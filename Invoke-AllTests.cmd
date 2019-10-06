cls

powershell.exe -noprofile -command ". %~dp0Run-Tests.ps1 -EnableExit"
@if errorlevel 1 echo FAIL & exit /b %errorlevel%

powershell.exe -version 2 -noprofile ". %~dp0Run-Tests.ps1 -EnableExit"
@if errorlevel 1 echo FAIL & exit /b %errorlevel%