# Start SillyTavern detached with output logging (bypasses git-bash background TTY issue)
$ErrorActionPreference = 'Stop'
$stDir = 'H:\workspace\hermes\session-prompt\.research\SillyTavern'
$node = 'C:\Users\86153\nodejs\node.exe'
$p = Start-Process -FilePath $node -ArgumentList 'server.js' -WorkingDirectory $stDir `
    -RedirectStandardOutput (Join-Path $stDir 'server.out.log') `
    -RedirectStandardError  (Join-Path $stDir 'server.err.log') `
    -WindowStyle Hidden -PassThru
$p.Id | Out-File -Encoding ascii (Join-Path $stDir 'server.pid')
Write-Output "Started PID $($p.Id)"
