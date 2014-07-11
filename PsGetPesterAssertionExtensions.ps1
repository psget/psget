
#region Custom Pester assertions
function PesterHaveCountOf {
    param([array] $list,[int] $count)
    process {
        return ($list -and $list.Length -eq $count)
    }
}

function PesterHaveCountOfFailureMessage {
    param([array] $list,[int] $count)
    process {
        return "Expected array length of $count, actual array length: $($list.length)"
    }
}

function NotPesterHaveCountOfFailureMessage {
    param([array] $list,[int] $count)
    process {
        return "Expected array length of $count to be different than actual array length: $($list.length)"
    }
}

<#
    .SYNOPSIS
       Verifies that a module can be imported by name only (using the $env:PSModulePath to locate the module)

    .PARAMETER Module
        The module name

    .PARAMETER Args
        $Args[0] can optionally contain the path of where the module is required to be installed
#>
function PesterBeGloballyImportable {
    param([String] $Module)
    process {
        $modulePath = ConvertTo-CanonicalPath -path (Get-UserModulePath)

        if ($args -and $args[0] -and (Test-Path $args[0])) {
            $modulePath = ConvertTo-CanonicalPath -path $args[0]
        }

        $paths = $env:PSModulePath -split ";" | foreach { ConvertTo-CanonicalPath -Path $_ }

        if ($paths -inotcontains $modulePath) {
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
    }
}

function PesterBeGloballyImportableFailureMessage {
    param([String] $Module)
    process {
        $modulePath = Get-UserModulePath
        if ($args -and $args[0] -and (Test-Path $args[0])) {
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
}

function NotPesterBeGloballyImportableFailureMessage {
    param([String] $Module)
    process {
        $modulePath = Get-UserModulePath
        if ($args -and $args[0] -and (Test-Path $args[0])) {
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
}

function PesterBeInPSModulePath {
    param([String] $Module)
    process {
        $modulePath = Get-UserModulePath
        if ($args -and $args[0] -and (Test-Path $args[0])) {
            $modulePath = $args[0]
        }

        $expectedInstallationPath = Join-Path -Path $modulePath -ChildPath $Module
        $baseFilename = Join-Path -Path $expectedInstallationPath -ChildPath $Module

        try {
            #Get the module by name
            $foundmodule = get-module -Name $module -ListAvailable
            $foundModuleInExactLocation = $foundmodule | Where-Object { [io.path]::GetDirectoryName($_.Path) -like $expectedInstallationPath }

            #Verify that the module exists in the correct location
            if (-not $foundModuleInExactLocation) {
                return $false
            }
        } catch {
            # Powershell v2 Get-Module returns cached entries for freshly deleted module which contains an error message instead if a path
            # therefore GetDirectoryName throws an error which we need to catch.
            return $false
        }

        return $true
    }
}

function PesterBeInPSModulePathFailureMessage {
    param([String] $Module)
    process {
        return "The path for the module '$Module' was not in PSModulePath environment variable"
    }
}

function NotPesterBeInPSModulePathFailureMessage {
    param([String] $Module)
    process {
        return "The path for the module '$Module' was in PSModulePath environment variable, it was not expected to be"
    }
}

<#
    .SYNOPSIS
        Ensures that a module exists, can be imported, and can be listed using the $env:PSModulePath envrionment variable
#>
function PesterBeInstalled {
    param([String] $Module)
    process {
        $modulePath = Get-UserModulePath
        if ($args -and $args[0] -and (Test-Path $args[0])) {
            $modulePath = $args[0]
        }

        $expectedInstallationPath = Join-Path -Path $modulePath -ChildPath $Module
        $baseFilename = Join-Path -Path $expectedInstallationPath -ChildPath $Module

        #Verify that the module (DLL or PSM1) exists
        if (-not (Test-Path "$baseFileName.psm1") -and -not (Test-Path "$baseFileName.dll")) {
            throw "Module $Module was not installed at '$baseFileName.psm1' or '$baseFileName.dll'"
        }

        return $true
    }
}

<#
    .SYNOPSIS
        Ensures that a module exists, can be imported, and can be listed using the $env:PSModulePath envrionment variable
#>
function PesterBeInstalledGlobally {
    param([String] $Module)
    process {
        $modulePath = $global:CommonGlobalModuleBasePath
        if ($args -and $args[0] -and (Test-Path $args[0])) {
            $modulePath = $args[0]
        }

        $expectedInstallationPath = Join-Path -Path $modulePath -ChildPath $Module
        $baseFilename = Join-Path -Path $expectedInstallationPath -ChildPath $Module


        #Verify that the module (DLL or PSM1) exists
        if (-not (Test-Path "$baseFileName.psm1") -and -not (Test-Path "$baseFileName.dll")) {
            throw "Module $Module was not installed at '$baseFileName.psm1' or '$baseFileName.dll'"
        }

        return $true
    }
}


function PesterBeInstalledFailureMessage {
    param([String] $Module)
    process {
        return "$Module was not installed"
    }
}

function PesterHaveExecutedPostInstallHook {
    param([String] $Module)

    $modulePath = Get-UserModulePath
    if ($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }

    $expectedInstallationPath = Join-Path -Path $modulePath -ChildPath $Module
    $installedPath = Join-Path -Path $expectedInstallationPath -ChildPath "installed.txt"

    #Verify that the installed.txt was created
    if (-not (Test-Path $installedPath)) {
        throw "Post-install-hook of $Module was not executed"
    }

    return $true
}

function PesterHaveExecutedPostInstallHookFailureMessage {
    param([String] $Module)
    process {
        return "$Module's post-install-hook not executed"
    }
}

function PesterNotHaveExecutedPostInstallHook {
    param([String] $Module)

    $modulePath = Get-UserModulePath
    if ($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }

    $expectedInstallationPath = Join-Path -Path $modulePath -ChildPath $Module
    $installedPath = Join-Path -Path $expectedInstallationPath -ChildPath "installed.txt"

    #Verify that the installed.txt was created
    if (Test-Path $installedPath) {
        throw "$Module's post-install-hook executed against request"
    }

    return $true
}

function PesterNotHaveExecutedPostInstallHookFailureMessage {
    param([String] $Module)
    process {
        return "$Module's post-install-hook executed against request"
    }
}

function PesterHaveExecutedPostUpdateHook {
    param([String] $Module)
    process {
        $modulePath = Get-UserModulePath
        if ($args -and $args[0] -and (Test-Path $args[0])) {
            $modulePath = $args[0]
        }

        $expectedInstallationPath = Join-Path -Path $modulePath -ChildPath $Module
        $installedPath = Join-Path -Path $expectedInstallationPath -ChildPath "updated.txt"

        #Verify that the installed.txt was created
        if (-not (Test-Path $installedPath)) {
            throw "Post-update-hook of $Module was not executed"
        }

        return $true
    }
}

function PesterHaveExecutedPostUpdateHookFailureMessage {
     param($Module)
     return "$Module's post-update-hook not executed"
}

function PesterNotHaveExecutedPostUpdateHook {
    param([String] $Module)
    process {
        $modulePath = Get-UserModulePath
        if ($args -and $args[0] -and (Test-Path $args[0])) {
            $modulePath = $args[0]
        }

        $expectedInstallationPath = Join-Path -Path $modulePath -ChildPath $Module
        $installedPath = Join-Path -Path $expectedInstallationPath -ChildPath "updated.txt"

        #Verify that the installed.txt was created
        if (Test-Path $installedPath) {
            throw "$Module's post-update-hook executed against request"
        }

        return $true
    }
}

function PesterNotHaveExecutedPostUpdateHookFailureMessage {
     param($Module)
     return "$Module's post-update-hook executed against request"
}
#endregion