##
##    PowerShell module installation stuff.
##    URL: https://github.com/psget/psget
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
    [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$true, ParameterSetName="Web")]
    [String]$ModuleUrl,    
    [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$true, ParameterSetName="Local")]
    $ModulePath,        
    [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Web")]
    [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Local")]
    [String]$ModuleName,
    [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Web")]
    [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$false, ParameterSetName="Local")]
    [String]$Type,

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [String]$Destination = $PsGetDestinationModulePath,

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [String]$ModuleHash,

    [Switch]$Global = $false,
    [Switch]$DoNotImport = $false,
    [Switch]$Startup = $false,
    [Switch]$Force = $false,
    [String]$DirectoryUrl = $global:PsGetDirectoryUrl
)

begin {

    if($PSVersionTable.PSVersion.Major -lt 2) {
        Write-Error "PsGet requires PowerShell 2.0 or better; you have version $($Host.Version)."    
        return
    }
}

process {
        
    switch($PSCmdlet.ParameterSetName) {
        "Repo"   {            
            if (-not (CheckIfNeedInstallAndImportIfNot $Module $Force $DoNotImport $ModuleHash)){
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
            
            if (-not (CheckIfNeedInstallAndImportIfNot $ModuleName $Force $DoNotImport $ModuleHash)){
                return;
            }
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
                
            # Let’s try guessing module name
            if ($ModuleName -eq ""){
                $BestCandidateModule = Get-ModuleIdentityFile -Path $TempModuleFolderPath
                $ModuleName = [IO.Path]::GetFileNameWithoutExtension($BestCandidateModule)
                Write-Verbose "Guessed module name: $ModuleName"
            }
            
            if ($ModuleName -eq ""){                
                throw "Cannot guess module name. Try specifying ModuleName argument."
            }
            
            if ($Type -eq ""){                
                throw "Cannot guess module type. Try specifying Type argument. Applicable values are 'ZIP' or 'PSM' "
            }

            if (-not (CheckIfNeedInstallAndImportIfNot $ModuleName $Force $DoNotImport $ModuleHash)){
                return;
            }

        }
        default {
            throw "Unknown ParameterSetName '$($PSCmdlet.ParameterSetName)'"
        }
    }

    ## Normalize child directory    
    if (-not (Test-Path -Path $TempModuleFolderPath\* -Include "$Modulename.psd1","$ModuleName.psm1")) {
        $ModulePath = Get-ModuleIdentityFile -Path $TempModuleFolderPath -ModuleName $ModuleName
        $TempModuleFolderPath = [System.IO.Path]::GetDirectoryName($ModulePath)
        Write-Verbose "Normalized module path to: $TempModuleFolderPath"
    }

    if ($ModuleHash) {
        $TempModuleHash = Get-PsGetModuleHash -Path $TempModuleFolderPath
        Write-Verbose "Hash of module in '$TempModuleFolderPath' is: $TempModuleHash"
        if ($ModuleHash -ne $TempModuleHash) {
            throw "Module contents do not match specified module hash. Ensure the expected hash is correct and the module source is trusted."
        }
    }
       
    if (-not $Destination) { 
        $ModulePaths = $Env:PSModulePath -split ';'
        if ($Global) {
            $ExpectedSystemModulePath = Join-Path -Path $PSHome -ChildPath Modules
            $Destination = $ModulePaths | Where-Object { $_ -eq $ExpectedSystemModulePath}
        } else {
            $ExpectedUserModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
            $Destination = $ModulePaths | Where-Object { $_ -eq $ExpectedUserModulePath}
        }
        if (-not $Destination) {
            $Destination = $ModulePaths | Select-Object -Index 0
        }
    }

    InstallModuleFromLocalFolder -SourceFolderPath:$TempModuleFolderPath -ModuleName:$ModuleName -Destination $Destination -DoNotImport:$DoNotImport -Startup:$Startup -Force:$Force 
}

<#
.Synopsis
    Installs a module.
.Description 
    Supports installing modules for the current user or all users (if elevated)
.Parameter Module
    Name of the module to install.
.Parameter ModuleUrl
    URL to the module to install; Can be direct link to PSM1 file or ZIP file. Can be a shortened link.
.Parameter ModulePath
    Local path to the module to install.
.Parameter Type
    When ModuleUrl or ModulePath specified, allows specifying type of the package. Can be ZIP or PSM1.
.Parameter Destination
    When specified the module will be installed below this path.
.Parameter ModuleHash
    When ModuleHash is specified the chosen module will only be installed if its contents match the provided hash.
.Parameter ModuleName
    When ModuleUrl or ModulePath specified, allows specifying the name of the module.
.Parameter Global
    If set, attempts to install the module to the all users location in Windows\System32...    
.Parmeter DoNotImport
    Indicates that command should not import module after installation
.Parmeter Startup
    Adds installed module to the profile.ps1
.Parmeter DirectoryUrl
    URL to central directory. By default it uses the value in the $PsGetDirectoryUrl global variable
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
    # Install-Module -ModuleUrl https://github.com/psget/psget/raw/master/TestModules/HelloWorld.zip

    Description
    -----------
    Downloads HelloWorld module (module can have more than one file) and installs it

#>
}

function Get-ModuleIdentityFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Path,

        [string]
        $ModuleName = '*'
    )

    $Includes = "$ModuleName.psd1","$ModuleName.psm1","$ModuleName.dll"

    # Sort by folder length ensures that we use one from root folder(Issue #12)
    $DirectoryNameLengthProperty = @{
        E = { $_.DirectoryName.Length }
    }

    # sort by Includes to give PSD1 preference over PSM1, etc
    $IncludesPreferenceProperty = @{
        E = {
            for ($Index = 0; $Index -lt $Includes.Length; $Index++) {
                if ($_.Name -like $Includes[$Index]) { break }
            }
            $Index
        }
    }

    Get-ChildItem -Path $Path -Include $Includes -Recurse |
        Where-Object { -not $_.PSIsContainer } |
        Sort-Object -Property $DirectoryNameLengthProperty, $IncludesPreferenceProperty | 
        Select-Object -ExpandProperty FullName -First 1

}

