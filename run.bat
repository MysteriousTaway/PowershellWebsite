setlocal
cd /d %~dp0
Powershell.exe -executionpolicy bypass -File web.ps1 -NoNewWindow
::pause