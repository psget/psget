##
##    PowerShell module installation stuff.
##    URL: https://github.com/chaliy/psget
##    Based on http://poshcode.org/1875 Install-Module by Joel Bennett 
##

#requires -Version 2.0
$PSGET_ZIP = "ZIP"
$PSGET_PSM1 = "PSM1"

function Install-Module {
[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0, ParameterSetName="Repo")]    
    [String]$Module,
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, ParameterSetName="Web")]
    [String]$ModuleUrl,    
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, ParameterSetName="Local")]
    $ModulePath,        
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Web")]
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Local")]
    [String]$ModuleName,
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Web")]
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Local")]
    [String]$Type,
    [Switch]$Global = $false,
    [Switch]$DoNotImport = $false,
    [Switch]$Startup = $false,
    [Switch]$Force = $false,
    [String]$DirectoryUrl = "https://github.com/chaliy/psget/raw/master/Directory.xml"
)

    if($PSVersionTable.PSVersion.Major -lt 2) {
        Write-Error "PsGet requires PowerShell 2.0 or better; you have version $($Host.Version)."    
        return
    }
        
    switch($PSCmdlet.ParameterSetName) {
        "Repo"   {            
            if (-not (CheckIfNeedInstallAndImportIfNot $Module $Force $DoNotImport)){
                return;
            }
            
            Write-Verbose "Module $Module will be installed from central repository"		                                
            $moduleData = Get-PsGetModuleInfo $Module -DirectoryUrl:$DirectoryUrl | select -First 1             
            if (!$moduleData){
                throw "Module $Module was not found in central repository"
            }
            
            $Type = $moduleData.Type        
            $ModuleName = $moduleData.Id    
            
            $downloadResult = DumbDownloadModuleFromWeb -DownloadURL:$moduleData.DownloadUrl -ModuleName:$moduleData.Id -Type:$Type
                                        
            $TempModuleFolderPath = $downloadResult.ModuleFolderPath            
            break
        }
        "Web" {			
            Write-Verbose "Module will be installed from $ModuleUrl"
            
            $result = DownloadModuleFromWeb -DownloadURL:$ModuleUrl -ModuleName:$ModuleName -Type:$Type
                                    
            $Type = $result.Type
            $ModuleName = $result.ModuleName
            $TempModuleFolderPath = $result.ModuleFolderPath
                        
            if ($Type -eq ""){
                throw "Cannot guess module type. Try specifying Type argument. Applicable values are 'ZIP' or 'PSM' "
            }    
                            
            if ($ModuleName -eq ""){
                throw "Cannot guess module name. Try specifying ModuleName argument"
            }
            
            break
        }
        "Local" {
            Write-Verbose "Module will be installed local path"
            $CandidateFilePath = Resolve-Path $ModulePath
            $CandidateFileName = [IO.Path]::GetFileName($CandidateFilePath)        
            if ($Type -eq ""){
                $Type = TryGuessTypeByExtension $CandidateFileName
            }
            
            ## Prepare module folder
            $TempModuleFolderPath = join-path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())                
            New-Item $TempModuleFolderPath -ItemType Directory | Out-Null    
            if ($Type -eq $PSGET_ZIP){                        
                UnzipModule $CandidateFilePath $TempModuleFolderPath
            }
            else {            
                Copy-Item $CandidateFilePath $TempModuleFolderPath
            }					    
                
            ## Let’s try guessing module name
            if ($ModuleName -eq ""){		        		        
                $BestCandidateModule = (Get-ChildItem $TempModuleFolderPath -Filter "*.psm1" -Recurse | select -Index 0).FullName
                $ModuleName = [IO.Path]::GetFileNameWithoutExtension($BestCandidateModule)
            }
            
            if ($ModuleName -eq ""){                
                throw "Cannot guess module name. Try specifying ModuleName argument."
            }
            
            if ($Type -eq ""){                
                throw "Cannot guess module type. Try specifying Type argument. Applicable values are 'ZIP' or 'PSM' "
            }
        }
    }
                            
    ## Normalize child directory    
    if (!(Test-Path (Join-Path $TempModuleFolderPath ($ModuleName + ".psm1")))){
        $ModulePath = (Get-ChildItem $TempModuleFolderPath -Filter "$ModuleName.psm1" -Recurse | select -Index 0)
        $TempModuleFolderPath = $ModulePath.DirectoryName
    }
       
    InstallModuleFromLocalFolder -SourceFolderPath:$TempModuleFolderPath -ModuleName:$ModuleName -Global:$Global -DoNotImport:$DoNotImport -Startup:$Startup -Force:$Force

