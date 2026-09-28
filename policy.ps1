param([int] $ExpectedStampedSubsystem = 2)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Assert-Subsystem([string] $Path, [int] $Expected) {
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path $Path))
    $pe = [BitConverter]::ToInt32($bytes, 0x3c)
    $subsystem = [BitConverter]::ToUInt16($bytes, $pe + 24 + 68)
    Write-Host "$Path : PE subsystem $subsystem (expected $Expected)"
    if ($subsystem -ne $Expected) { throw 'Wrong Windows subsystem' }
}

bazel --output_user_root=C:/b --ignore_all_rc_files build --enable_bzlmod //:stamped //:unstamped //:native_console --subcommands
if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
Assert-Subsystem bazel-bin/stamped.exe $ExpectedStampedSubsystem
Assert-Subsystem bazel-bin/unstamped.exe 3
Assert-Subsystem bazel-bin/native_console.exe 3
