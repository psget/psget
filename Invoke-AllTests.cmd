cls

powershell.exe -noprofile %~dp0TestGetPsGet.ps1
@if errorlevel 1 echo FAIL & exit /b %errorlevel%

powershell.exe -noprofile %~dp0Tests.ps1
@if errorlevel 1 echo FAIL & exit /b %errorlevel%

powershell.exe -version 2 -noprofile %~dp0TestGetPsGet.ps1
@if errorlevel 1 echo FAIL & exit /b %errorlevel%

powershell.exe -version 2 -noprofile %~dp0Tests.ps1
@if errorlevel 1 echo FAIL & exit /b %errorlevel%