<#
.Synopsis
    Installs a module. Only PSM1 modules are supported.
.Description 
    Supports installing modules for the current user or all users (if elevated)
.Parameter Module
    Name of the module to install.
.Parameter ModuleUrl
    URL to the module to install; Can be direct link to PSM1 file or ZIP file. Can be shortned link.
.Parameter ModulePath
    Local path to the module to install.
.Parameter Type
    When ModuleUrl or ModulePath specified, allowas specifing type of the package. Can be ZIP or PSM1.
.Parameter ModuleName
    When ModuleUrl or ModulePath specified, allowas specifing name of the module.
.Parameter Global
    If set, attempts to install the module to the all users location in Windows\System32...    
.Parmeter DoNotImport
    Indicates that command should not import module after intsallation
.Parmeter Startup
    Adds installed module to the profile.ps1
.Parmeter DirectoryUrl
    URL to central directory. By default it is https://github.com/chaliy/psget/raw/master/Registry.xml
.Link
    http://psget.net       
    
    
.Example
    # Install-Module PsConfig -DoNotImport

    Description
    -----------
    Installs the module witout importing it to the current session
    
.Example
    # Install-Module PoshHg -Startup

    Description
    -----------
    Installs the module and then adds impoer of the given module to your profile.ps1 file
    
.Example
    # Install-Module PsUrl

    Description
    -----------
    This command will query module information from central registry and install required stuff.
	
.Example
    Install-Module -ModulePath .\Authenticode.psm1 -Global

    Description
    -----------
    Installs the Authenticode module to the System32\WindowsPowerShell\v1.0\Modules for all users to use.
    
.Example
    # Install-Module -ModuleUrl https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1

    Description
    -----------
    Installs the PsUrl module to the users modules folder
    
.Example
    # Install-Module -ModuleUrl http://bit.ly/e1X4BO -ModuleName "PsUrl"

    Description
    -----------
    Installs the PsUrl module with name specified, because command will not be able to guess it
    
.Example
    # Install-Module -ModuleUrl https://github.com/chaliy/psget/raw/master/TestModules/HelloWorld.zip

    Description
    -----------
    Downloads HelloWorld module (module can have more than one file) and installs it

#>
}

function Get-PsGetModuleInfo {
[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]        
    [String]$ModuleName,
    [String]$DirectoryUrl = "https://github.com/chaliy/psget/raw/master/Directory.xml"
)
    Write-Verbose "Downloading modules repository from $DirectoryUrl"
    $client = (new-object Net.WebClient)
    $repoXml = [xml]$client.DownloadString($DirectoryUrl)
    
    
    $nss = @{ a = "http://www.w3.org/2005/Atom";
              pg = "urn:psget:v1.0" }
    
    $feed = $repoXml.feed
    $title = $feed.title.innertext
    Write-Verbose "Processing $title feed..."
    
    # Very naive, ignoring namespases and so on.    
    $feed.entry | ?{ $_.id -like $ModuleName } | %{ 
        $Type = ""
        switch -regex ($_.content.type) {
            "application/zip" { $Type = $PSGET_ZIP  }
            default { $Type = $PSGET_PSM1  }
        }
        
        New-Object PSObject -Property @{
            "Title" = $_.title.innertext
            "Id" = $_.id
            "Type" = $Type
            "DownloadUrl" = $_.content.src
        }                
    }           
