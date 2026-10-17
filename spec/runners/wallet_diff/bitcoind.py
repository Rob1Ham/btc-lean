"""Private regtest bitcoind driver and JSON-RPC client.

The module is deliberately self-contained: Python 3 standard library only,
one disposable regtest datadir per process, cookie authentication, and a
best-effort clean shutdown.  It does not model wallets or Bitcoin rules; it
only moves JSON to and from a pinned bitcoind.

Not modeled here: RPC transport security (the cookie is read from a local
file), multi-node networking, restart persistence, and wallet database
formats.  The driver binds RPC to 127.0.0.1 and disables P2P listening.
"""

from __future__ import annotations

import base64
import http.client
import json
import os
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.parse
from pathlib import Path
from typing import Any, Iterable

DEFAULT_BITCOIND = "build/scratch/core-build/build/bin/bitcoind"
DEFAULT_TMP_ROOT = "build/scratch"


class RPCError(Exception):
    """A JSON-RPC error returned by bitcoind.

    ``code`` and ``message`` are preserved verbatim because the corpus records
    Core's exact error contract.  ``data`` is optional and is not written to
    the corpus unless a caller explicitly projects it.
    """

    def __init__(self, code: int, message: str, data: Any = None) -> None:
        super().__init__(f"RPC error {code}: {message}")
        self.code = code
        self.message = message
        self.data = data

    def as_dict(self) -> dict[str, Any]:
        """Return the stable, corpus-facing representation of the error."""
        return {"code": self.code, "message": self.message}


class NodeStartError(RuntimeError):
    """Raised when bitcoind cannot be started or does not answer RPC."""


def _free_port() -> int:
    """Reserve an ephemeral loopback port and immediately release it.

    There is a small TOCTOU window between release and bitcoind's bind.  A
    failed start is reported with the debug log so the caller can retry; no
    other process on this host is expected to race the harness.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])
    finally:
        sock.close()


def _pid_is_ours(pid: int, datadir: Path) -> bool:
    """Return True when ``pid`` is alive and its command line names ``datadir``."""
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False
    return str(datadir).encode() in raw


def _tail(path: Path, lines: int = 40) -> str:
    """Return the last ``lines`` lines of a text file, or an empty string."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    return "\n".join(text[-lines:])