function Get-PsGetModuleInfo {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]
        [String]$ModuleName,
        [String]$DirectoryUrl = $global:PsGetDirectoryUrl
    )

    begin {
        Write-Verbose "Downloading modules repository from $DirectoryUrl"
        $client = (new-object Net.WebClient)
        $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        $repoXml = [xml]$client.DownloadString($DirectoryUrl)

        $nss = @{ a = "http://www.w3.org/2005/Atom";
                  pg = "urn:psget:v1.0" }
    
        $feed = $repoXml.feed
        $title = $feed.title.innertext
        Write-Verbose "Processing $title feed..."
    }
    
    process {
        # Very naive, ignoring namespases and so on.
        $feed.entry |
            Where-Object { $_.id -like $ModuleName } |
            ForEach-Object {
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
                } |
                    Add-Member -MemberType AliasProperty -Name ModuleName -Value Title -PassThru |
                    Add-Member -MemberType AliasProperty -Name ModuleUrl -Value DownloadUrl -PassThru
            }
    }
<#
.Synopsis
    Retrieve information about module from central directory
.Description 
    Command will query central directory to get information about module specified.
.Parameter ModuleName
    Name of module to look for in directory. Supports wildcards.
.Parameter DirectoryUrl
    URL to central directory. By default it uses the value in the $PsGetDirectoryUrl global variable
.Link
    http://psget.net
.Example
    Get-PsGetModuleInfo PoshCo*

    Description
    -----------
    Retrieves information about all registerd modules that starts with PoshCo.

#>
}

function CheckIfNeedInstallAndImportIfNot {
    param (
        $ModuleName,
        $Force,
        $DoNotImport,
        [string]
        $ModuleHash
    )

    if ($Force) {
        # if forced we always install the module again
        return $true
    }

    $InstalledModule = Get-Module -Name $ModuleName -ListAvailable

    if (-not $InstalledModule) {
        # if the module is not installed, we install the module
        return $true
    }

    if ($ModuleHash) {
        $InstalledModuleHash = Get-PsGetModuleHash -Path $InstalledModule.ModuleBase
        Write-Verbose "Hash of module in '$($InstalledModule.ModuleBase)' is: $InstalledModuleHash"
        if ($ModuleHash -ne $InstalledModuleHash) {
            # if the hash doesn't match, we install the module
            return $true
        }
    }

    if ($DoNotImport -eq $false){
        Import-Module -Name $ModuleName -Global
    }

    Write-Verbose "$ModuleName already installed. Use -Force if you need reinstall"
    return $false
}

