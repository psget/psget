
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

    $modulePath = ConvertTo-CanonicalPath -path (Get-UserModulePath)

    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = ConvertTo-CanonicalPath -path $args[0]
    }

    $paths = $env:PSModulePath -split ";" | foreach { ConvertTo-CanonicalPath -Path $_ }

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
    $modulePath = Get-UserModulePath
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

    $modulePath = Get-UserModulePath
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

    $modulePath = Get-UserModulePath
    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }

    $expectedInstallationPath = Join-Path -Path $ModulePath -ChildPath $Module
    $baseFilename = join-path $expectedInstallationPath $Module

    try {
        #Get the module by name
        $foundmodule = get-module -Name $module -ListAvailable
        $foundModuleInExactLocation = $foundmodule|where {[io.path]::GetDirectoryName($_.Path) -like $expectedInstallationPath}

        #Verify that the module exists in the correct location
        if(-not $foundModuleInExactLocation) {
            return $false
        }
    } catch {
        # Powershell v2 Get-Module returns cached entries for freshly deleted module which contains an error message instead if a path
        # therefore GetDirectoryName throws an error which we need to catch.
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

    $modulePath = Get-UserModulePath
    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }

    $expectedInstallationPath = Join-Path -Path $ModulePath -ChildPath $Module
    $baseFilename = join-path $expectedInstallationPath $Module


    #Verify that the module (DLL or PSM1) exists
    if (-not (Test-Path "$baseFileName.psm1") -and -not (Test-Path "$baseFileName.dll")){
        throw "Module $Module was not installed at '$baseFileName.psm1' or '$baseFileName.dll'"
    }

    return $true
}

function PesterBeInstalledGlobally {
    param(
    $Module
    )
<#
.SYNOPSIS
Ensures that a module exists, can be imported, and can be listed using the $env:PSModulePath envrionment variable

#>

    $modulePath = $global:CommonGlobalModuleBasePath
    if($args -and $args[0] -and (Test-Path $args[0])) {
        $modulePath = $args[0]
    }

    $expectedInstallationPath = Join-Path -Path $ModulePath -ChildPath $Module
    $baseFilename = join-path $expectedInstallationPath $Module


    #Verify that the module (DLL or PSM1) exists
    if (-not (Test-Path "$baseFileName.psm1") -and -not (Test-Path "$baseFileName.dll")){
        throw "Module $Module was not installed at '$baseFileName.psm1' or '$baseFileName.dll'"
    }

    return $true
}


function PesterBeInstalledFailureMessage {
     param($Module)
     return "$Module was not installed"
}
#endregion