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