function UnzipModule($inp, $dest){

    $inp = Resolve-Path $inp
    
    if ($inp.Extension -ne ".zip"){
        $PSGET_ZIPFolderPath = [IO.Path]::ChangeExtension($inp, ".zip")            
        Rename-Item $inp $PSGET_ZIPFolderPath -Force    
        $inp = $PSGET_ZIPFolderPath;
    }

    Write-Verbose "Unzip $inp to $dest"
    # From http://serverfault.com/questions/18872/how-to-zip-unzip-files-in-powershell/201604#201604
    $shellApp = New-Object -Com Shell.Application        
    $PSGET_ZIPFile = $shellApp.namespace([String]$inp)         

    $ContentTypesXmlPath = Join-Path -Path $PSGET_ZIPFile.Self.Path -ChildPath '[Content_Types].xml'
    if ($PSGET_ZIPFile.items() | Where-Object { $_.Path -eq $ContentTypesXmlPath }) {
        Write-Verbose 'Zip file appears to be created by System.IO.Packaging (eg Nuget)'
    }

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
    $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
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
    $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
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
        $BestCandidateModule = Get-ModuleIdentityFile -Path $TempModuleFolderPath
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
    [Parameter(Mandatory=$true)]
    [String]$Destination,    
    [Switch]$DoNotImport = $false,
    [Switch]$Startup = $false,
    [Switch]$Force = $false
)    
    $IsDestinationInPSModulePath = $Env:PSModulePath -split ';' -contains $Destination
    if (-not $IsDestinationInPSModulePath) {
        Write-Warning 'Module install destination is not included in the PSModulePath environment variable'
    }

    # Make a folder for the module
    $ModuleFolderPath = ([System.IO.Path]::Combine($Destination, $ModuleName))
    
    if ((Test-Path $ModuleFolderPath) -eq $false) {
        New-Item $ModuleFolderPath -ItemType Directory -ErrorAction Continue -ErrorVariable FailMkDir | Out-Null
        ## Handle the error if they asked for -Global and don't have permissions
        if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
            throw "You do not have permission to install a module to '$Destination'. You may need to be elevated."
        }        
        Write-Verbose "Create module folder at $ModuleFolderPath"
    }
    
    # Empty existing module folder before copying new files
    Get-ChildItem -Path $ModuleFolderPath -Force | Remove-Item -Force -Recurse -ErrorAction Stop

    # Copy module files to destination folder
    Get-ChildItem $SourceFolderPath | Copy-Item -Destination $ModuleFolderPath -Force -Recurse
    
    # Try to run Install.ps1 if any
    $Install = ($ModuleFolderPath + "\Install.ps1")
    if (Test-Path $Install){
        # TODO consider rechecking hash before running install.ps1
        Write-Verbose "Install.ps1 file found in module. Let's execute it."
        & $Install
    }
    
    ## Check if something was installed
    if ($IsDestinationInPSModulePath) {
        if (-not(Get-Module $ModuleName -ListAvailable)){
            throw "For some unexpected reasons module was not installed."
        }
    } else {
        if (-not (Test-Path -Path $ModuleFolderPath\* -Include *.psd1,*.psm1,*.dll)) {
            throw "For some unexpected reasons module was not installed."
        }
    }
    Write-Host "Module $ModuleName was successfully installed." -Foreground Green
    
    if ($DoNotImport -eq $false){
        # TODO consider rechecking hash before calling Import-Module
        $IdentityExtension = [System.IO.Path]::GetExtension((Get-ModuleIdentityFile -Path $ModuleFolderPath -ModuleName $ModuleName))
        if ($IdentityExtension -eq '.dll') {
            Write-Warning 'Module is installed but cannot be automatically imported because it is a binary module'
        } else {
            Import-Module -Name $ModuleFolderPath -Global
        }
    }
    
    if ($IsDestinationInPSModulePath -and $Startup) {
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
            $Signature = Get-AuthenticodeSignature -FilePath $AllProfile
            if ($Signature.Status -eq 'Valid') {
                Write-Error "PsGet cannot modify code-signed profile '$AllProfile'."
            } else {
                Write-Verbose "Add Import-Module $ModuleName command to the profile"
                "`nImport-Module $ModuleName" | Add-Content $AllProfile
            }
        }
    }
}

