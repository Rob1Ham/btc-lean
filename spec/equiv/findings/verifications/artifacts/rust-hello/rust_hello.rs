// E0 R-leg smoke test: a trivial pure function, no panic paths.
#[no_mangle]
pub extern "C" fn add_one(x: i32) -> i32 { x.wrapping_add(1) }
