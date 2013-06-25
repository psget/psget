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

function Remove-PathFromEnvironmentVariable {
    param(
    [Parameter(Mandatory=$true)]
    [string]$VariableName, 
    [System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User,
    [Parameter(Mandatory=$true)]
    [string]$PathToRemove,
    [switch]$PersistEnvironment)
   
    $existingPathValue = [Environment]::GetEnvironmentVariable($variableName, $Scope)
    Write-Verbose "The existing value of the '$Scope' environment variable '$variableName' is '$existingPathValue'"
    $pathToRemove = Canonicolize-Path $PathToRemove
    Write-Verbose "Path: $pathToAdd"

    #Canonicolize and cliean up path variable
    $newPathValue = Remove-PathFromEnvironmentPath  "$existingPathValue" $pathToRemove

    #Only update the environment variable
    if($existingPathValue -notlike $newPathValue) {
        if($PersistEnvironment) {
            #Set the new value
            [Environment]::SetEnvironmentVariable($variableName,$newPathValue, $Scope)
        }

        #Import the value into the current session (Process)
        Import-GlobalEnvironmentVariableToSession -VariableName $variableName

        #Just print out the new value for verbose
        $newSessionValue = gc "env:\$variableName"
        Write-Verbose "The new value of the '$Scope' environment variable '$variableName' is '$newSessionValue'"
    } else {
        Write-Verbose  "The new value of the '$Scope' environment variable '$variableName' is the same as the existing value, will not update"
    }

}

function Get-UserModulePath {
    return $global:UserModuleBasePath
}