function Get-FileHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]
        $Path
    )

    begin {
        $Algorithm = New-Object -TypeName System.Security.Cryptography.SHA256Managed
    }

    process {
        if (-not (Test-Path -Path $Path -PathType Leaf)) {
            Write-Error "Cannot find file: $Path"
            return
        }
        $Stream = [System.IO.File]::OpenRead($Path)
        try {
            $HashBytes = $Algorithm.ComputeHash($Stream)
            [BitConverter]::ToString($HashBytes) -replace '-',''
        } finally {
            $Stream.Close()
        }
    }
}

function Get-FolderHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "Cannot find folder: $Path"
    }

    $Path = $Path + '\' -replace '\\\\$','\\'
    $PathPattern = '^' + [Regex]::Escape($Path)

    $ChildHashes = Get-ChildItem -Path $Path -Recurse -Force |
        Where-Object { -not $_.PSIsContainer } |
        ForEach-Object {
            New-Object -TypeName PSObject -Property @{
                RelativePath = $_.FullName -replace $PathPattern, ''
                Hash = Get-FileHash -Path $_.FullName
            }
        }

    $Text = @($ChildHashes |
        Sort-Object -Property RelativePath |
        ForEach-Object {
            '{0} {1}' -f $_.Hash, $_.RelativePath
        }) -join "`r`n"

    Write-Debug "TEXT>$Text<TEXT"

    $Algorithm = New-Object -TypeName System.Security.Cryptography.SHA256Managed
    $HashBytes = $Algorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    [BitConverter]::ToString($HashBytes) -replace '-',''
}

function Get-PsGetModuleHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [Alias('ModuleBase')]
        [string]
        $Path
    )

    Get-FolderHash -Path $Path
}

# Back Up TabExpansion if needed
# Idea is stolen from posh-git + ps-get
$teBackup = 'PsGet_DefaultTabExpansion'
if((Test-Path Function:\TabExpansion) -and !(Test-Path Function:\$teBackup)) {
    Rename-Item Function:\TabExpansion $teBackup
}

# Revert old tabexpnasion when module is unloaded
# this does not cover all paths, but most of them
# Idea is stolen from PowerTab
$Module = $MyInvocation.MyCommand.ScriptBlock.Module 
$Module.OnRemove = {
    Write-Verbose "Revert tab expansion back"
    Remove-Item Function:\TabExpansion
    if (Test-Path Function:\$teBackup)
    {
        Rename-Item Function:\$teBackup Function:\TabExpansion
    }
}

# Set up new tab expansion
Function global:TabExpansion {
    param($line, $lastWord)
            
    if ($line -eq "Install-Module $lastword" -or $line -eq "inmo $lastword" -or $line -eq "ismo $lastword")
    {
        Get-PsGetModuleInfo "$lastword*" | % { $_.Id } | sort -Unique
    }    
    elseif ( Test-Path Function:\$teBackup )
    {
        & $teBackup $line $lastWord
    }       
}

if (-not (Get-Variable -Name PsGetDirectoryUrl -Scope Global -ErrorAction SilentlyContinue)) {
    $global:PsGetDirectoryUrl = 'https://github.com/psget/psget/raw/master/Directory.xml'
}

Set-Alias inmo Install-Module
Set-Alias ismo Install-Module
Export-ModuleMember Install-Module
Export-ModuleMember Get-PsGetModuleInfo
Export-ModuleMember Get-PsGetModuleHash
Export-ModuleMember -Alias inmo
Export-ModuleMember -Alias ismo
