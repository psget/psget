#Set-StrictMode -Version Latest
$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
Import-Module ($here + "\PsGet\PsGet.psm1") -Force
$verbose = $false;

if(-not $pester) {
    Write-Warning "The tests for GetPsGet should be executed using the Run-Tests.ps1 script or Invoke-AllTests.cmd batch script"
    exit -1;
}

#Import Custom Pester assertions
. "$here\PsGetPesterAssertionExtensions.ps1"
. "$here\HelperFunctionsForTesting.ps1"

Describe "Install-Module" {

    $UserModulePath = Get-UserModulePath

    Context "When modules installed globaly" {

        It "Should support installing module globally" {
            Install-Module -ModulePath $here\TestModules\HelloWorld.psm1  -Verbose:$verbose -Global
            "HelloWorld" | Should BeInstalledGlobally
            Drop-Module "HelloWorld" -Global
        }

        It "Should add common modules folder to the env variables" {
            Backup-PSModulePathVariable -Scope "Machine"
            Backup-PSModulePathVariable -Scope "User"

            try {
            Remove-PathFromPSModulePath -PathToRemove $global:CommonGlobalModuleBasePath -PersistEnvironment -Scope "Machine"
            Remove-PathFromPSModulePath -PathToRemove $global:CommonGlobalModuleBasePath -PersistEnvironment -Scope "User"

            Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose:$verbose -Force -Global

            $Env:PSModulePath.Contains($global:CommonGlobalModuleBasePath) | Should Be $True

            Drop-Module "HelloWorld" -Global
            } catch {
                Restore-PSModulePathVariable -Scope "Machine"
                Restore-PSModulePathVariable -Scope "User"
            }
        }
    }
}