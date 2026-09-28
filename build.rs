fn main() {
    println!("cargo:rerun-if-env-changed=TARRO_DESKTOP_FLEET_VERSION");
    println!("cargo:rustc-check-cfg=cfg(tarro_desktop_stamped)");
    if std::env::var("TARRO_DESKTOP_FLEET_VERSION").is_ok() {
        println!("cargo:rustc-cfg=tarro_desktop_stamped");
    }
}
