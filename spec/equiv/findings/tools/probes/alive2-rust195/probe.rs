#[no_mangle]
pub extern "C" fn probe_sum(n: u32) -> u64 {
    let v: Vec<u32> = (0..n).collect();
    v.iter().map(|x| *x as u64).sum()
}
