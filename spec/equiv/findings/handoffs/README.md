# Handoffs between roles

Use this directory when a task crosses a write-scope boundary. One file per
handoff:

```
findings/handoffs/<from>-to-<to>-<topic>.md
```

Template:

```
from: <role>
to: <role>
status: open | accepted | done | rejected
artifacts:
  - <path> (what it is)
ask: <one concrete action>
blockers: <exact missing thing, or none>
evidence: <command + hash, if any>
```

Rules:

- The receiving role changes `status` to `accepted`, does the work in its own
  scope, then sets `done` and links the artifact.
- An open handoff blocks the dependent milestone; name it in the checkpoint.
- No cross-scope writes. If a file must change outside your scope, write a
  handoff instead of editing it.
