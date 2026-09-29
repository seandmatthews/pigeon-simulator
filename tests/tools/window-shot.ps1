# window-shot.ps1 <title-pattern> <output-path>
# OS-level window capture via Win32 PrintWindow — bypasses the in-process
# capture stream entirely (useful when a session runs with --images off, or
# as a second opinion on what the player actually sees). Captures the
# top-level window whose title contains <title-pattern> (case-insensitive);
# pilot.py titles game windows "Pigeon pilot <session-id>", so passing the
# session id targets exactly one instance among many.
#
# Exit 0 + writes PNG on success. Exit 1 if no matching window found.
# PS 5.1-safe.

param(
    [Parameter(Mandatory = $true)]
    [string]$TitlePattern,
    [Parameter(Mandatory = $true)]
    [string]$OutPath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Shot {
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

# find candidate windows: visible, with a title matching the pattern
$procs = Get-Process | Where-Object {
    $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -and
    $_.MainWindowTitle -match [regex]::Escape($TitlePattern)
}
if (-not $procs) {
    Write-Output "NOWINDOW"
    exit 1
}
$proc = $procs | Select-Object -First 1
$hwnd = $proc.MainWindowHandle

[Win32Shot]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 250

$rect = New-Object Win32Shot+RECT
[Win32Shot]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
if ($w -le 0 -or $h -le 0) {
    Write-Output "NOWINDOW"
    exit 1
}

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()

# PW_RENDERFULLCONTENT (2) captures GPU-composited content (needed for Godot)
[Win32Shot]::PrintWindow($hwnd, $hdc, 2) | Out-Null

$g.ReleaseHdc($hdc)
$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output "SAVED $OutPath ${w}x${h}"
exit 0
