##
##    PowerShell module installation stuff.
##    Based on http://poshcode.org/1875 Install-Module by Joel Bennett 
##

function Install-Module {
[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]    
    [String]$Module,
	[Switch]$Global = $false
)
    function EnsureModuleIsLocal(){		
        if ($Module.StartsWith("http")){
			# Na¿ve try to guess name. At list need to parse headers to get 
			# module name or accept it as arguments...
            $nameMatch = [regex]::match($Module, "/(?'name'[^/]*).psm1[\#\?]*")		
			if ($nameMatch.Groups["name"].Success -eq $false) {
				Write-Error "Cannot guess name of the module from URL. Module URL should be in form of 'http://example.com/FooModule.psm1'"
				exit
			}
			$moduleName = $nameMatch.Groups["name"].Value
			$tempModulePath = ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $moduleName + ".psm1"))
			Write-Host $tempModulePath
           	(new-object System.Net.WebClient).DownloadFile($Module, $tempModulePath)
			$tempModulePath
        } else {
			Resolve-Path $ModuleFilePath
		}
    }

    ## Get the Full Path of the module file
    $ModuleFilePath = EnsureModuleIsLocal
    
    ## Deduce the Module Name from the file name
    $ModuleName = (Get-ChildItem $ModuleFilePath).BaseName
    
    ## Note: This assumes that your PSModulePath is unaltered
    ## Or at least, that it has the LOCAL path first and GLOBAL path second
    $PSModulePath = $Env:PSModulePath -split ";" | Select -Index ([int][bool]$Global)

    ## Make a folder for the module
    $ModuleFolder = MkDir $PSModulePath\$ModuleName -EA 0 -EV FailMkDir
    ## Handle the error if they asked for -Global and don't have permissions
    if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
        if($Global) {
            throw "You must be elevated to install a global module."
        } else { throw @($FailMkDir)[0] }
    }

    ## Move the script module (and make sure it ends in .psm1)
    Move-Item $ModuleFilePath $ModuleFolder

    ## Output A ModuleInfo object
    Get-Module $ModuleName -List
<#
.Synopsis
    Installs a single-file (psm1 or dll) module to the ModulePath
.Description 
    Supports installing modules for the current user or all users (if elevated)
.Parameter Module
    The path or URL to the module file to be installed
.Parameter Global
    If set, attempts to install the module to the all users location in Windows\System32...
.Example
    Install-Module .\Authenticode.psm1 -Global

    Description
    -----------
    Installs the Authenticode module to the System32\WindowsPowerShell\v1.0\Modules for all users to use.
	
.Example
    # Install-Module https://github.com/chaliy/psurl/raw/master/PsUrl.psm1

    Description
    -----------
    Installs the PsUrl module to the users modules folder

#>
}

Export-ModuleMember Install-Module
