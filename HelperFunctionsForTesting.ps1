function Invoke-InSandbox {
    param (
        [Switch] $Global,
        [ScriptBlock] $test = $(Throw 'No test script block is provided. (Have you put the open curly brace on the next line?)')
    )
    process {
        Enter-Sandbox -Global:$Global
        try {
            & $test
        }
        finally {
            Exit-Sandbox -Global:$Global
        }
    }
}

function Enter-Sandbox {
    param (
        [Switch] $Global
    )
    process {
        Write-Debug 'Enter into Sandbox'
        $script:backup_UserModuleBasePath = $global:UserModuleBasePath
        $script:backup_CommonGlobalModuleBasePath = $global:CommonGlobalModuleBasePath
        $script:backup_PsGetDirectoryUrl = $global:PsGetDirectoryUrl
        if (Test-Path 'Variable:\global:PsGetDestinationModulePath') {
            $script:backup_PsGetDestinationModulePath = $global:PsGetDestinationModulePath
            Remove-Variable -Name PsGetDestinationModulePath -Scope Global
        }

        $testDrive = (Get-Item 'TestDrive:\').FullName
        $global:UserModuleBasePath = ConvertTo-CanonicalPath -Path "$testDrive\user"
        $global:CommonGlobalModuleBasePath = ConvertTo-CanonicalPath -Path "$testDrive\machine"
        $global:PsGetDirectoryUrl = 'https://github.com/psget/psget/raw/master/Directory.xml'

        $script:backup_PSModulePathUser = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
        $script:backup_PSModulePathProcess = [Environment]::GetEnvironmentVariable('PSModulePath', 'Process')

        if ($Global) {
            $script:backup_PSModulePathMachine = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
        }
    }
}

function Exit-Sandbox {
    param (
        [Switch] $Global
    )
    process {
        Write-Debug 'Exit from Sandbox'
        $global:UserModuleBasePath = $script:backup_UserModuleBasePath
        $global:CommonGlobalModuleBasePath = $script:backup_CommonGlobalModuleBasePath
        $global:PsGetDirectoryUrl = $script:backup_PsGetDirectoryUrl

        if (Test-Path 'Variable:\script:backup_PsGetDestinationModulePath') {
            $global:PsGetDestinationModulePath = $script:backup_PsGetDestinationModulePath
        }
        elseif (Test-Path 'Variable:\global:PsGetDestinationModulePath') {
            Remove-Variable -Name PsGetDestinationModulePath -Scope Global
        }

        [Environment]::SetEnvironmentVariable('PSModulePath', $script:backup_PSModulePathUser, 'User')
        [Environment]::SetEnvironmentVariable('PSModulePath', $script:backup_PSModulePathProcess, 'Process')

        if ($Global) {
            [Environment]::SetEnvironmentVariable('PSModulePath', $script:backup_PSModulePathMachine, 'Machine')
        }
    }
}

function Drop-Module {
    param (
        [String] $Module,

        [Switch] $Global
    )
    process {
        Remove-Module $Module -Force -ErrorAction SilentlyContinue

        if ($Global) {
            if ((Test-Path $global:CommonGlobalModuleBasePath/$Module/)) {
                Remove-Item $global:CommonGlobalModuleBasePath/$Module/ -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        elseif ((Test-Path $UserModulePath/$Module/)) {
            Remove-Item $UserModulePath/$Module/ -Force -Recurse -ErrorAction SilentlyContinue
        }

        #Delete all installations of this module that are locatable via the PSModulePath
        Get-Module -Name $Module -ListAvailable | foreach {
            Remove-Item $_.ModuleBase -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}

function Install-ModuleOutOfProcess {
    param(
        [String] $Module,

        [String] $FunctionNameToVerify,

        [String] $Destination,

        [String] $PackageVersion
    )
    process {
        # run this test out-of-process so the binary module can be removed without locking issues
        & powershell -noprofile -command {
            param ($here, $Module, $FunctionNameToVerify, $PackageVersion)
            Import-Module -Name "$here\PsGet\PsGet.psm1"

            Install-module -NugetPackageId $Module -DoNotImport -PackageVersion $PackageVersion  -Update
            if (-not (Get-Command -Name $FunctionNameToVerify -Module $module)) {
                throw "$Module not installed"
            }
        } -args $here, $Module, $FunctionNameToVerify, $PackageVersion
    }
}

function ConvertTo-CanonicalPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $Path
    )
    process {
        return [IO.Path]::GetFullPath(($Path.Trim()))
    }
}

function Get-TempDir {
    process {
        return Join-Path -Path ((Get-Item 'TestDrive:\').FullName) -ChildPath ([Guid]::NewGuid().ToString())
    }
}

function Remove-PathFromPSModulePath {
    param(
        [Parameter(Mandatory=$true)]
        [String] $PathToRemove,
        [Switch] $Global
    )
    process {
        $scope = 'User'
        if ($Global) {
            $scope = 'Machine'
        }

        $existingPathValue = [Environment]::GetEnvironmentVariable('PSModulePath', $scope)
        $PathToRemove = ConvertTo-CanonicalPath -Path $PathToRemove
        $newPathValue = ''
        if ($existingPathValue) {
            $paths = $existingPathValue.Split(';') | foreach { ConvertTo-CanonicalPath -Path $_ } | Where { $_ -ne $pathToRemove }
            $newPathValue = $paths -join ';'
        }

        #Only update the environment variable
        if ($existingPathValue -ne $newPathValue) {
            [Environment]::SetEnvironmentVariable('PSModulePath', $newPathValue, $scope)

            Update-PSModulePath

            #Just print out the new value for verbose
            $newSessionValue = Get-Content -Path 'env:\PSModulePath'
            Write-Verbose "The new value of the '$scope' environment variable 'PSModulePath' is '$newSessionValue'"
        }
        else {
            Write-Verbose  "The new value of the '$scope' environment variable 'PSModulePath' is the same as the existing value, will not update"
        }
    }
}

<#
    .SYNOPSIS
        Update '$env:PSModulePath' from 'User' and 'Machine' scope envrionment variables
#>
function Update-PSModulePath {
    process {
        # powershell default
        $psModulePath = "$env:ProgramFiles\WindowsPowershell\Modules\"

        $machineModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
        if (-not $machineModulePath) {
            # powershell default
            $machineModulePath = Join-Path -Path $PSHOME -ChildPath 'Modules'
        }

        $userModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
        if (-not $userModulePath) {
            # powershell default
            $userModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules'
        }

        $newSessionValue = "$userModulePath;$machineModulePath;$psModulePath"

        #Set the value in the current process
        [Environment]::SetEnvironmentVariable('PSModulePath', $newSessionValue, 'Process')
    }
}

function Get-UserModulePath {
    process {
        return $global:UserModuleBasePath
    }
}