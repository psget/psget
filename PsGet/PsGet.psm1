##
##    PowerShell module installation stuff.
##    URL: https://github.com/chaliy/psget
##    Based on http://poshcode.org/1875 Install-Module by Joel Bennett 
##

#requires -Version 2.0
function Install-Module {
[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]    
    [String]$Module,
	[Switch]$Global,
	[String]$ModuleName,
	[String]$Type,
    [Switch]$DoNotImport = $false,
    [Switch]$Startup = $false
)

    if($PSVersionTable.PSVersion.Major -lt 2) {
        Write-Error "PsGet requires PowerShell 2.0 or better; you have version $($Host.Version)."    
        return
    }
        
    Write-Verbose "Installing module $Module"

	$ZIP = "ZIP"
	$PSM1 = "PSM1"
	$CandidateFilePath = ""	
	$CandidateFileName = ""	
	
	function Unzip([String]$inp, $dest){
		Write-Verbose "Unzip $inp to $dest"
		# From http://serverfault.com/questions/18872/how-to-zip-unzip-files-in-powershell/201604#201604
		$shellApp = New-Object -Com Shell.Application		
		$zipFile = $shellApp.namespace($inp) 		
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
		if ($contentType -eq "application/zip"){
			return $ZIP
		} 		
		return TryGuessTypeByExtension $fileName				
	}
	    
	## If module name starts with HTTP we will try to download this guy yo local folder.
    if ($Module.StartsWith("http")){
		Write-Verbose "Module spec is starting from HTTP, so let us try to download it"
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
			Move-Item $TmpCandidateFilePath $CandidateFilePath -Force
		}
		if ($Type -eq $PSM1){			
			if ($ModuleName -ne ""){
				$CandidateFileName = ($ModuleName + ".psm1")
			}
			$TmpCandidateFilePath = $CandidateFilePath			
			$CandidateFilePath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($CandidateFilePath), $CandidateFileName)			
			Move-Item $TmpCandidateFilePath $CandidateFilePath -Force
		}
    } else {
		$CandidateFilePath = Resolve-Path $Module
		$CandidateFileName = [System.IO.Path]::GetFileName($CandidateFilePath)		
		if ($Type -eq ""){		
			$Type = TryGuessTypeByExtension $CandidateFileName
		}		
	}
	
	if ($Type -eq ""){				
		throw "Cannot guess module type. Try specifying Type argument. Applicable values are 'ZIP' or 'PSM' "
	}
	
	## Prepare module folder
	$TempModuleFolderPath = ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ([System.Guid]::NewGuid().ToString() + "\")))	
	if ((Test-Path $TempModuleFolderPath) -eq $false) { New-Item $TempModuleFolderPath -ItemType Directory | Out-Null }	
	if ($Type -eq $ZIP){		
		Write-Verbose "Type of the module is ZIP so, let us try unzip it"

		Unzip $CandidateFilePath $TempModuleFolderPath
	}
	else {			
		Copy-Item $CandidateFilePath $TempModuleFolderPath
	}
		
	## Let’s try guessing module name
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
		throw "Cannot guess module name. Try specifying ModuleName argument."
	}
	    
    ## Note: This assumes that your PSModulePath is unaltered
    ## Or at least, that it has the LOCAL path first and GLOBAL path second
    $PSModulePath = $Env:PSModulePath -split ";" | Select -Index ([int][bool]$Global)

    ## Make a folder for the module
	$ModuleFolderPath = ([System.IO.Path]::Combine($PSModulePath, $ModuleName))
	
	if ((Test-Path $ModuleFolderPath) -eq $false) {
	    New-Item $ModuleFolderPath -ItemType Directory -ErrorAction Continue -ErrorVariable FailMkDir | Out-Null
	    ## Handle the error if they asked for -Global and don't have permissions
	    if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
	        if($Global) {
	            throw "You must be elevated to install a global module."
	        } else { throw @($FailMkDir)[0] }
	    }		
		Write-Verbose "Create module folder at $ModuleFolderPath"
	}
	
    # Copy module files to destination folder
	Get-ChildItem $TempModuleFolderPath | Copy-Item -Destination $ModuleFolderPath -Force -Recurse
    
    # Try to run Install.ps1 if any
    $Install = ($ModuleFolderPath + "\Install.ps1")
    if (Test-Path $Install){
        Write-Verbose "Install.ps1 file found in module. Let's executing it."
        & $Install
    }
	
    ## Check if something was installed
    if (-not(Get-Module $ModuleName -ListAvailable)){
		throw "For some unexpected reasons module was not installed."
	} else {
		Write-Host "Module $ModuleName was successfully installed." -Foreground Green
	}
    
    if ($DoNotImport -eq $false){
        Import-Module $ModuleName
    }
    
    if ($Startup -eq $true){
        # WARNING $Profile is empty on Win2008R2 under Administrator
        $ProfileDir = $(split-path -parent $Profile)
        $AllProfile = ($ProfileDir + "/profile.ps1")
        if(!(Test-Path $AllProfile)) {
            Write-Verbose "Creating PowerShell profile...`n$AllProfile"
            New-Item $AllProfile -Type File -Force -ErrorAction Stop
        }
        if (Select-String $AllProfile -Pattern "Import-Module $ModuleName"){
            Write-Verbose "Import-Module $ModuleName command already in your profile"
        } else {
            Write-Verbose "Add Import-Module $ModuleName command to the profile"
            "`nImport-Module $ModuleName" | Add-Content $AllProfile
        }
    }

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
.Parmeter DoNotImport
    Indicates that command should not import module after intsallation.
.Parmeter $Startup
    Adds installed module to the profile.ps1.
    
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
    Installs the PsUrl module with name specified, because command will not be able to guess it
	
.Example
    # Install-Module https://github.com/chaliy/psget/raw/master/TestModules/HelloWorld.zip

    Description
    -----------
    Downloads HelloWorld module (module can have more than one file) and installs it
    
.Example
    # Install-Module https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1 -DoNotImport

    Description
    -----------
    Installs the module witout importing it to the current session
    
.Example
    # Install-Module https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1 -Startup

    Description
    -----------
    Installs the module and then adds impoer of the given module to your profile.ps1 file

#>
}

Export-ModuleMember Install-Module
