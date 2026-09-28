# Windows subsystem reproduction

Requires Windows x64 with MSVC, Bazelisk, and Rust 1.98.0 (`rustup toolchain install 1.98.0 --profile minimal`).

```powershell
git clone https://github.com/ashi009/rules-rust-windows-subsystem-repro
cd rules-rust-windows-subsystem-repro
./repro.ps1
```

`main.rs` contains only `#![windows_subsystem = "windows"]` and an empty `main`.
The script compares its PE subsystem when built directly with rustc and with
an unmodified rules_rust release. It also tests the raw `/SUBSYSTEM:WINDOWS`
override, with and without `/ENTRY:mainCRTStartup`, on a separate source file
without the attribute.

CI also runs against upstream rules_rust commit
`83d85cce0ab56b42a7466d8b34f4e52949d2d064`.
