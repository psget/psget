##
##    PowerShell module installation stuff.
##    URL: https://github.com/chaliy/psget
##    Based on http://poshcode.org/1875 Install-Module by Joel Bennett 
##

function Install-Module {
[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]    
    [String]$Module,
	[Switch]$Global,
	[String]$ModuleName
)
	
    function EnsureModuleIsLocal(){		
		## If module name starts with HTTP we will try to download this guy yo local folder.
        if ($Module.StartsWith("http")){
			$client = (new-object System.Net.WebClient)
			$tempModulePath = [System.IO.Path]::GetTempFileName()
			$client.DownloadFile($Module, $tempModulePath)
						
			if ($ModuleName -eq ""){
							
				## Try get module name from content disposition header
				$contentDisposition = $client.ResponseHeaders["Content-Disposition"]				
				$nameMatch = [regex]::match($contentDisposition, "filename=""(?'name'[^/]+).psm1""")			
				if ($nameMatch.Groups["name"].Success) {
					$ModuleName = $nameMatch.Groups["name"].Value
				}
				
				## If ModuleName still empty, lets try hardcore
				if ($ModuleName -eq "") {
					## Na¿ve try to guess name from URL
		            $nameMatch = [regex]::match($Module, "/(?'name'[^/]+).psm1[\#\?]*")		
					if ($nameMatch.Groups["name"].Success) {
						$ModuleName = $nameMatch.Groups["name"].Value
					}
				}
			}		
						
			if ($ModuleName -eq ""){				
				throw "Cannot guess module name. Try specify ModuleName argument."
			}						
			
			$tempModulePathWithExtension = ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $moduleName + ".psm1"))			
			Move-Item $tempModulePath $tempModulePathWithExtension
			
			$tempModulePathWithExtension
        } else {
			Resolve-Path $ModuleFilePath
		}
    }

    ## Get the Full Path of the module file
    $ModuleFilePath = EnsureModuleIsLocal
		
	if ($ModuleName -eq ""){
		## Deduce the Module Name from the file name
		$ModuleName = (Get-ChildItem $ModuleFilePath).BaseName
	}    
	
    
    ## Note: This assumes that your PSModulePath is unaltered
    ## Or at least, that it has the LOCAL path first and GLOBAL path second
    $PSModulePath = $Env:PSModulePath -split ";" | Select -Index ([int][bool]$Global)

    ## Make a folder for the module
	$ModuleFolderPath = ([System.IO.Path]::Combine($PSModulePath, $ModuleName))
	
	if (Test-Path $ModuleFolderPath) {
	    $ModuleFolder = New-Item $ModuleFolderPath -ItemType Directory -EA 0 -EV FailMkDir
	    ## Handle the error if they asked for -Global and don't have permissions
	    if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
	        if($Global) {
	            throw "You must be elevated to install a global module."
	        } else { throw @($FailMkDir)[0] }
	    }		
	}
		
    ## Move the script module (and make sure it ends in .psm1)
    Move-Item $ModuleFilePath $ModuleFolderPath -Force

    ## Output A ModuleInfo object
    Get-Module $ModuleName -List
<#
.Synopsis
    Installs a single-file module to the ModulePath. Only PSM1 modules are supported.
.Description 
    Supports installing modules for the current user or all users (if elevated)
.Parameter Module
    The path or URL to the module file to be installed
.Parameter Global
    If set, attempts to install the module to the all users location in Windows\System32...	
.Parameter ModuleName
    Name of the module to install. This is optional argument, in most cases command will be to guess module name automatically.
	
.Example
    Install-Module .\Authenticode.psm1 -Global

    Description
    -----------
    Installs the Authenticode module to the System32\WindowsPowerShell\v1.0\Modules for all users to use.
	
.Example
    # Install-Module https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1

    Description
    -----------
    Installs the PsUrl module to the users modules folder
	
.Example
    # Install-Module http://bit.ly/e1X4BO -ModuleName "PsUrl"

    Description
    -----------
    Installs the PsUrl module with name spcified, because command will not be able to guess it

#>
}

Export-ModuleMember Install-Module
