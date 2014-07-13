#Set-StrictMode -Version Latest
$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
Import-Module ($here + '\PsGet\PsGet.psm1') -Force
$verbose = $false

if(-not $pester) {
    Write-Warning 'The tests for GetPsGet should be executed using the Run-Tests.ps1 script or Invoke-AllTests.cmd batch script'
    exit -1;
}

#Import Custom Pester assertions
. "$here\PsGetPesterAssertionExtensions.ps1"
. "$here\HelperFunctionsForTesting.ps1"

Describe 'Install-Module' {
    Context 'When modules are installed from Web URL Source' {
        Invoke-InSandbox {
            It 'Should support something simple' {
                Install-Module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorld.psm1 -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should support urls that command cannot guess module name' {
                Install-Module -ModuleUrl http://bit.ly/ggXoOR -ModuleName 'HelloWorld'  -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should support zipped modules' {
                Install-Module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorld.zip  -Verbose:$verbose
                'HelloWorldZip' | Should BeInstalled
                Drop-Module -Module 'HelloWorldZip'
            }

            It 'Should support zipped in child folder modules' {
                Install-Module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorldInChildFolder.zip  -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should support alternate install destination' {
                Install-Module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorld.psm1 -Destination $Env:TEMP\Modules -Verbose:$verbose
                if (-not (Test-Path -Path $Env:TEMP\Modules\HelloWorld\HelloWorld.psm1)) {
                    throw 'Module was not installed to alternate destination'
                }
                Remove-Item -Path $Env:TEMP\Modules -Recurse -Force
            }
        }
    }

    Context 'When modules installed from local source' {
        Invoke-InSandbox {
            It 'Should support zipped with child modules' {
                # The problem was with PSCX, they have many child modules
                # And PsGet was loading one of child module instead.
                # This test ensues that only main module is loaded
                # Related to Issue #12
                Install-Module -ModulePath $here\TestModules\HelloWorldFolderWithChildModules.zip  -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should support local PSM1 modules' {
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1  -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should support installing local module directory of loose files' {
                Install-Module -ModulePath $here\TestModules\HelloWorldFolder  -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should support local zipped modules' {
                Install-Module -ModulePath $here\TestModules\HelloWorld.zip  -Verbose:$verbose
                'HelloWorldZip' | Should BeInstalled
                Drop-Module -Module 'HelloWorldZip'
            }

            It 'Should support zipped modules with a PSD1 manifest' {
                Install-Module -ModulePath $here\TestModules\ManifestTestModule.zip -Verbose:$verbose
                if (-not (Get-Command -Name Get-ManifestTestModuleName -Module ManifestTestModule)) {
                    throw 'ManifestTestModule not installed'
                }
                Drop-Module -Module ManifestTestModule
            }

            It 'Should support local zipped in child folder modules' {
                Install-Module -ModulePath $here\TestModules\HelloWorldInChildFolder.zip  -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should support zipped modules with a PSD1 manifest in a child folder' {
                Install-Module -ModulePath $here\TestModules\ManifestTestModuleInChildFolder.zip -Verbose:$verbose
                if (-not (Get-Command -Name Get-ManifestTestModuleName -Module ManifestTestModule)) {
                    throw 'ManifestTestModule not installed'
                }
                Drop-Module -Module ManifestTestModule
            }

            It 'Should not install module twice' {
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose:$verbose
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should not install module twice When ModuleName specified' {
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose:$verbose
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should install module twice When Update specified' {
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose:$verbose
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -Update -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }
        }
    }

    Context 'When modules from centralized PsGet repository' {
        Invoke-InSandbox {
            It 'Should install module from repo' {
                Install-Module HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should update installed module' {
                Install-Module HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                update-module HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should install zipped module from repo' {
                Install-Module HelloWorldZip -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorldZip' | Should BeInstalled
                Drop-Module -Module 'HelloWorldZip'
            }

            It 'Should install module from directory url specified in global variable' {
                $OriginalPsGetDirectoryUrl = $global:PsGetDirectoryUrl
                try {
                    $global:PsGetDirectoryUrl = 'https://github.com/psget/psget/raw/master/TestModules/Directory.xml'
                    Install-Module -Module HelloWorld -Verbose:$verbose
                    'HelloWorld' | Should BeInstalled
                } finally {
                    $global:PsGetDirectoryUrl = $OriginalPsGetDirectoryUrl
                    Drop-Module -Module 'HelloWorld'
                }
            }

            It 'Should retrieve information about module by ID' {
                $retrieved = Get-PsGetModuleInfo HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                $retrieved | Should Not Be $null
                $retrieved.Id | Should Be 'HelloWorld'
            }

            It 'Should retrieve information about module and wildcard' {
                $retrieved = Get-PsGetModuleInfo Hello* -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                $retrieved | Should HaveCountOf 1
            }

            It 'Should support value pipelining to Get-PsGetModuleInfo' {
                $retrieved = 'HelloWorld' | Get-PsGetModuleInfo -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                $retrieved.Id | Should Be 'HelloWorld'
            }

            It 'Should support property pipelining to Get-PsGetModuleInfo' {
                $retrieved = New-Object -TypeName PSObject -Property @{ ModuleName = 'HelloWorld' } | Get-PsGetModuleInfo -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                $retrieved.Id | Should Be 'HelloWorld'
            }

            It 'Should output objects from Get-PsGetModuleInfo that have properties matching parameters of Install-Module' {
                $retrieved = Get-PsGetModuleInfo -ModuleName HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose
                $retrieved.Id | Should Be 'HelloWorld'
                $retrieved.ModuleUrl | Should Be 'https://github.com/psget/psget/raw/master/TestModules/HelloWorld.psm1'
            }

            It 'Should support piping from Get-PsGetModuleInfo to Install-Module' {
                Get-PsGetModuleInfo -ModuleName HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose:$verbose |
                    Install-Module -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module 'HelloWorld'
            }
        }
    }

    Context 'After installation complete' {
        Invoke-InSandbox {
            It 'Should not modify User or Machine permanent environment variables' {
                #Use a unique path so it can be removed from the environment variable
                $tempDir = Get-TempDir
                $beforeModulePath = $env:PSModulePath
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Destination $tempDir -Verbose:$verbose
                'HelloWorld' | Should BeInstalled  $tempDir
                'HelloWorld' | Should Not BeInPSModulePath $tempDir
                'HelloWorld' | Should Not BeGloballyImportable $tempDir

                $env:PSModulePath | Should Be $beforeModulePath
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should modify User or Machine permanent environment variable When using -PersistEnvironment switch' {
                #Use a unique path so it can be removed from the environment variable
                $tempDir = Get-TempDir
                Install-Module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Destination $tempDir -PersistEnvironment -Verbose:$verbose
                'HelloWorld' | Should BeInPSModulePath $tempDir
                'HelloWorld' | Should BeInstalled  $tempDir
                'HelloWorld' | Should BeGloballyImportable $tempDir

                #Because we are persisting the environment variable change, the before and after should be different
                $env:PSModulePath | Should Not Be $beforeModulePath

                Drop-Module -Module 'HelloWorld'
            }

            It 'Should install to user modules When PSModulePath has been prefixed' {
                $DefaultUserPSModulePath = Get-UserModulePath
                $DefaultSystemPSModulePath = $global:CommonGlobalModuleBasePath

                $DefaultPSModulePath = $DefaultUserPSModulePath,$DefaultSystemPSModulePath -join ';'

                $OriginalPSModulePath = $Env:PSModulePath
                $OriginalDestinationModulePath = $PSGetDefaultDestinationModulePath
                try {

                    $Env:PSModulePath = "$Env:ProgramFiles\TestPSModulePath;$DefaultPSModulePath"

                    Install-Module -ModulePath $here\TestModules\HelloWorld.psm1  -Verbose:$verbose -Global:$false
                    if (-not (Test-Path -Path $DefaultUserPSModulePath\HelloWorld\HelloWorld.psm1)) {
                        throw 'Module was not installed to user module path'
                    }
                    Remove-Item -Path $DefaultUserPSModulePath\HelloWorld -Recurse -Force

                } finally {
                    # restore paths
                    $Env:PSModulePath = $OriginalPSModulePath
                    $PSGetDefaultDestinationModulePath = $OriginalDestinationModulePath
                }
            }
        }
    }

    Context 'When requiring a specific module hash value' {
        Invoke-InSandbox {
            $userModulePath = Get-UserModulePath
            It 'Should install module matching the expected hash' {
                Install-Module -ModuleName HelloWorld -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorldInChildFolder.zip -ModuleHash 722377BA6AE291B6109C7ECEBE5E2B0745B46A070238F7D05FC0DCA68F8BAD03 -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                Drop-Module -Module HelloWorld
            }

            It 'Should not install a module with a conflicting hash' {
                try {
                    Install-Module -ModuleName HelloWorld -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorldInChildFolder.zip -ModuleHash AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA -Verbose:$verbose
                } catch { $_ }
                if (Test-Path $userModulePath/HelloWorld/HelloWorld.psm1) {
                    throw 'Module HelloWorld was installed but Should not have been installed.'
                }
                Drop-Module -Module HelloWorld
            }

            It 'Should reinstall a module When the existing installation has a conflicting hash' {
                # make sure it is installed but not imported
                Install-Module -ModuleName HelloWorld -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorldInChildFolder.zip -ModuleHash 722377BA6AE291B6109C7ECEBE5E2B0745B46A070238F7D05FC0DCA68F8BAD03 -DoNotImport -Verbose:$verbose
                # change the module so the hash is wrong
                Set-Content -Path $userModulePath\HelloWorld\extrafile.txt -Value ExtraContent

                Get-PSGetModuleHash -Path $here\TestModules\HelloWorldFolder
                Get-PSGetModuleHash -Path $userModulePath\HelloWorld

                Install-Module -ModuleName HelloWorld -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorldInChildFolder.zip -ModuleHash 722377BA6AE291B6109C7ECEBE5E2B0745B46A070238F7D05FC0DCA68F8BAD03 -Verbose:$verbose
                if ((Get-PSGetModuleHash -Path $userModulePath\HelloWorld) -ne '722377BA6AE291B6109C7ECEBE5E2B0745B46A070238F7D05FC0DCA68F8BAD03') {
                    throw 'Module HelloWorld was not reinstalled to fix the hash.'
                }
                Drop-Module -Module HelloWorld
            }
        }
    }

    Context 'When installing binary modules' {
        Invoke-InSandbox {
            It 'Should support zipped binary modules' {
                # run this test out-of-process so the binary module can be removed without locking issues
                & powershell -noprofile -command {
                    param ($here,$verbose)
                    Import-Module -Name "$here\PsGet\PsGet.psm1"

                    Install-Module -ModulePath $here\TestModules\TestBinaryModule.zip  -Verbose:$verbose -Update
                    Import-Module -Name TestBinaryModule
                    if (-not (Get-Command -Name Get-Echo -Module TestBinaryModule)) {
                        throw 'TestBinaryModule not installed'
                    }
                } -args $here,$verbose
                Drop-Module -Module TestBinaryModule
            }
        }
    }

    Context 'When installing Nuget: Script modules' {
        Invoke-InSandbox {
            It 'Should support installing the latest stable version of a custom Nuget package' {
                Install-Module -NugetPackageId PsGetTest -NugetSource http://www.myget.org/F/psgettest -DoNotImport -Verbose:$verbose
                'PsGetTest' | Should BeInstalled
                Drop-Module -Module PsGetTest
            }

            It 'Should support installing a latest pre-release version of a custom Nuget package' {
                Install-Module -NugetPackageId PsGetTest -PreRelease -NugetSource http://www.myget.org/F/psgettest -DoNotImport -Verbose:$verbose
                'PsGetTest' | Should BeInstalled
                Drop-Module -Module PsGetTest
            }

            It 'Should support installing a specific pre-release version of a custom Nuget package' {
                Install-Module -NugetPackageId PsGetTest -PackageVersion 1.0.0-alpha -NugetSource http://www.myget.org/F/psgettest -DoNotImport -Verbose:$verbose
                'PsGetTest' | Should BeInstalled
                Drop-Module -Module PsGetTest
            }
        }
    }

    Context 'When installing Nuget: Binary Modules' {
        Invoke-InSandbox {
            It 'Should support installing the latest version of a public Nuget package' {
                Install-ModuleOutOfProcess -Module 'mdbc' -FunctionNameToVerify 'Connect-Mdbc'
                Drop-Module -Module mdbc
            }

            It 'Should support installing a specific version of a public Nuget package' {
                # Install-Module -NugetPackageId mdbc -PackageVersion 1.0.6 -DoNotImport -Verbose:$verbose
                Install-ModuleOutOfProcess -Module 'mdbc' -FunctionNameToVerify 'Connect-Mdbc' -PackageVersion 1.0.6
                Drop-Module -Module mdbc
            }
        }
    }

    Context 'After installation the post-install-hooks may be called' {
        Invoke-InSandbox {
            It 'Should execute the standard post-install-hook Install.ps1' {
                Install-Module -ModulePath $here\TestModules\HelloWorldWithInstall.zip -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should not execute the standard post-install-hook Install.ps1 if -DoNotPostInstall is set' {
                Install-Module -ModulePath $here\TestModules\HelloWorldWithInstall.zip -Verbose:$verbose -DoNotPostInstall
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should NotHaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should only execute the standard post-install-hook Install.ps1 if nothing else defined' {
                Install-Module -ModulePath $here\TestModules\HelloWorldWithPostHook.zip -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should NotHaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should execute the defined post-install-hook PostHook.ps1' {
                Install-Module -ModulePath $here\TestModules\HelloWorldWithPostHook.zip -Verbose:$verbose -PostInstallHook 'PostHook.ps1'
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should execute the standard post-install-hook Install.ps1 for directory installs if nothing defined' {
                Install-Module HelloWorldWithInstall -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should execute the standard post-install-hook Install.ps1 for directory updates if nothing defined' {
                Install-Module HelloWorldWithInstall -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose -Update
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should not execute the standard post-install-hook Install.ps1 for directory installs if -DoNotPostInstall' {
                Install-Module HelloWorldWithInstall -DirectoryUrl "file://$here\TestModules\Directory.xml" -DoNotPostInstall -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should NotHaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should not execute the standard post-install-hook Install.ps1 for directory installs if DoNotPostInstall set in directory' {
                Install-Module HelloWorldWithoutInstall -DirectoryUrl "file://$here\TestModules\Directory.xml"  -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should NotHaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should execute the post-install-hook defined in directory.xml' {
                Install-Module HelloWorldWithPostHook -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should not execute the post-install-hook if not defined in directory.xml' {
                Install-Module HelloWorldWithoutPostHook -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should NotHaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should not execute the post-install-hook in update context if not defined' {
                Install-Module HelloWorldWithPostHook -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should execute the post-install-hook defined in directory.xml with default name Install.ps1 but can prevent executing it in update context' {
                Install-Module HelloWorldWithInstallButNotUpdate -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'

                Install-Module HelloWorldWithInstallButNotUpdate -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose -Update
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should NotHaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should execute the post-install-hook defined in directory.xml' {
                Install-Module HelloWorldWithPostInUp -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should HaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }

            It 'Should not execute the post-install-hook if not defined in directory.xml' {
                Install-Module HelloWorldWithoutPostInUp -DirectoryUrl "file://$here\TestModules\Directory.xml" -Verbose:$verbose
                'HelloWorld' | Should BeInstalled
                'HelloWorld' | Should NotHaveExecutedPostInstallHook
                Drop-Module -Module 'HelloWorld'
            }
        }
    }
}