<#
.Synopsis
    Retrieve infromation about module from central directory
.Description 
    Command query contral directory (https://github.com/chaliy/psget/raw/master/TestModules/Directory.xml) to get information about module specified.
.Parmeter $DirectoryUrl
    URL to central directory. By default it is https://github.com/chaliy/psget/raw/master/Registry.xml
.Link
    http://psget.net
.Example
    Get-PsGetModuleInfo PoshCo*

    Description
    -----------
    Retrieves information about all registerd modules that starts with PoshCo.

#>
}

function CheckIfNeedInstallAndImportIfNot($ModuleName, $Force, $DoNotImport){
    if (($Force -eq $false) -and (Get-Module $ModuleName -ListAvailable)){
        Write-Verbose "$ModuleName already installed. Use -Force if you need reinstall"
        if ($DoNotImport -eq $false){
            Import-Module $ModuleName -Global
        }
        return $false
    }
    return $true
}

function UnzipModule($inp, $dest){

    $inp = Resolve-Path $inp
    
    if ($inp.Exntesion -ne ".zip"){
        $PSGET_ZIPFolderPath = [IO.Path]::ChangeExtension($inp, ".zip")            
        Rename-Item $inp $PSGET_ZIPFolderPath -Force    
        $inp = $PSGET_ZIPFolderPath;
    }

    Write-Verbose "Unzip $inp to $dest"
    # From http://serverfault.com/questions/18872/how-to-zip-unzip-files-in-powershell/201604#201604
    $shellApp = New-Object -Com Shell.Application        
    $PSGET_ZIPFile = $shellApp.namespace([String]$inp)         
    $destination = $shellApp.namespace($dest)         
    $destination.Copyhere($PSGET_ZIPFile.items())
}

function TryGuessTypeByExtension($fileName){
    if ($fileName -like "*.zip"){
        return $PSGET_ZIP
    } 
    if ($fileName -like "*.psm1"){
        return $PSGET_PSM1
    }    
    return $PSGET_PSM1
}

function DumbDownloadModuleFromWeb($DownloadURL, $ModuleName, $Type) {
        
    #Create folder to download module content into	
    $TempModuleFolderPath = join-path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + "\$ModuleName")
    New-Item $TempModuleFolderPath -ItemType Directory | Out-Null
    
    # Client to download module stuff
    $client = (new-object Net.WebClient)
    
    $DownloadFilePath = [System.IO.Path]::GetTempFileName()
    $client.DownloadFile($DownloadURL, $DownloadFilePath)
    
    switch ($Type) {
        $PSGET_ZIP { 
            UnzipModule $DownloadFilePath $TempModuleFolderPath
        }
        
        $PSGET_PSM1 {
            $CandidateFileName = ($ModuleName + ".psm1") 
            $CandidateFilePath =  Join-Path $TempModuleFolderPath $CandidateFileName
            Move-Item $DownloadFilePath $CandidateFilePath -Force            
        }
        default {
            throw "Type $Type is not supported yet"
        }
    }
                  
    return @{
        ModuleFolderPath = $TempModuleFolderPath;        
    }
}