class Bitcoind:
    """A disposable regtest daemon plus a cookie-authenticated RPC client.

    Parameters are intentionally small: a binary path, an optional datadir,
    and extra command-line arguments.  When ``datadir`` is omitted a fresh
    directory is created below ``build/scratch``.
    """

    def __init__(
        self,
        binary: str = DEFAULT_BITCOIND,
        datadir: str | None = None,
        extra_args: Iterable[str] = (),
        startup_timeout: float = 90.0,
        rpc_timeout: float = 120.0,
    ) -> None:
        self.binary = str(binary)
        self._owns_datadir = datadir is None
        if datadir is None:
            self.datadir = Path(tempfile.mkdtemp(prefix="wallet-diff-", dir=DEFAULT_TMP_ROOT))
        else:
            self.datadir = Path(datadir).resolve()
            self.datadir.mkdir(parents=True, exist_ok=True)
        self.extra_args = list(extra_args)
        self.startup_timeout = startup_timeout
        self.rpc_timeout = rpc_timeout
        self.port: int | None = None
        self._cookie: str | None = None
        self._pid: int | None = None
        self._request_id = 0
        self._started = False
        self._stopped = False

    # ------------------------------------------------------------------ paths

    @property
    def cookie_path(self) -> Path:
        """Path of the regtest RPC cookie file."""
        return self.datadir / "regtest" / ".cookie"

    @property
    def debug_log(self) -> Path:
        """Path of the regtest debug log."""
        return self.datadir / "regtest" / "debug.log"

    @property
    def pid_path(self) -> Path:
        """Path of the daemon PID file."""
        return self.datadir / "regtest" / "bitcoind.pid"

    # ---------------------------------------------------------------- startup

    def start(self) -> "Bitcoind":
        """Start bitcoind with ``-daemonwait`` and wait until RPC answers."""
        if not os.access(self.binary, os.X_OK):
            raise NodeStartError(f"bitcoind is not executable: {self.binary}")
        self.port = _free_port()
        args = [
            self.binary,
            "-regtest",
            f"-datadir={self.datadir}",
            "-server=1",
            "-daemonwait",
            f"-rpcport={self.port}",
            "-rpcbind=127.0.0.1",
            "-rpcallowip=127.0.0.1",
            "-listen=0",
            "-discover=0",
            "-dnsseed=0",
            "-fallbackfee=0.0002",
            "-printtoconsole=0",
            *self.extra_args,
        ]
        proc = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=self.startup_timeout,
            check=False,
        )
        if proc.returncode != 0:
            detail = _tail(self.debug_log) or proc.stdout.decode("utf-8", "replace")
            raise NodeStartError(f"bitcoind failed to start (rc={proc.returncode}):\n{detail}")
        self._started = True
        try:
            self._pid = int(self.pid_path.read_text(encoding="ascii").strip())
        except (OSError, ValueError):
            self._pid = None
        self._wait_for_rpc()
        return self

    def _wait_for_rpc(self) -> None:
        """Poll ``getblockchaininfo`` until the RPC server is ready."""
        deadline = time.monotonic() + self.startup_timeout
        last_error: Exception | None = None
        while time.monotonic() < deadline:
            try:
                self.rpc("getblockchaininfo")
                return
            except (OSError, RPCError, http.client.HTTPException, json.JSONDecodeError) as exc:
                last_error = exc
                time.sleep(0.1)
        detail = _tail(self.debug_log)
        raise NodeStartError(f"bitcoind RPC did not become ready: {last_error}\n{detail}")

    # -------------------------------------------------------------------- RPC

    def _read_cookie(self) -> str:
        """Read and cache the ``__cookie__:<secret>`` Basic-auth credential."""
        if self._cookie is None:
            self._cookie = self.cookie_path.read_text(encoding="ascii").strip()
        return self._cookie

    def _auth_header(self) -> str:
        token = base64.b64encode(self._read_cookie().encode("ascii")).decode("ascii")
        return f"Basic {token}"

    def rpc(
        self,
        method: str,
        *params: Any,
        wallet: str | None = None,
    ) -> Any:
        """Call one JSON-RPC method and return its ``result``.

        ``wallet`` selects the ``/wallet/<name>`` endpoint used by wallet RPCs
        in multi-wallet mode.  JSON-RPC errors raise :class:`RPCError`; they
        are not converted to ``None``.
        """
        if self.port is None:
            raise NodeStartError("bitcoind has not been started")
        self._request_id += 1
        payload = json.dumps(
            {"jsonrpc": "2.0", "id": self._request_id, "method": method, "params": list(params)},
            separators=(",", ":"),
        ).encode("utf-8")
        path = "/"
        if wallet is not None:
            path = "/wallet/" + urllib.parse.quote(wallet, safe="")
        headers = {
            "Content-Type": "application/json",
            "Authorization": self._auth_header(),
        }
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=self.rpc_timeout)
        try:
            conn.request("POST", path, body=payload, headers=headers)
            response = conn.getresponse()
            raw = response.read()
        finally:
            conn.close()

        if response.status == 401:
            # A restarted daemon may have rotated the cookie.
            self._cookie = None
            raise RPCError(401, "unauthorized", None)
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise RPCError(response.status, raw.decode("utf-8", "replace")) from exc
        error = decoded.get("error")
        if error:
            if isinstance(error, dict):
                raise RPCError(int(error.get("code", -1)), str(error.get("message", "")), error.get("data"))
            raise RPCError(-1, str(error))
        return decoded.get("result")

    # ---------------------------------------------------------------- shutdown

    def _alive(self) -> bool:
        """Return True while the recorded daemon process still exists."""
        if self._pid is None:
            return False
        return _pid_is_ours(self._pid, self.datadir)

    def stop(self, timeout: float = 60.0) -> None:
        """Request a clean stop and wait for the process to disappear.

        If RPC shutdown fails, SIGTERM is sent; SIGKILL is a last resort.
        Repeated calls are harmless.
        """
        if self._stopped:
            return
        self._stopped = True
        if self._started:
            try:
                self.rpc("stop")
            except (OSError, RPCError, http.client.HTTPException):
                pass
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline and self._alive():
            time.sleep(0.05)
        if self._alive() and self._pid is not None:
            try:
                os.kill(self._pid, 15)
            except OSError:
                pass
            deadline = time.monotonic() + 10.0
            while time.monotonic() < deadline and self._alive():
                time.sleep(0.05)
        if self._alive() and self._pid is not None:
            try:
                os.kill(self._pid, 9)
            except OSError:
                pass
            time.sleep(0.2)

    def cleanup(self, keep: bool = False) -> None:
        """Stop the daemon and remove the datadir unless ``keep`` is true."""
        self.stop()
        if self._owns_datadir and not keep:
            shutil.rmtree(self.datadir, ignore_errors=True)

    def __enter__(self) -> "Bitcoind":
        return self.start()

    def __exit__(self, exc_type: Any, exc: Any, tb: Any) -> None:
        self.cleanup(keep=False)
