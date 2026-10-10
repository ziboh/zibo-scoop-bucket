<#
.SYNOPSIS
    Associates MarkFlowy with markdown / text / json files for the current user.

.DESCRIPTION
    Registers a per-user ProgId (MarkFlowy.Document) plus an Applications entry,
    then points the default value of the selected extensions at it. Every value
    that is overwritten is backed up, so -Uninstall can restore the previous
    state (regardless of whether the app is being removed).

    Windows stores an explicit per-user choice for an extension under
    HKCU\...\Explorer\FileExts\<ext>\UserChoice, and that key takes priority
    over HKCU\Software\Classes\<ext>. UserChoice is protected (its value is
    hash-signed), so this script never deletes it - it reports the affected
    extensions instead and asks the user to pick MarkFlowy via
    "Open with -> Choose another app".

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File "$dir\markflowy-file-assoc.ps1"

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File "$dir\markflowy-file-assoc.ps1" -Uninstall
#>
[CmdletBinding()]
param(
    [string]$AppPath,
    [string[]]$Extensions = @('.md', '.markdown', '.json', '.txt'),
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty inside a param() default when the script is started with
# `powershell -File`, so resolve the default app path here instead.
if (-not $AppPath) {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $AppPath = Join-Path $scriptDir 'MarkFlowy.exe'
}

$progId = 'MarkFlowy.Document'
$appProgId = 'Applications\MarkFlowy.exe'
$backupRoot = 'Software\MarkFlowy\FileAssocBackup'
$userChoiceRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts'

$currentUser = [Microsoft.Win32.Registry]::CurrentUser
$classes = $currentUser.CreateSubKey('Software\Classes')

function Get-UserChoice {
    param([string]$Extension)

    $key = $currentUser.OpenSubKey("$userChoiceRoot\$Extension\UserChoice")
    if (-not $key) { return $null }
    try { return $key.GetValue('ProgId') } finally { $key.Dispose() }
}

function Test-IsOurChoice {
    param([string]$Choice)

    if (-not $Choice) { return $false }
    return ($Choice -ieq $progId) -or ($Choice -ieq $appProgId)
}

function Invoke-ExplorerRefresh {
    if (-not ('ExplorerRefresh' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ExplorerRefresh {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
'@
    }
    [ExplorerRefresh]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
}

try {
    if (-not $Uninstall) {
        if (-not (Test-Path -LiteralPath $AppPath)) {
            throw "MarkFlowy.exe was not found: $AppPath"
        }

        $resolvedApp = (Resolve-Path -LiteralPath $AppPath).Path
        $command = '"{0}" "%1"' -f $resolvedApp

        # Snapshot the current state before touching anything (first run wins: a
        # re-run must not overwrite the backup with our own ProgId).
        $backup = $currentUser.OpenSubKey($backupRoot)

        foreach ($extension in $Extensions) {
            if ($backup -and $backup.OpenSubKey($extension)) { continue }

            $key = $classes.OpenSubKey($extension)
            $previous = if ($key) { $key.GetValue('') } else { $null }
            if ($key) { $key.Dispose() }

            $entry = $currentUser.CreateSubKey("$backupRoot\$extension")
            $entry.SetValue('HadPrevious', [int]($null -ne $previous), [Microsoft.Win32.RegistryValueKind]::DWord)
            $entry.SetValue('Previous', [string]$previous, [Microsoft.Win32.RegistryValueKind]::String)
            $entry.Dispose()
        }

        $appCommandKey = $classes.OpenSubKey("$appProgId\shell\open\command")
        $previousCommand = if ($appCommandKey) { $appCommandKey.GetValue('') } else { $null }
        if ($appCommandKey) { $appCommandKey.Dispose() }

        if (-not ($backup -and $backup.OpenSubKey('Applications'))) {
            $entry = $currentUser.CreateSubKey("$backupRoot\Applications")
            $entry.SetValue('HadCommand', [int]($null -ne $previousCommand), [Microsoft.Win32.RegistryValueKind]::DWord)
            $entry.SetValue('Command', [string]$previousCommand, [Microsoft.Win32.RegistryValueKind]::String)
            $entry.Dispose()
        }

        if ($backup) { $backup.Dispose() }

        # ProgId used as the extension default.
        $key = $classes.CreateSubKey($progId)
        $key.SetValue('', 'MarkFlowy document', [Microsoft.Win32.RegistryValueKind]::String)
        $key.CreateSubKey('DefaultIcon').SetValue('', "$resolvedApp,0", [Microsoft.Win32.RegistryValueKind]::String)
        $key.CreateSubKey('shell\open\command').SetValue('', $command, [Microsoft.Win32.RegistryValueKind]::String)
        $key.Dispose()

        # Application entry: lets MarkFlowy show up in "Open with" and is what an
        # existing FileExts UserChoice for .md resolves through.
        $key = $classes.CreateSubKey($appProgId)
        $key.SetValue('FriendlyAppName', 'MarkFlowy', [Microsoft.Win32.RegistryValueKind]::String)
        $key.CreateSubKey('DefaultIcon').SetValue('', "$resolvedApp,0", [Microsoft.Win32.RegistryValueKind]::String)
        $key.CreateSubKey('shell\open\command').SetValue('', $command, [Microsoft.Win32.RegistryValueKind]::String)
        $types = $key.CreateSubKey('SupportedTypes')
        foreach ($extension in $Extensions) {
            $types.SetValue($extension, '', [Microsoft.Win32.RegistryValueKind]::String)
        }
        $types.Dispose()
        $key.Dispose()

        $shadowed = @()
        Write-Host ''
        Write-Host 'MarkFlowy file associations updated:'
        foreach ($extension in $Extensions) {
            $key = $classes.CreateSubKey($extension)
            $key.SetValue('', $progId, [Microsoft.Win32.RegistryValueKind]::String)
            $key.Dispose()

            $choice = Get-UserChoice $extension
            if ($choice -and -not (Test-IsOurChoice $choice)) {
                $shadowed += "  $extension -> $choice"
                Write-Host ("  {0,-11} {1}" -f $extension, 'set, but another app is the per-user default')
            }
            elseif (Test-IsOurChoice $choice) {
                Write-Host ("  {0,-11} {1}" -f $extension, 'ok (MarkFlowy was already the per-user default)')
            }
            else {
                Write-Host ("  {0,-11} {1}" -f $extension, 'ok')
            }
        }

        if ($shadowed.Count -gt 0) {
            Write-Host ''
            Write-Host 'These extensions already have an explicit per-user default, which Windows gives'
            Write-Host 'priority over this script. To hand them to MarkFlowy, right click a file ->'
            Write-Host 'Open with -> Choose another app -> MarkFlowy -> Always use this app:'
            $shadowed | ForEach-Object { Write-Host $_ }
        }

        Write-Host ''
        Write-Host 'Undo with: -Uninstall'
    }
    else {
        $resolvedApp = if (Test-Path -LiteralPath $AppPath) { (Resolve-Path -LiteralPath $AppPath).Path } else { $AppPath }
        $backup = $currentUser.OpenSubKey($backupRoot)

        foreach ($extension in $Extensions) {
            $key = $classes.OpenSubKey($extension, $true)
            if (-not $key) { continue }

            if ($key.GetValue('') -eq $progId) {
                $entry = if ($backup) { $backup.OpenSubKey($extension) } else { $null }
                if ($entry -and [int]$entry.GetValue('HadPrevious') -eq 1) {
                    $key.SetValue('', [string]$entry.GetValue('Previous'), [Microsoft.Win32.RegistryValueKind]::String)
                }
                else {
                    $key.DeleteValue('', $false)
                }
                if ($entry) { $entry.Dispose() }
            }
            $key.Dispose()
        }

        $entry = if ($backup) { $backup.OpenSubKey('Applications') } else { $null }
        $key = $classes.OpenSubKey($appProgId, $true)
        if ($key) {
            $commandKey = $key.OpenSubKey('shell\open\command', $true)
            $currentCommand = if ($commandKey) { $commandKey.GetValue('') } else { $null }

            if ($entry -and [int]$entry.GetValue('HadCommand') -eq 1) {
                # The command predates this script: put it back, drop the rest.
                if ($commandKey) { $commandKey.SetValue('', [string]$entry.GetValue('Command'), [Microsoft.Win32.RegistryValueKind]::String) }
                foreach ($name in @('FriendlyAppName', 'DefaultIcon', 'SupportedTypes')) {
                    try { $key.DeleteSubKeyTree($name, $false) } catch { }
                }
            }
            elseif ($currentCommand -and $currentCommand -like "*$resolvedApp*") {
                # No backup and the entry is ours: remove it completely.
                if ($commandKey) { $commandKey.Dispose(); $commandKey = $null }
                $key.Close()
                $classes.DeleteSubKeyTree($appProgId, $false)
                $key = $null
            }

            if ($commandKey) { $commandKey.Dispose() }
            if ($key) { $key.Dispose() }
        }
        if ($entry) { $entry.Dispose() }

        $classes.DeleteSubKeyTree($progId, $false)
        $currentUser.DeleteSubKeyTree($backupRoot, $false)

        $stillChosen = @()
        foreach ($extension in $Extensions) {
            $choice = Get-UserChoice $extension
            if (Test-IsOurChoice $choice) { $stillChosen += "  $extension -> $choice" }
        }

        Write-Host ''
        Write-Host 'MarkFlowy file associations were removed.'

        if ($stillChosen.Count -gt 0) {
            Write-Host ''
            Write-Host 'Windows still remembers an explicit per-user choice for these extensions'
            Write-Host '(it is hash-protected and cannot be reset by a script). Repoint them with'
            Write-Host 'Open with -> Choose another app:'
            $stillChosen | ForEach-Object { Write-Host $_ }
        }
    }
}
finally {
    $classes.Dispose()
}

Invoke-ExplorerRefresh
