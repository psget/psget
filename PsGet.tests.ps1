#Set-StrictMode -Version Latest
$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
Remove-Module PsGet -Force -ErrorAction SilentlyContinue
import-module -name ($here + "\PsGet\PsGet.psm1") -force 
$verbose = $false;

#region Test Helper Functions
function Drop-Module ($Module) {
    Remove-Module $Module -Force -ErrorAction SilentlyContinue
    if ((Test-Path $UserModulePath/$Module/)){	
		Remove-Item $UserModulePath/$Module/ -Force -Recurse -ErrorAction SilentlyContinue
	}

    #Delete all installations of this module that are locatable via the PSModulePath
    Get-Module -Name $Module | foreach {
        Remove-Item $_.ModuleBase -Force -Recurse -ErrorAction SilentlyContinue 
    }

    $Env:PSModulePath -split ";"
}

function Install-ModuleOutOfProcess {
    param([string]$module, [string]$FunctionNameToVerify,[string]$PackageVersion)
    # run this test out-of-process so the binary module can be removed without locking issues
    & powershell.exe -command {
        param ($here,$module,$FunctionNameToVerify,$PAckageVersion,$Global)
        Import-Module -Name "$here\PsGet\PsGet.psm1"
    
        install-module -NugetPackageId $module -DoNotImport -PackageVersion $PAckageVersion -update -Global:$Global
        Import-Module -Name $module
        if (-not (Get-Command -Name $FunctionNameToVerify -Module $module)) {
            throw "$module not installed"
        }
    } -args $here,$module,$FunctionNameToVerify,$PAckageVersion,$Global

}

