#Set-StrictMode -Version Latest
$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
Remove-Module PsGet -Force -ErrorAction SilentlyContinue
import-module -name ($here + "\PsGet\PsGet.psm1") -force 
$verbose = $false;

if(-not $pester) {
    Write-Warning "**********  The tests for PsGet should be executed using the Run-Tests.ps1 script or Invoke-AllTests.cmd batch script **********"
    exit -1;
}

#Import Custom Pester assertions
. (Join-Path -path $here -ChildPath "PsGetPesterAssertionExtensions.ps1")

#Import Test Helper funtions
. (Join-Path -Path $here -ChildPath "HelperFunctionsForTesting.ps1")


#Put the tests in a re-usable script block so they can be used for different argument values (i.e. use both -Global:$true and -Global:$false for all tests)
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
