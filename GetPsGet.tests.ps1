if(-not $pester) {
    Write-Warning 'The tests for GetPsGet should be executed using the Run-Tests.ps1 script or Invoke-AllTests.cmd batch script'
    exit -1;
}

$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
. "$here\HelperFunctionsForTesting.ps1"

function Get-GetPsGet {
    Get-Content -Path $here\GetPsGet.ps1 | Out-String
}

# backup current PSModulePath before testing
$OriginalPSModulePath = $env:PSModulePath


# default PSModulePath is '{userpath};{systempath}'
$DefaultUserPSModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules

Describe 'GetPsGet.ps1 installs the PsGet module' {
    Context 'Installation target can be configured by environment variable ''$PsGetDestinationModulePath''' {
        $PsGetDestinationModulePath = (Get-Item -Path 'TestDrive:\').FullName
        $expectedPath = ConvertTo-CanonicalPath -Path "$PsGetDestinationModulePath\PsGet"
        $env:PSModulePath = $DefaultPSModulePath
        Mock Write-Host
        Mock Write-Warning
        Remove-Module PsGet -ErrorAction SilentlyContinue

        Get-GetPsGet | Invoke-Expression
        It 'installs PsGet to target path' {
            Test-Path -Path $expectedPath\PsGet.psm1 | Should Be $true
        }

        It 'imports the module from target path' {
            (Get-Command Install-Module).Module.ModuleBase | Should Be $expectedPath
        }

        Remove-Variable -Name PsGetDestinationModulePath
        $env:PSModulePath = $OriginalPSModulePath
    }

    Context 'Installation target will be selected from PSModulePath if ''$PsGetDestinationModulePath'' is not defined' {
        Remove-Variable -Name PsGetDestinationModulePath -ErrorAction SilentlyContinue
        $testDrive = (Get-Item -Path 'TestDrive:').FullName
        $pathA = "$testDrive\A"
        $pathB = "$testDrive\B"
        $env:PSModulePath = "$pathA;$pathB"
        $expectedPath = ConvertTo-CanonicalPath -Path "$pathA\PsGet"
        Mock Write-Host
        Mock Write-Warning
        Remove-Module PsGet -ErrorAction SilentlyContinue

        Get-GetPsGet | Invoke-Expression
        It 'installs PsGet to first path in PSModulePath' {
            Test-Path -Path $expectedPath\PsGet.psm1 | Should Be $true
        }

        It 'imports the module from that path' {
            (Get-Command Install-Module).Module.ModuleBase | Should Be $expectedPath
        }

        $env:PSModulePath = $OriginalPSModulePath
    }

    Context 'Installation selects always the default user module path if available in PSModulePath' {
        Write-Warning 'This test is not completely isolated and (re-)install PsGet into the users default module path. This potentially new version should be no issue because new versions of PsGet are backward compatible and the executing user develops PsGet changes.'
        Remove-Variable -Name PsGetDestinationModulePath -ErrorAction SilentlyContinue
        $pathA = (Get-Item -Path 'TestDrive:\').FullName
        $env:PSModulePath = "$pathA;$HOME\TestPSModulePath;$env:ProgramFiles\TestPSModulePath;$DefaultUserPSModulePath"
        $expectedPath = ConvertTo-CanonicalPath -Path "$DefaultUserPSModulePath\PsGet"
        Mock Write-Host
        Mock Write-Warning
        Remove-Module PsGet -ErrorAction SilentlyContinue

        Get-GetPsGet | Invoke-Expression
        It 'installs PsGet to first path in PSModulePath' {
            Test-Path -Path $expectedPath\PsGet.psm1 | Should Be $true
        }

        It 'imports the module from that path' {
            (Get-Command Install-Module).Module.ModuleBase | Should Be $expectedPath
        }

        $env:PSModulePath = $OriginalPSModulePath
    }

    Context 'Installation works with ErrorActionPreference = ''Stop'' and Set-StrictMode Latest' {
        $PsGetDestinationModulePath = (Get-Item -Path 'TestDrive:\').FullName
        $expectedPath = ConvertTo-CanonicalPath -Path "$PsGetDestinationModulePath\PsGet"
        $env:PSModulePath = $DefaultPSModulePath
        Mock Write-Host
        Mock Write-Warning
        Remove-Module PsGet -ErrorAction SilentlyContinue

        powershell -noprofile -command {
                param ($DownloadedScript, $Destination)
                function Write-Host {}
                function Write-Warning {}
                $PsGetDestinationModulePath = $Destination
                $ErrorActionPreference = 'Stop'
                Set-StrictMode -Version Latest
                $DownloadedScript | iex
            } -args @(Get-GetPsGet; $PsGetDestinationModulePath)

        It 'Should support ErrorActionPreference = ''Stop'' and Set-StrictMode Latest' {
            -not $? | Should be $false
        }

        It 'installs PsGet to target path' {
            Test-Path -Path $expectedPath\PsGet.psm1 | Should Be $true
        }

        Remove-Variable -Name PsGetDestinationModulePath
        $env:PSModulePath = $OriginalPSModulePath
    }
}