function Canonicolize-Path {
    param(
    [Parameter(Mandatory=$true)]
    [string]$Path)
    
    return [io.path]::GetFullPath(($path.Trim() + '\'))

}

function Get-TempDir {
    return (join-path -path ([IO.Path]::GetTempPath()) -child ([Guid]::NewGuid().ToString()) )
}
#endregion

#region Custom Pester assertions
function PesterHaveCountOf {
    param([array]$list,[int]$count)
    return ($list -and $list.Length -eq $count)

}

function PesterHaveCountOfFailureMessage {
    param([array]$list,[int]$count)
    return "Expected array length of $count, actual array length: $($list.length)"

}

function NotPesterHaveCountOfFailureMessage {
    param([array]$list,[int]$count)
    return "Expected array length of $count to be different than actual array length: $($list.length)"

}

function PesterBeGloballyImportable {
    param($Module)

    $modulePath = Canonicolize-Path -path $UserModulePath

    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = Canonicolize-Path -path $args[0]
    }

    $paths = $env:PSModulePath -split ";" | foreach { Canonicolize-Path -Path $_ }

    if($paths -inotcontains $modulePath) {
        return $false
    }

    #To pass, all modules must be importable via the $env:PSModulePath environment variable (explicit path not required)
    try {
        Import-Module -Name $Module  -ErrorAction Stop
    } catch {
        return $false
    } finally {
        Remove-Module -Name $Module -Force -ErrorAction SilentlyContinue
    }
    return $true
<#
.SYNOPSIS
Verifies that a module can be imported by name only (using the $env:PSModulePath to locate the module)

.PARAMETER Module
The module name
.PARAMETER Args
$Args[0] can optionally contain the path of where the module is required to be installed

#>
}

function PesterBeGloballyImportableFailureMessage {
    param($Module)
    $modulePath = $UserModulePath
    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }
    return @"
    The module '$Module' was not globally importable (requires that module's install base path is in the `$env:PSModulePath variable)

    Installation location of module '$Module':
    $modulePath


    Value of `$env:PSModulePath
    $env:PSModulePath
"@
}

function NotPesterBeGloballyImportableFailureMessage {
    param($Module)

    $modulePath = $UserModulePath
    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }
    return @"
    The module '$Module' was globally importable, but was not expected to be (requires that module's install base path is NOT in the `$env:PSModulePath variable)

    Installation location of module '$Module':
    $modulePath


    Value of `$env:PSModulePath
    $env:PSModulePath
"@

}

function PesterBeInPSModulePath {
    param(
    $Module
    )

   $modulePath = $UserModulePath
    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }

    $expectedInstallationPath = Join-Path -Path $ModulePath -ChildPath $Module
    $baseFilename = join-path $expectedInstallationPath $Module

    #Get the module by name
    $foundmodule = get-module -Name $module -ListAvailable
    $foundModuleInExactLocation = $foundmodule|where {[io.path]::GetDirectoryName($_.Path) -like $expectedInstallationPath}

    #Verify that the module exists in the correct location
    if(-not $foundModuleInExactLocation) {
        return $false
    }

    return $true
}

function PesterBeInPSModulePathFailureMessage {
     param($Module)
     return "The path for the module '$Module' was not in PSModulePath environment variable"
}

function NotPesterBeInPSModulePathFailureMessage {
    param($Module)
     return "The path for the module '$Module' was in PSModulePath environment variable, it was not expected to be"

}

function PesterBeInstalled {
    param(
    $Module
    )
<#
.SYNOPSIS
Ensures that a module exists, can be imported, and can be listed using the $env:PSModulePath envrionment variable

#>

    $modulePath = $UserModulePath
    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }

    $expectedInstallationPath = Join-Path -Path $ModulePath -ChildPath $Module
    $baseFilename = join-path $expectedInstallationPath $Module


    #Verify that the module (DLL or PSM1) exists
    if (-not (Test-Path "$baseFileName.psm1") -and -not (Test-Path "$baseFileName.dll")){
		$err = "Module $Module was not installed at '$baseFileName.psm1' or '$baseFileName.dll'"
        Write-Warning $err
        throw $err
        
	}

    return $true
}


function PesterBeInstalledFailureMessage {
     param($Module)
     return "$Module was not installed"
}
#endregion

#Put the tests in a re-usable script block so they can be reused for different argument values (i.e. All tests pass wheter or not -Global is specified)
$installModuleTests = [scriptblock] {
    if($Global) {
        $UserModulePath = $global:CommonGlobalModuleBasePath
    } else {
    
        $UserModulePath = Get-UserModulePath
    }


    Context "When modules are installed from Web URL Source" {
        It "Should support something simple" {
            install-module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorld.psm1 -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled 
            drop-module "HelloWorld"
        }

        It "Should support urls that command cannot guess module name" {
            install-module -ModuleUrl http://bit.ly/ggXoOR -ModuleName "HelloWorld"  -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }
    

        It "Should support zipped modules" {
            install-module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorld.zip  -Verbose:$verbose -Global:$Global
            "HelloWorldZip" | Should BeInstalled
            drop-module "HelloWorldZip"
        }

        It "Should support zipped in child folder modules" {
            install-module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorldInChildFolder.zip  -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        
        It "Should support alternate install destination" {
            install-module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorld.psm1 -Destination $Env:TEMP\Modules -Verbose:$verbose -Global:$Global
            if (-not (Test-Path -Path $Env:TEMP\Modules\HelloWorld\HelloWorld.psm1)) {
                throw "Module was not installed to alternate destination"
            }
            Remove-Item -Path $Env:TEMP\Modules -Recurse -Force
        }
    }

    Context "When modules installed from local source" {
        It "Should support zipped with child modules" {
            # The problem was with PSCX, they have many child modules
            # And PsGet was loading one of child module instead.
            # This test ensues that only main module is loaded
            # Related to Issue #12
            install-module -ModulePath $here\TestModules\HelloWorldFolderWithChildModules.zip  -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should support local PSM1 modules" {
            install-module -ModulePath $here\TestModules\HelloWorld.psm1  -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should support installing local module directory of loose files" {
            install-module -ModulePath $here\TestModules\HelloWorldFolder  -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should support local zipped modules" {
            install-module -ModulePath $here\TestModules\HelloWorld.zip  -Verbose:$verbose -Global:$Global
            "HelloWorldZip" | Should BeInstalled
            drop-module "HelloWorldZip"
        }

        It "Should support zipped modules with a PSD1 manifest" {
            install-module -ModulePath $here\TestModules\ManifestTestModule.zip -Verbose:$verbose -Global:$Global
            if (-not (Get-Command -Name Get-ManifestTestModuleName -Module ManifestTestModule)) {
                throw "ManifestTestModule not installed"
            }
            drop-module ManifestTestModule
        }

        It "Should support local zipped in child folder modules" {
            install-module -ModulePath $here\TestModules\HelloWorldInChildFolder.zip  -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should support zipped modules with a PSD1 manifest in a child folder" {
            install-module -ModulePath $here\TestModules\ManifestTestModuleInChildFolder.zip -Verbose:$verbose -Global:$Global
            if (-not (Get-Command -Name Get-ManifestTestModuleName -Module ManifestTestModule)) {
                throw "ManifestTestModule not installed"
            }
            drop-module ManifestTestModule
        }

        It "Should support modules with install.ps1" {
            install-module -ModulePath $here\TestModules\HelloWorldWithInstall.zip  -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should not install module twice" {
            install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose:$verbose -Global:$Global
            install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should not install module twice When ModuleName specified" {
            install-module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose:$verbose -Global:$Global
            install-module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should install module twice When Update specified" {
            install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose:$verbose -Global:$Global
            install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Update -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }
    }

    Context "When modules from centralized PsGet repository" {
        It "Should install module from repo" {
            install-module HelloWorld -DirectoryURL "https://github.com/psget/psget/raw/master/TestModules/Directory.xml" -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should update installed module" {
            install-module HelloWorld -DirectoryURL "https://github.com/psget/psget/raw/master/TestModules/Directory.xml" -Verbose:$verbose -Global:$Global
            update-module HelloWorld -DirectoryURL "https://github.com/psget/psget/raw/master/TestModules/Directory.xml" -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }

        It "Should install zipped module from repo" {
            install-module HelloWorldZip -DirectoryURL "https://github.com/psget/psget/raw/master/TestModules/Directory.xml" -Verbose:$verbose -Global:$Global
            "HelloWorldZip" | Should BeInstalled
            drop-module "HelloWorldZip"
        }

        It "Should install module from directory url specified in global variable" {
            $OriginalPsGetDirectoryUrl = $global:PsGetDirectoryUrl
            try {
                $global:PsGetDirectoryUrl = 'https://github.com/psget/psget/raw/master/TestModules/Directory.xml'
                Install-Module -Module HelloWorld -Verbose:$verbose -Global:$Global
                "HelloWorld" | Should BeInstalled
            } finally {
                $global:PsGetDirectoryUrl = $OriginalPsGetDirectoryUrl
                drop-module "HelloWorld"
            }
        }

        #It ""Should crash if module was not found in repo"" {
        #install-module Foo -DirectoryURL "https://github.com/psget/psget/raw/master/TestModules/Directory.xml" -Verbose:$verbose -Global:$Global

        It "Should retrieve information about module by ID" {
            $retrieved = Get-PsGetModuleInfo HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose 
            $retrieved | Should Not Be $null
            $retrieved.Id | Should Be "HelloWorld"
        }

        It "Should retrieve information about module and wildcard" {
            $retrieved = Get-PsGetModuleInfo Hello* -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose 
            $retrieved | Should HaveCountOf 1
        }

        It "Should support value pipelining to Get-PsGetModuleInfo" {
            $retrieved = 'HelloWorld' | Get-PsGetModuleInfo -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
            $retrieved.Id | Should Be "HelloWorld"
        }

        It "Should support property pipelining to Get-PsGetModuleInfo" {
            $retrieved = New-Object -TypeName PSObject -Property @{ ModuleName = 'HelloWorld' } | Get-PsGetModuleInfo -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
            $retrieved.Id | Should Be "HelloWorld"
        }

        It "Should output objects from Get-PsGetModuleInfo that have properties matching parameters of Install-Module" {
            $retrieved = Get-PsGetModuleInfo -ModuleName HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose 
            $retrieved.Id | Should Be "HelloWorld"
            $retrieved.ModuleUrl | Should Be "https://github.com/psget/psget/raw/master/TestModules/HelloWorld.psm1"
        }

        It "Should support piping from Get-PsGetModuleInfo to Install-Module" {
            Get-PsGetModuleInfo -ModuleName HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose |
                Install-Module -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module "HelloWorld"
        }
    }

    Context "After installation complete" {
        It "Should not modify User or Machine permanent environment variables" {
            #Use a unique path so it can be removed from the environment variable
            $tempDir = Get-TempDir
            $beforeModulePath = $env:PSModulePath
            install-module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Destination $tempDir -Verbose:$verbose -Global:$Global 
            "HelloWorld" | Should BeInstalled  $tempDir
            "HelloWorld" | Should Not BeInPSModulePath $tempDir
            "HelloWorld" | Should Not BeGloballyImportable $tempDir

            $env:PSModulePath | Should Be $beforeModulePath
            drop-module "HelloWorld"
        }

        It "Should modify User or Machine permanent environment variable When using -PersistEnvironment switch" {
            #Use a unique path so it can be removed from the environment variable
            $tempDir = Get-TempDir
            $beforeModulePath = $env:PSModulePath
            try{
                install-module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Destination $tempDir -PersistEnvironment -Verbose:$verbose -Global:$Global 
                "HelloWorld" | Should BeInPSModulePath $tempDir
                "HelloWorld" | Should BeInstalled  $tempDir
                "HelloWorld" | Should BeGloballyImportable $tempDir

                #Because we are persisting the environment variable change, the before and after should be different
                $env:PSModulePath | Should Not Be $beforeModulePath

                drop-module "HelloWorld"
            } finally {
                Remove-PathFromEnvironmentVariable -VariableName "PSModulePath" -PathToRemove $tempDir -PersistEnvironment -Scope "Machine"
                Remove-PathFromEnvironmentVariable -VariableName "PSModulePath" -PathToRemove $tempDir -PersistEnvironment -Scope "User"
            }

            #Just to verify we properly cleaned up
            $env:PSModulePath | Should Be $beforeModulePath
        }

        It "Should install to user modules When PSModulePath has been prefixed" {
            $DefaultUserPSModulePath = Get-UserModulePath
            $DefaultSystemPSModulePath = $global:CommonGlobalModuleBasePath

            $DefaultPSModulePath = $DefaultUserPSModulePath,$DefaultSystemPSModulePath -join ';'

            $OriginalPSModulePath = $Env:PSModulePath
            $OriginalDestinationModulePath = $PSGetDefaultDestinationModulePath
            try {

           
                $Env:PSModulePath = "$Env:ProgramFiles\TestPSModulePath;$DefaultPSModulePath"


                install-module -ModulePath $here\TestModules\HelloWorld.psm1  -Verbose:$verbose -Global:$false
                if (-not (Test-Path -Path $DefaultUserPSModulePath\HelloWorld\HelloWorld.psm1)) {
                    throw "Module was not installed to user module path"
                }
                Remove-Item -Path $DefaultUserPSModulePath\HelloWorld -Recurse -Force

            } finally {
                # restore paths
                $Env:PSModulePath = $OriginalPSModulePath
                $PSGetDefaultDestinationModulePath = $OriginalDestinationModulePath
            }
        }
    }

    Context "When requiring a specific module hash value" {
        It "Should hash module in a folder" {
            $Hash = Get-PsGetModuleHash -Path $here\TestModules\HelloWorldFolder
            $Hash | Should Be 563E329AFF0785E4A2C3039EF7F60F9E2FA68888CE12EE38C1406BDDC09A87E1
        }

        It "Should install module matching the expected hash" {
            Install-Module -ModulePath $here\TestModules\HelloWorldFolder\HelloWorld.psm1 -ModuleHash 563E329AFF0785E4A2C3039EF7F60F9E2FA68888CE12EE38C1406BDDC09A87E1 -Verbose:$verbose -Global:$Global
            "HelloWorld" | Should BeInstalled
            drop-module HelloWorld
        }

        It "Should not install a module with a conflicting hash" {
            try {
                Install-Module -ModulePath $here\TestModules\HelloWorldFolder\HelloWorld.psm1 -ModuleHash AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA -Verbose:$verbose -Global:$Global
            } catch { $_ }
            if (Test-Path $UserModulePath/HelloWorld/HelloWorld.psm1) {
                throw "Module HelloWorld was installed but Should not have been installed."
            }
            drop-module HelloWorld
        }

        It "Should reinstall a module When the existing installation has a conflicting hash" {
            # make sure it is installed but not imported
            Install-Module -ModulePath $here\TestModules\HelloWorldFolder\HelloWorld.psm1 -ModuleHash 563E329AFF0785E4A2C3039EF7F60F9E2FA68888CE12EE38C1406BDDC09A87E1 -DoNotImport -Verbose:$verbose -Global:$Global 
            # change the module so the hash is wrong
            #Set-Content -Path $UserModulePath\HelloWorld\extrafile.txt -Value ExtraContent

            Get-PSGetModuleHash -Path $here\TestModules\HelloWorldFolder
            Get-PSGetModuleHash -Path $UserModulePath\HelloWorld

            Install-Module -ModulePath $here\TestModules\HelloWorldFolder\HelloWorld.psm1 -ModuleHash 563E329AFF0785E4A2C3039EF7F60F9E2FA68888CE12EE38C1406BDDC09A87E1 -Verbose:$verbose -Global:$Global
            if ((Get-PSGetModuleHash -Path $UserModulePath\HelloWorld) -ne '563E329AFF0785E4A2C3039EF7F60F9E2FA68888CE12EE38C1406BDDC09A87E1') {
                throw "Module HelloWorld was not reinstalled to fix the hash."
            }
            drop-module HelloWorld
        }
    }

    Context "When installing binary modules" {
        It "Should support zipped binary modules" {

            # run this test out-of-process so the binary module can be removed without locking issues
            & powershell.exe -command {
                param ($here,$verbose)
                Import-Module -Name "$here\PsGet\PsGet.psm1"
    
                install-module -ModulePath $here\TestModules\TestBinaryModule.zip  -Verbose:$verbose -Global:$Global -Update
                Import-Module -Name TestBinaryModule
                if (-not (Get-Command -Name Get-Echo -Module TestBinaryModule)) {
                    throw "TestBinaryModule not installed"
                }
            } -args $here,$verbose
            drop-module TestBinaryModule
        }
    }

    Context "When installing Nuget" { 
        Context "Script modules"{
            It "Should support installing the latest stable version of a custom Nuget package" {
                install-module -NugetPackageId PsGetTest -NugetSource http://www.myget.org/F/psgettest -DoNotImport -Verbose:$verbose -Global:$Global
                "PsGetTest" | Should BeInstalled
                drop-module PsGetTest
            }

            It "Should support installing a latest pre-release version of a custom Nuget package" {
                install-module -NugetPackageId PsGetTest -PreRelease -NugetSource http://www.myget.org/F/psgettest -DoNotImport -Verbose:$verbose -Global:$Global
                "PsGetTest" | Should BeInstalled
                drop-module PsGetTest
            }

            It "Should support installing a specific pre-release version of a custom Nuget package" {
                install-module -NugetPackageId PsGetTest -PackageVersion 1.0.0-alpha -NugetSource http://www.myget.org/F/psgettest -DoNotImport -Verbose:$verbose -Global:$Global
                "PsGetTest" | Should BeInstalled
                drop-module PsGetTest
            }
        }

        Context "Binary Modules" {
            It "Should support installing the latest version of a public Nuget package" {
                Install-ModuleOutOfProcess -module 'mdbc' -FunctionNameToVerify 'Connect-Mdbc'
                "mdbc" | Should BeInstalled
                drop-module mdbc
            }

            It "Should support installing a specific version of a public Nuget package" {
               # install-module -NugetPackageId mdbc -PackageVersion 1.0.6 -DoNotImport -Verbose:$verbose -Global:$Global
                Install-ModuleOutOfProcess -module 'mdbc' -FunctionNameToVerify 'Connect-Mdbc' -PackageVersion 1.0.6
                "mdbc" | Should BeInstalled
                drop-module mdbc
            }

        }
    }
    
}

#Need ability to execute permutations of parameters using the same tests
$Global = $false
Describe "Install-Module -Global:$Global" $installModuleTests 
$Global = $true
Describe "Install-Module -Global:$Global" $installModuleTests 
