$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Show-Subsystem([string] $Path) {
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path $Path))
    $pe = [BitConverter]::ToInt32($bytes, 0x3c)
    $subsystem = [BitConverter]::ToUInt16($bytes, $pe + 24 + 68)
    Write-Host "$Path : PE subsystem $subsystem (2 = Windows GUI, 3 = Windows console)"
    return $subsystem
}

function Require-Success {
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $LASTEXITCODE" }
}

New-Item -ItemType Directory -Force out | Out-Null
Write-Host '$ rustc +1.98.0 -Vv'
rustc +1.98.0 -Vv
Require-Success
Write-Host '$ bazel version'
bazel --output_user_root=C:/b --ignore_all_rc_files version
Require-Success

Write-Host '$ rustc +1.98.0 main.rs -o out/direct.exe'
rustc +1.98.0 main.rs -o out/direct.exe
Require-Success
if ((Show-Subsystem out/direct.exe) -ne 2) { throw 'rustc control is not GUI' }

Write-Host '$ rustc +1.98.0 plain.rs -Clink-arg=/SUBSYSTEM:WINDOWS -o out/override.exe'
$failure = & rustc +1.98.0 plain.rs -Clink-arg=/SUBSYSTEM:WINDOWS -o out/override.exe 2>&1
$failedExit = $LASTEXITCODE
$failure | ForEach-Object { Write-Host $_ }
if ($failedExit -eq 0 -or ($failure -join "`n") -notmatch 'WinMain') {
    throw 'Expected the raw subsystem override to fail with missing WinMain'
}

Write-Host '$ rustc +1.98.0 plain.rs -Clink-arg=/SUBSYSTEM:WINDOWS -Clink-arg=/ENTRY:mainCRTStartup -o out/fixed.exe'
rustc +1.98.0 plain.rs -Clink-arg=/SUBSYSTEM:WINDOWS -Clink-arg=/ENTRY:mainCRTStartup -o out/fixed.exe
Require-Success
if ((Show-Subsystem out/fixed.exe) -ne 2) { throw 'Explicit entry point control is not GUI' }

Write-Host '$ bazel build //:gui //:override_with_entry'
bazel --output_user_root=C:/b --ignore_all_rc_files build --enable_bzlmod //:gui //:override_with_entry --subcommands
Require-Success
$guiSubsystem = Show-Subsystem bazel-bin/gui.exe
if ((Show-Subsystem bazel-bin/override_with_entry.exe) -ne 2) { throw 'Bazel explicit entry point control is not GUI' }

Write-Host '$ bazel build //:override_only'
$failure = & bazel --output_user_root=C:/b --ignore_all_rc_files build --enable_bzlmod //:override_only 2>&1
$failedExit = $LASTEXITCODE
$failure | ForEach-Object { Write-Host $_ }
if ($failedExit -eq 0 -or ($failure -join "`n") -notmatch 'WinMain') {
    throw 'Expected the Bazel subsystem override to fail with missing WinMain'
}

Write-Host "RESULT: rustc GUI=2; Bazel GUI=$guiSubsystem; raw subsystem override fails with WinMain in both; explicit entry point succeeds in both."
if ($guiSubsystem -ne 3) { throw 'The suspected upstream console override did not reproduce' }
Write-Host '$ bazel build //:gui_target_override --stamp'
bazel --output_user_root=C:/b --ignore_all_rc_files build --enable_bzlmod //:gui_target_override --stamp --subcommands
Require-Success
if ((Show-Subsystem bazel-bin/gui_target_override.exe) -ne 2) { throw 'Stamped target-local workaround is not GUI' }
Write-Host '$ bazel build //:gui_target_override --nostamp'
bazel --output_user_root=C:/b --ignore_all_rc_files build --enable_bzlmod //:gui_target_override --nostamp --subcommands
Require-Success
if ((Show-Subsystem bazel-bin/gui_target_override.exe) -ne 2) { throw 'Unstamped target-local workaround is not GUI' }
Write-Host 'PASS: GUI attribute plus target subsystem override links as GUI with and without stamping; no explicit entry point or toolchain patches.'
$global:LASTEXITCODE = 0

foreach ($mode in @('fastbuild', 'dbg', 'opt')) {
    foreach ($stamp in @('--stamp', '--nostamp')) {
        Write-Host "`$ bazel build //:profile_subsystem -c $mode $stamp"
        bazel --output_user_root=C:/b --ignore_all_rc_files build --enable_bzlmod //:profile_subsystem -c $mode $stamp --subcommands
        Require-Success
        $expected = if ($mode -eq 'opt') { 2 } else { 3 }
        if ((Show-Subsystem bazel-bin/profile_subsystem.exe) -ne $expected) {
            throw "Wrong subsystem for mode=$mode stamp=$stamp"
        }
        Write-Host "PASS: mode=$mode stamp=$stamp subsystem=$expected"
    }
}

Write-Host '$ bazel build //:profile_subsystem -c opt --platforms=//:macos_arm64 --nobuild'
$failure = & bazel --output_user_root=C:/b --ignore_all_rc_files build --enable_bzlmod //:profile_subsystem -c opt --platforms=//:macos_arm64 --nobuild 2>&1
$failedExit = $LASTEXITCODE
$failure | ForEach-Object { Write-Host $_ }
if ($failedExit -eq 0 -or ($failure -join "`n") -notmatch 'incompatible') {
    throw 'Expected explicit macOS build to be rejected as incompatible'
}
Write-Host 'PASS: macOS target rejected by compatibility constraint before compilation'
$global:LASTEXITCODE = 0