function DownloadModuleFromWeb {
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]    
    [String]$DownloadURL,    
    [String]$ModuleName,
    [String]$Type
)    
    function TryGuessFileName($client, $downloadUrl){    
        ## Try get module name from content disposition header (e.g. attachment; filename="Pscx-2.0.0.1.zip" )
        $contentDisposition = $client.ResponseHeaders["Content-Disposition"]                        
        $nameMatch = [regex]::match($contentDisposition, "filename=""(?'name'[^/]+\.(psm1|zip))""")
        if ($nameMatch.Groups["name"].Success) {
            return $nameMatch.Groups["name"].Value
        }
                
        ## Na¿ve try to guess name from URL
        $nameMatch = [regex]::match($downloadUrl, "/(?'name'[^/]+\.(psm1|zip))[\#\?]*")
        if ($nameMatch.Groups["name"].Success) {
            return $nameMatch.Groups["name"].Value
        }
    }        
    
    function TryGuessType($client, $fileName){    
        $contentType = $client.ResponseHeaders["Content-Type"]        
        if ($contentType -eq "application/zip"){
            return $PSGET_ZIP
        }         
        return TryGuessTypeByExtension $fileName                
    }
    
    #Create folder to download module content into
	$TempModuleFolderPath = join-path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())    
    if ((Test-Path $TempModuleFolderPath) -eq $false) { New-Item $TempModuleFolderPath -ItemType Directory | Out-Null }    
    
    # Client to download module stuff
    $client = (new-object Net.WebClient)
    
    $DownloadFilePath = [System.IO.Path]::GetTempFileName()
    $client.DownloadFile($DownloadURL, $DownloadFilePath)
    
    $CandidateFileName = TryGuessFileName $client $downloadUrl        
    
    if ($Type -eq ""){
        $Type = TryGuessType $client $CandidateFileName
    }
    if ($Type -eq $PSGET_ZIP){                        
        UnzipModule $DownloadFilePath $TempModuleFolderPath
    }
    if ($Type -eq $PSGET_PSM1){            
        if ($ModuleName -ne ""){
            $CandidateFileName = ($ModuleName + ".psm1")
        }
        
        $CandidateFilePath =  Join-Path $TempModuleFolderPath $CandidateFileName
        Move-Item $DownloadFilePath $CandidateFilePath -Force            
    }    

    if ($ModuleName -eq ""){
        $BestCandidateModule = (Get-ChildItem $TempModuleFolderPath -Filter "*.psm1" -Recurse | select -Index 0).FullName
        $ModuleName = [IO.Path]::GetFileNameWithoutExtension($BestCandidateModule)
    }
        
    return @{
        ModuleFolderPath = $TempModuleFolderPath;    
        FileName = $CandidateFileName;
        Type = $Type;
        ModuleName = $ModuleName
    }
}

function InstallModuleFromLocalFolder {
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]    
    $SourceFolderPath,
    [Parameter(Mandatory=$true)]
    [String]$ModuleName,    
    [Switch]$Global = $false,    
    [Switch]$DoNotImport = $false,
    [Switch]$Startup = $false,
    [Switch]$Force = $false
)
    if (-not (CheckIfNeedInstallAndImportIfNot $ModuleName $Force $DoNotImport)){
        return;
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
    Get-ChildItem $SourceFolderPath | Copy-Item -Destination $ModuleFolderPath -Force -Recurse
    
    # Try to run Install.ps1 if any
    $Install = ($ModuleFolderPath + "\Install.ps1")
    if (Test-Path $Install){
        Write-Verbose "Install.ps1 file found in module. Let's execute it."
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
}

# Save old tabexpnasion to revert it back when module is unload
# this does not cover all pathes, but most of them
# Idea is stolen from PowerTab
$OldTabExpansion = Get-Content Function:TabExpansion
$Module = $MyInvocation.MyCommand.ScriptBlock.Module 
$Module.OnRemove = {
    Write-Verbose "Revert tab expansion back"
    Set-Content Function:\TabExpansion -Value $OldTabExpansion
}


# Override TabExpansion
# Idea is stolen from posh-git + ps-get
$teBackup = 'PsGet_DefaultTabExpansion'
if(!(Test-Path Function:\$teBackup)) {
    Rename-Item Function:\TabExpansion $teBackup
}

# Set up new tab expansion
Function global:TabExpansion {
    param($line, $lastWord)
            
    if ($line -eq "Install-Module $lastword" -or $line -eq "inmo $lastword")
    {
        Get-PsGetModuleInfo "$lastword*" | % { $_.Id } | sort -Unique
    }    
    else
    {
        & $teBackup $line $lastWord
    }       
}

Set-Alias inmo Install-Module
Export-ModuleMember Install-Module
Export-ModuleMember Get-PsGetModuleInfo
Export-ModuleMember -Alias inmo