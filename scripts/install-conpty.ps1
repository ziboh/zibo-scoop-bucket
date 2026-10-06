[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$WezTermDirectory
)

$ErrorActionPreference = 'Stop'
$packageUrl = 'https://github.com/microsoft/terminal/releases/download/v1.24.10921.0/Microsoft.Windows.Console.ConPTY.1.24.260402001.nupkg'
$expectedVersion = '1.24.2604.02001'
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('wezterm-conpty-' + [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    $archive = Join-Path $temporaryDirectory 'conpty.zip'
    $extract = Join-Path $temporaryDirectory 'extract'

    Invoke-WebRequest -Uri $packageUrl -OutFile $archive -UseBasicParsing
    Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force

    $sources = @{
        'OpenConsole.exe' = Join-Path $extract 'build\native\runtimes\x64\OpenConsole.exe'
        'conpty.dll'      = Join-Path $extract 'runtimes\win-x64\native\conpty.dll'
    }

    foreach ($file in $sources.Keys) {
        $source = $sources[$file]
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "The official package is missing $file."
        }

        $signature = Get-AuthenticodeSignature -LiteralPath $source
        if ($signature.Status -ne 'Valid') {
            throw "$file from the official package does not have a valid signature."
        }

        $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($source).FileVersion
        if ($version -ne $expectedVersion) {
            throw "$file has version $version; expected $expectedVersion."
        }
    }

    foreach ($file in $sources.Keys) {
        Copy-Item -LiteralPath $sources[$file] -Destination (Join-Path $WezTermDirectory $file) -Force
    }

    Write-Host "Installed Microsoft ConPTY $expectedVersion for WezTerm."
}
finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
