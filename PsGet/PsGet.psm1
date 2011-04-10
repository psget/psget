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
	[String]$ModuleName,
	[String]$Type
)

	$ZIP = "ZIP"
	$PSM1 = "PSM1"
	$CandidateFilePath = ""	
	$CandidateFileName = ""	
	
	function Unzip([String]$inp, $dest){
		# From http://serverfault.com/questions/18872/how-to-zip-unzip-files-in-powershell/201604#201604
		$shellApp = New-Object -Com Shell.Application		
		$zipFile = $shellApp.namespace($inp) 
		if ((Test-Path $dest) -eq $false) { New-Item $dest -ItemType Directory }
		$destination = $shellApp.namespace($dest) 		
		$destination.Copyhere($zipFile.items())
	}
	
	function TryGuessFileName($client){	
		## Try get module name from content disposition header (e.g. attachment; filename="Pscx-2.0.0.1.zip" )
		$contentDisposition = $client.ResponseHeaders["Content-Disposition"]						
		$nameMatch = [regex]::match($contentDisposition, "filename=""(?'name'[^/]+\.(psm1|zip))""")
		if ($nameMatch.Groups["name"].Success) {
			return $nameMatch.Groups["name"].Value
		}
				
		## Na¿ve try to guess name from URL
        $nameMatch = [regex]::match($Module, "/(?'name'[^/]+\.(psm1|zip))[\#\?]*")
		if ($nameMatch.Groups["name"].Success) {
			return $nameMatch.Groups["name"].Value
		}
	}
	
	function TryGuessTypeByExtension($fileName){
		if ($fileName -like "*.zip"){
			return $ZIP
		} 
		if ($fileName -like "*.psm1"){
			return $PSM1
		}	
		return $PSM1
	}
	
	function TryGuessType($client, $fileName){	
		$contentType = $client.ResponseHeaders["Content-Type"]
		Write-Host $contentType
		if ($contentType -eq "application/zip"){
			return $ZIP
		} 		
		return TryGuessTypeByExtension $fileName				
	}
	    
	## If module name starts with HTTP we will try to download this guy yo local folder.
    if ($Module.StartsWith("http")){
		$client = (new-object System.Net.WebClient)
		$CandidateFilePath = [System.IO.Path]::GetTempFileName()
		$client.DownloadFile($Module, $CandidateFilePath)
		$CandidateFileName = TryGuessFileName $client
			
		
		if ($Type -eq ""){
			$Type = TryGuessType $client $CandidateFileName
		}		
		if ($Type -eq $ZIP){
			$TmpCandidateFilePath = $CandidateFilePath
			$CandidateFilePath = [System.IO.Path]::ChangeExtension($CandidateFilePath, ".zip")
			[System.IO.File]::Move($TmpCandidateFilePath, $CandidateFilePath)
		}
    } else {
		$CandidateFilePath = Resolve-Path $Module
		$CandidateFileName = [System.IO.Path]::GetFileName($CandidateFilePath)		
		if ($Type -eq ""){		
			$Type = TryGuessTypeByExtension $CandidateFileName
		}		
	}
	
	if ($Type -eq ""){				
		throw "Cannot guess module type. Try specify Type argument. Applicable values are 'ZIP' or 'PSM' "
	}
	
	## Prepare module folder
	$TempModuleFolderPath = ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ([System.Guid]::NewGuid().ToString() + "\")))	
	if ($Type -eq $ZIP){		
		Write-Host $CandidateFilePath
		Unzip $CandidateFilePath $TempModuleFolderPath
	}
	else {
		Copy-Item $CandidateFilePath $TempModuleFolderPath
	}
		
	## Lets try guess module name
	if ($ModuleName -eq ""){
		
		if ($Type -eq $ZIP){			
			$BestCandidateModule = (Get-ChildItem $TempModuleFolderPath -Filter "*.psm1" -Recurse | select -Index 0).FullName
			$ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($BestCandidateModule)
			## We assume that module definition is located in root folder of the module
			## So we can easy rebase root of the temp destination
			$TempModuleFolderPath = [System.IO.Path]::GetDirectoryName($BestCandidateModule)			
		}
		else {
			$ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($CandidateFileName)
		}		
	}
	
	if ($ModuleName -eq ""){				
		throw "Cannot guess module name. Try specify ModuleName argument."
	}
	
	
	    
    ## Note: This assumes that your PSModulePath is unaltered
    ## Or at least, that it has the LOCAL path first and GLOBAL path second
    $PSModulePath = $Env:PSModulePath -split ";" | Select -Index ([int][bool]$Global)

    ## Make a folder for the module
	$ModuleFolderPath = ([System.IO.Path]::Combine($PSModulePath, $ModuleName))
	
	if ((Test-Path $ModuleFolderPath) -eq $false) {
	    $ModuleFolder = New-Item $ModuleFolderPath -ItemType Directory -EA 0 -EV FailMkDir
	    ## Handle the error if they asked for -Global and don't have permissions
	    if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
	        if($Global) {
	            throw "You must be elevated to install a global module."
	        } else { throw @($FailMkDir)[0] }
	    }		
	}
	
	Get-ChildItem $TempModuleFolderPath | Copy-Item -Destination $ModuleFolderPath -Force -Recurse
	
    ## Output A ModuleInfo object
    Get-Module $ModuleName -List
<#
.Synopsis
    Installs a module. Only PSM1 modules are supported.
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
