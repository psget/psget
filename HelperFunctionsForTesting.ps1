
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