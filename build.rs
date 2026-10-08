use std::env;

fn main() {
    println!("cargo:rustc-check-cfg=cfg(tarro_desktop_windows_gui)");
    // Read the target profile: build scripts themselves run in the host configuration.
    if env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows")
        && env::var("PROFILE").as_deref() == Ok("release")
    {
        println!("cargo:rustc-cfg=tarro_desktop_windows_gui");
        if env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc") {
            // TODO(bazelbuild/rules_cc#929): remove when the toolchain honors the GUI subsystem.
            println!("cargo:rustc-link-arg-bins=/SUBSYSTEM:WINDOWS");
        }
    }

}
