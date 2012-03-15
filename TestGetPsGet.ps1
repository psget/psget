$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

function Remove-PsGetModule {
    Get-Module -Name PsGet | Remove-Module -ErrorAction Stop
    Get-Module -Name PsGet -ListAvailable | Select-Object -ExpandProperty ModuleBase | Remove-Item -Recurse
}

function SimulateBootstrapDownload {
    Get-Content -Path $PSScriptRoot\GetPsGet.ps1 | Out-String 
}

Remove-Variable -Name PsGetDestinationModulePath -ErrorAction SilentlyContinue
# backup current PSModulePath before testing
$OriginalPSModulePath = $Env:PSModulePath

# default PSModulePath is '{userpath};{systempath}'
$DefaultUserPSModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
$DefaultSystemPSModulePath = Join-Path -Path $PSHOME -ChildPath Modules

$DefaultPSModulePath = $DefaultUserPSModulePath,$DefaultSystemPSModulePath -join ';'

try {

    Write-Host Should support the default PSModulePath
    $Env:PSModulePath = $DefaultPSModulePath
    Remove-PsGetModule
    SimulateBootstrapDownload | iex
    if (-not (Test-Path -Path $DefaultUserPSModulePath\PsGet\PsGet.psm1)) {
        throw 'PsGet module was not installed to expected location'
    }

    Write-Host Should support the default PSModulePath with a prepended Program Files-relative module path
    $Env:PSModulePath = "$Env:ProgramFiles\TestPSModulePath;$DefaultPSModulePath"
    Remove-PsGetModule
    SimulateBootstrapDownload | iex
    if (-not (Test-Path -Path $DefaultUserPSModulePath\PsGet\PsGet.psm1)) {
        throw 'PsGet module was not installed to expected location'
    }

    Write-Host Should support the default PSModulePath with a prepended user profile-relative module path
    $Env:PSModulePath = "$HOME\TestPSModulePath;$DefaultPSModulePath"
    Remove-PsGetModule
    SimulateBootstrapDownload | iex
    if (-not (Test-Path -Path $DefaultUserPSModulePath\PsGet\PsGet.psm1)) {
        throw 'PsGet module was not installed to expected location'
    }

    Write-Host Should support a PSModulePath missing the default user profile-relative module path
    $FirstModulePath = "$Env:TEMP\TestPSModulePath"
    $Env:PSModulePath = "$FirstModulePath;$DefaultSystemPSModulePath"
    Remove-PsGetModule
    SimulateBootstrapDownload | iex
    if (-not (Test-Path -Path $FirstModulePath\PsGet\PsGet.psm1)) {
        throw 'PsGet module was not installed to expected location'
    }

    Write-Host Should support specifying the module install destination
    $PsGetDestinationModulePath = "$Env:TEMP\TestPSModulePath"
    $Env:PSModulePath = "$DefaultPSModulePath;$PsGetDestinationModulePath"
    Remove-PsGetModule
    SimulateBootstrapDownload | iex
    if (-not (Test-Path -Path $PsGetDestinationModulePath\PsGet\PsGet.psm1)) {
        throw 'PsGet module was not installed to expected location'
    }
    Remove-Variable -Name PsGetDestinationModulePath

    Write-Host Should support specifying a module install destination not in the PSModulePath
    $PsGetDestinationModulePath = "$Env:TEMP\TestPSModulePath"
    $Env:PSModulePath = $DefaultPSModulePath
    Remove-PsGetModule
    SimulateBootstrapDownload | iex
    if (-not (Test-Path -Path $PsGetDestinationModulePath\PsGet\PsGet.psm1)) {
        throw 'PsGet module was not installed to expected location'
    }
    Remove-Variable -Name PsGetDestinationModulePath

} finally {
    # restore PSModulePath 
    $Env:PSModulePath = $OriginalPSModulePath
}