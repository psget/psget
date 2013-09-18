<#

.SYNOPSIS
    PowerShell module installation stuff.
    URL: https://github.com/psget/psget
    Based on http://poshcode.org/1875 Install-Module by Joel Bennett 

#>
#requires -Version 2.0
$PSGET_ZIP = "ZIP"
$PSGET_PSM1 = "PSM1"
$PSGET_PSD1 = "PSD1"

$global:UserModuleBasePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "WindowsPowerShell\Modules"
$global:CommonGlobalModuleBasePath = Join-Path -Path $env:CommonProgramFiles -ChildPath "Modules"

function Install-Module {

[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0, ParameterSetName="CentralDirectory")]    
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
    [ValidateSet('ZIP', 'PSM1', 'PSD1')] # $PSGET_ZIP, $PSGET_PSM1 or $PSGET_PSD1
    [String]$Type,

    [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$true, ParameterSetName='NuGet')]
    [ValidatePattern('^\w+([_.-]\w+)*$')] # regex from NuGet.PackageIdValidator._idRegex
    [ValidateLength(1,100)] # maximum length from NuGet.PackageIdValidator.MaxPackageIdLength
    [String]$NuGetPackageId,

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='NuGet')]
    [String]$PackageVersion,

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='NuGet')]
    [String]$NugetSource = "https://nuget.org/api/v2/",

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='NuGet')]
    [switch]$PreRelease,

    [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName='NuGet')]
    [string]$PreReleaseTag,

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [String]$Destination = $global:PsGetDestinationModulePath,

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [String]$ModuleHash,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [String]$InstallWithModuleName,

    [Switch]$Global = $false,
    [Switch]$DoNotImport = $false,
    [Switch]$Startup = $false,
    [Switch]$AddToProfile = $false,
    [Switch]$Force = $false,
    [Switch]$Update = $false,
    [Switch]$PersistEnvironment = $false,
    [String]$DirectoryUrl = $global:PsGetDirectoryUrl
    
)

begin {

    if($PSVersionTable.PSVersion.Major -lt 2) {
        Write-Error "PsGet requires PowerShell 2.0 or better; you have version $($Host.Version)"
        return
    }

    if ($Force){
        Write-Verbose "Force parameter is considered obsolete. Please use Update instead"
        $Update = $true
    }


    if ($Startup){
        Write-Verbose "Startup parameter is considered obsolete. Please use AddToProfile instead"
        $AddToProfile = $true
    }    



}

process {
        
    #If global is chosen, then the Machine environment variable PSModulePath will be modified
    if($Global) {
        $moduleEnvironmentVariableScope = "Machine"
    } else {
        $moduleEnvironmentVariableScope = "User"
    }

    #If no destination provided, default to CommonFiles\Modules location or User's modules directory
    if (-not $Destination) { 
        $Destination = $global:UserModuleBasePath
        if ($Global) {
            $Destination = $global:CommonGlobalModuleBasePath
            
        }
        #Because we are using the default location, always ensure it is persisted
        $PersistEnvironment = $true
    } 

    #If the destination is not set by now, go ahead and throw
    if(-not $Destination) {
        throw "The destination path was not added to the PSModulePath environment variable, ensure you have the rights to modify environment variables"
    }

    $Destination = Canonicolize-Path $Destination

    switch($PSCmdlet.ParameterSetName) {
        CentralDirectory {            
            if (!$InstallWithModuleName) {
                $InstallWithModuleName = $Module
            }
            if (-not (CheckIfNeedInstallAndImportIfNot -ModuleName:$InstallWithModuleName -Update:$Update -DoNotImport:$DoNotImport -ModuleHash:$ModuleHash -Destination:$Destination)){
                return;
            }
            
            Write-Verbose "Module $Module will be installed from central repository"		                                
            $moduleData = Get-PsGetModuleInfo $Module -DirectoryUrl:$DirectoryUrl | select -First 1             
            if (!$moduleData){
                throw "Module $Module was not found in central repository"
            }
            
            $Type = $moduleData.Type        
            $ModuleName = $moduleData.Id
            $Verb = $moduleData.Verb
            
            $downloadResult = DumbDownloadModuleFromWeb -DownloadURL:$moduleData.DownloadUrl -ModuleName:$moduleData.Id -Type:$Type -Verb:$Verb
                                        
            $TempModuleFolderPath = $downloadResult.ModuleFolderPath
            break
        }
        Web {			
            Write-Verbose "Module will be installed from $ModuleUrl"
            
            $result = DownloadModuleFromWeb -DownloadURL:$ModuleUrl -ModuleName:$ModuleName -Type:$Type -Verb:GET
                                    
            $Type = $result.Type
            $ModuleName = $result.ModuleName
            $TempModuleFolderPath = $result.ModuleFolderPath
                        
            if ($Type -eq ""){
                throw "Cannot guess module type. Try specifying Type argument. Applicable values are '{0}' or '{1}' " -f $PSGET_ZIP, $PSGET_PSM1
            }    
                            
            if ($ModuleName -eq ""){
                throw "Cannot guess module name. Try specifying ModuleName argument"
            }
            
            if (!$InstallWithModuleName) {
                $InstallWithModuleName = $ModuleName
            }
            if (-not (CheckIfNeedInstallAndImportIfNot -ModuleName:$InstallWithModuleName -Update:$Update -DoNotImport:$DoNotImport `
                        -ModuleHash:$ModuleHash -Destination:$Destination)){
                return;
            }
        }
        Local {
            Write-Verbose "Module will be installed local path"
            $CandidateFileDir = $CandidateFilePath = Resolve-Path $ModulePath
			
			#if the CandidateFilePath is as file and not a directory, then we want to extract the directory
			if([IO.File]::Exists($CandidateFilePath) -and -not [IO.Directory]::Exists($CandidateFilePath)) {
				$CandidateFileDir = [IO.Path]::GetDirectoryName($CandidateFilePath)
			} 
			
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
                Copy-Item $CandidateFileDir $TempModuleFolderPath -Force -Recurse
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
                throw "Cannot guess module type. Try specifying Type argument. Applicable values are '{0}', '{1}' or '{2}' " -f $PSGET_ZIP, $PSGET_PSM1, $PSGET_PSD1
            }

            if (!$InstallWithModuleName) {
                $InstallWithModuleName = $ModuleName
            }
            if (-not (CheckIfNeedInstallAndImportIfNot -ModuleName:$InstallWithModuleName -Update:$Update -DoNotImport:$DoNotImport -ModuleHash:$ModuleHash -Destination:$Destination)){
                return;
            }

        }
        NuGet {
            if (!$InstallWithModuleName) {
                $InstallWithModuleName = $NuGetPackageId
            }
            if (-not (CheckIfNeedInstallAndImportIfNot -ModuleName:$InstallWithModuleName -Update:$Update -DoNotImport:$DoNotImport -ModuleHash:$ModuleHash -Destination:$Destination)){
                return;
            }
            
            try
            {
                $DownloadResult = DownloadNugetPackage -NuGetPackageId $NuGetPackageId -PackageVersion $PackageVersion -Source $NugetSource -PreRelease $PreRelease.IsPresent -PreReleaseTag $PreReleaseTag
                $ModuleName = $DownloadResult.ModuleName
                $TempModuleFolderPath = $DownloadResult.ModuleFolderPath
            }
            catch
            {
                Write-Error $_.Exception.Message
                return
            }
        }
        default {
            throw "Unknown ParameterSetName '$($PSCmdlet.ParameterSetName)'"
        }
    }

    ## Normalize child directory    
    if (-not (Test-Path -Path $TempModuleFolderPath\* -Include "$ModuleName.psd1","$ModuleName.psm1")) {
        $ModulePath = Get-ModuleIdentityFile -Path $TempModuleFolderPath -ModuleName $ModuleName
        $TempModuleFolderPath = [System.IO.Path]::GetDirectoryName($ModulePath)
        Write-Verbose "Normalized module path to: $TempModuleFolderPath"
    }


    #Ensure that the hash of the module matches the specified hash
    if ($ModuleHash) {
        $TempModuleHash = Get-PsGetModuleHash -Path $TempModuleFolderPath
        Write-Verbose "Hash of module in '$TempModuleFolderPath' is: $TempModuleHash"
        if ($ModuleHash -ne $TempModuleHash) {
            throw "Module contents do not match specified module hash. Ensure the expected hash is correct and the module source is trusted."
        }

        $DestinationModulePath = Join-Path -path $Destination -ChildPath $ModuleName
        #If the module destination already exists, and the destination hash is different from the sepecified hash, set the update flag to true
        if(Test-Path $DestinationModulePath ) {
            $DestinationModuleHash = Get-PsGetModuleHash -Path $DestinationModulePath
            if($DestinationModuleHash -ne $ModuleHash ) {
                $Update = $true
            }
        }
    }
    
    if ($InstallWithModuleName -ne $ModuleName) {
        $ModuleIdentityFile = Get-ModuleIdentityFile -Path $TempModuleFolderPath -ModuleName $ModuleName

        $NewModuleIdentityFileName = $InstallWithModuleName + (Get-ChildItem $ModuleIdentityFile).Extension

        Rename-Item -Path $ModuleIdentityFile -NewName $NewModuleIdentityFileName
        $ModuleName = $InstallWithModuleName
    }
    
    #Add the Destination path to the User or Machine environment    
    AddPathToPSModulePath -Scope $moduleEnvironmentVariableScope -PathToAdd $Destination -PersistEnvironment:$PersistEnvironment
    
    InstallModuleFromLocalFolder -SourceFolderPath:$TempModuleFolderPath -ModuleName:$ModuleName -Destination $Destination -DoNotImport:$DoNotImport -AddToProfile:$AddToProfile -Update:$Update 
}

<#
.SYNOPSIS
    Installs PowerShell modules from a variety of sources including: Nuget, PsGet module directory, local directory, zipped folder and web URL
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
    If set, attempts to install the module to the all users location in C:\Program Files\Common Files\Modules...
    Note, if the -Destination directory is specified, then -Global will not have any effect
.Parameter DoNotImport
    Indicates that command should not import module after installation
.Parameter AddToProfile
    Adds installed module to the profile.ps1
.Parameter Update
    Forces module to be updated
.Parameter DirectoryUrl
    URL to central directory. By default it uses the value in the $PsGetDirectoryUrl global variable
.Parameter NuGetPackageId
    NuGet package name containing the module to install
.Parameter PackageVersion
    Allows a specific version of the specified NuGet package to used, if not specified then the latest stable version will be used
.Parameter NugetSource
    URL to the NuGet feed containing the package
.Parameter PreRelease
    If PackageVersion is not specified, then this switch allows the latest prerelease package to be used
.Parameter PreReleaseTag
    If PackageVersion is not specified, then this parameter allows the latest version of a particular prerelease tag to be used
.Parameter PersistEnvironment
    If this switch is specified, the installation destination path will be added to either the User's PSModulePath environment variable or Machine's PSModulePath environment variable (if -Global specified)

.Link
    http://psget.net       
    
    
.Example
    # Install-Module PsConfig -DoNotImport

    Description
    -----------
    Installs the module witout importing it to the current session
    
.Example
    # Install-Module PoshHg -AddToProfile

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

.Example
    # Install-Module -NugetPackageId SomePackage

    Description
    -----------
    Downloads the latest stable version of the 'SomePackage' module from the NuGet Gallery

.Example
    # Install-Module -NugetPackageId SomePackage -PackageVersion 1.0.2-beta

    Description
    -----------
    Downloads the specified version of the 'SomePackage' module from the NuGet Gallery

.Example
    # Install-Module -NugetPackageId SomePackage -PreRelease

    Description
    -----------
    Downloads the latest pre-release version of the 'SomePackage' module from the NuGet Gallery

.Example
    # Install-Module -NugetPackageId SomePackage -PreReleaseTag beta -NugetSource http://myget.org/F/myfeed

    Description
    -----------
    Downloads the latest 'beta' pre-release version of the 'SomePackage' module from a custom NuGet feed
#>
}

function Update-Module {
[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0, ParameterSetName="Repo")]    
    [String]$Module,
    [Parameter(ParameterSetName="All")]
    [Switch]$All,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [String]$Destination = $global:PsGetDestinationModulePath,

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [String]$ModuleHash,

    [Switch]$Global = $false,
    [Switch]$DoNotImport = $false,
    [Switch]$AddToProfile = $false,
    [String]$DirectoryUrl = $global:PsGetDirectoryUrl
)
    if ($PSCmdlet.ParameterSetName -eq 'All') {
        Install-Module -Module PSGet -Force -DoNotImport

        Get-PsGetModuleInfo '*' |
        Where-Object {
            if ($PSItem.Id -ne 'PSGet') {
                Get-Module -Name:($PSItem.ModuleName) -ListAvailable 
            }
        } | Install-Module -Update            

        Import-Module -Name PSGet -Force

    } else {
        Install-Module -Module:$Module -Destination:$Destination -ModuleHash:$ModuleHash -Global:$Global -DoNotImport:$DoNotImport -AddToProfile:$AddToProfile -DirectoryUrl:$DirectoryUrl -Update
    }
<#
.Synopsis
    Updates a module.
.Description 
    Supports updating modules for the current user or all users (if elevated)
.Parameter Module
    Name of the module to update.
.Parameter Destination
    When specified the module will be updated below this path.
.Parameter ModuleHash
    When ModuleHash is specified the chosen module will only be installed if its contents match the provided hash.
.Parameter Global
    If set, attempts to install the module to the all users location in Windows\System32...
.Parameter DoNotImport
    Indicates that command should not import module after installation
.Parameter AddToProfile
    Adds installed module to the profile.ps1
.Parameter Update
    Forces module to be updated
.Parameter DirectoryUrl
    URL to central directory. By default it uses the value in the $PsGetDirectoryUrl global variable
.Link
    http://psget.net
.Link
    Install-Module
    
    
.Example
    # Update-Module PsUrl

    Description
    -----------
    Updates the module    
#>
}

function DownloadNuGetPackage {
    param (
        $NuGetPackageId,
        $PackageVersion,
        $Source,
        $PreRelease,
        $PreReleaseTag
    )

    $WebClient = New-Object -TypeName System.Net.WebClient
    $WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

    if (-not $Source.EndsWith("/"))
    {
        $Source += "/"
    }

    Write-Verbose "Querying '$Source' repository for package with Id '$NuGetPackageId'"
    $Url = "{1}Packages()?`$filter=tolower(Id)+eq+'{0}'&`$orderby=Id" -f $NuGetPackageId.ToLower(), $Source
    Write-Debug "NuGet query url: $Url"

    try
    {
        $XmlDoc = [xml]$WebClient.DownloadString($Url)
    }
    catch
    {
        throw "Unable to download from NuGet feed: $($_.Exception.InnerException.Message)"
    }

    if ($PackageVersion) {
        #  version regexs can be found in the NuGet.SemanticVersion class
        $Entry = $XmlDoc.feed.entry |
            Where-Object { $_.properties.Version -eq $PackageVersion } |
            Select-Object -First 1
    } else {
        
        $Entry = FindLatestNugetPackageFromFeed $XmlDoc.feed.entry $NuGetPackageId $PreRelease $PreReleaseTag
    }

    if ($Entry) {
        $PackageVersion = $Entry.properties.Version
        Write-Verbose "Found NuGet package version '$PackageVersion'"
    } else {
        throw ("Cannot find NuGet package '$NuGetPackageId $PackageVersion' [PreRelease='{0}', PreReleaseTag='{1}']" -f $PreRelease, $PreReleaseTag)
    }

    $DownloadUrl = $Entry.content.src
    Write-Verbose "Downloading NuGet package from '$DownloadUrl'"
    $DownloadResult = DownloadModuleFromWeb -DownloadURL $DownloadUrl -ModuleName $NugetPackageId
    return $DownloadResult
}

function Get-ModuleIdentityFileName {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $ModuleName
    )

    # list of extensions from the documentation for the RootModule parameter of the New-ModuleManifest cmdlet
    'psd1','psm1','ps1','dll','cdxml','xaml' |
        ForEach-Object {
            '{0}.{1}' -f $ModuleName, $_
        }
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

    $Includes = Get-ModuleIdentityFileName -ModuleName $ModuleName

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
        $client = (new-object Net.WebClient)
        $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

        $PsGetDataPath = Join-Path -Path $Env:APPDATA -ChildPath psget
        $DirectoryCachePath = Join-Path -Path $PsGetDataPath -ChildPath directorycache.clixml
        $DirectoryCache = @()
        $CacheEntry = $null
        if (Test-Path -Path $DirectoryCachePath) {
            $DirectoryCache = Import-Clixml -Path $DirectoryCachePath
            $CacheEntry = $DirectoryCache | Where-Object { $_.Url -eq $DirectoryUrl } | Select-Object -First 1
        }
        if (-not $CacheEntry) {
            $CacheEntry = @{
                Url = $DirectoryUrl
                File = '{0}.xml' -f [Guid]::NewGuid().Tostring()
                ETag = $null
            }
            $DirectoryCache += @($CacheEntry)
        }        
        $CacheEntryFilePath = Join-Path -Path $PsGetDataPath -ChildPath $CacheEntry.File
        if ($CacheEntry -and $CacheEntry.ETag -and (Test-Path -Path $CacheEntryFilePath)) {
            if ((Get-Item -Path $CacheEntryFilePath).LastWriteTime.AddDays(1) -gt (Get-Date)) {
                # use cached directory if it is less than 24 hours old
                $client.Headers.Add('If-None-Match', $CacheEntry.ETag)
            }
        }

        try {
            Write-Verbose "Downloading modules repository from $DirectoryUrl"
            $repoRaw = $client.DownloadString($DirectoryUrl)            
            $StatusCode = 200
        } catch [System.Net.WebException] {            
            $Response = $_.Exception.Response
            if ($Response) { $StatusCode = [int]$Response.StatusCode }
        }

        if ($StatusCode -eq 200) {
            $repoXml = [xml]$repoRaw

            $CacheEntry.ETag = $client.ResponseHeaders['ETag']
            if (-not (Test-Path -Path $PsGetDataPath)) {
                New-Item -Path $PsGetDataPath -ItemType Container | Out-Null
            }
            $repoXml.Save($CacheEntryFilePath)
            Export-Clixml -InputObject $DirectoryCache -Path $DirectoryCachePath
        } elseif (Test-Path -Path $CacheEntryFilePath) {
            if ($StatusCode -ne 304) {
                Write-Warning "Could not retrieve modules repository from '$DirectoryUrl'. Status code: $StatusCode"
            }
            Write-Verbose "Using cached copy of modules repository"
            $repoXml = [xml](Get-Content -Path $CacheEntryFilePath)
        } else {
            throw "Could not retrieve modules repository from '$DirectoryUrl'. Status code: $StatusCode"
        }

        $nss = @{ a = "http://www.w3.org/2005/Atom";
                  pg = "urn:psget:v1.0" }
    
        $feed = $repoXml.feed
        $title = $feed.title.innertext
        Write-Verbose "Processing $title feed..."
    }
    
    process {
        # Very naive, ignoring namespaces and so on.
        $feed.entry |
            Where-Object { $_.id -like $ModuleName } |
            ForEach-Object {
                $Type = ""
                switch -regex ($_.content.type) {
                    "application/zip" { $Type = $PSGET_ZIP  }
                    default { $Type = $PSGET_PSM1  }
                }

                $Verb = if ($_.properties.Verb -imatch 'POST') { "POST" }
                    else { "GET" }
        
                New-Object PSObject -Property @{
                    Title = $_.title.innertext
                    Description = $_.summary.'#text'
                    Updated = [DateTime]$_.updated
                    Author= $_.author.name
                    Id = $_.id
                    Type = $Type
                    DownloadUrl = $_.content.src
                    Verb = $Verb 
                    #This was changed from using the  $_.properties.ProjectUrl because the value for ModuleUrl needs to be the full path to the module file
                    #This change was required to get the tests to pass
                    ModuleUrl = $_.content.src                
                } |   
                     Add-Member -MemberType AliasProperty -Name ModuleName -Value Title -PassThru |
                    Select-Object Title, ModuleName, Id, Description, Updated, Type, Verb, ModuleUrl,DownloadUrl

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

function ImportModuleGlobal {
    param (
        $Name,
        $ModuleBase,
        [switch]$Force
    )

    Import-Module -Name $ModuleBase -Global -Force:$Force

    $IdentityExtension = [System.IO.Path]::GetExtension((Get-ModuleIdentityFile -Path $ModuleBase -ModuleName $Name))
    if ($IdentityExtension -eq '.dll') {
        # import module twice for binary modules to workaround PowerShell bug:
        # https://connect.microsoft.com/PowerShell/feedback/details/733869/import-module-global-does-not-work-for-a-binary-module
        Import-Module -Name $ModuleBase -Global -Force:$Force
    }
}

function CheckIfNeedInstallAndImportIfNot {
    param (
        $ModuleName,
        [Switch]$Update,
        $DoNotImport,
        [String]$ModuleHash,
        [String]$Destination
    )

    if ($Update) {
        # if update we always install the module again
        return $true
    }

    $InstalledModule = Get-Module -Name $ModuleName -ListAvailable 
    
    #If a destination path is provided, the module is only considered installed if it is installed in that path
    if($Destination) {
        $InstalledModule = $installedModule | Where {
            (Canonicolize-Path $_.ModuleBase) -like (Canonicolize-Path $Destination)
        } | Select-Object -First 1
        Write-Verbose "Expecting the module '$ModuleName' to be installed in '$Destination'"
    } else {

        #It is possible that a module could be installed in more than one location
        #In that case, let's just warn, and take the first one
        if($InstalledModule -and $InstalledModule.Count -gt 1) {
            $FirstInstalledModule = $InstalledModule | Select-Object -First 1

            Write-Warning @"
    The module '$ModuleName' was installed at more than one location.  Installed paths:
        $($InstalledModule.ModuleBase | fl | out-string)

    Using the first path found: ($($FirstInstalledModule.ModuleBase))

"@
            $InstalledModule = $FirstInstalledModule
        }
    }

    if (-not $InstalledModule -and $Destination) {
        # if the module is not installed in the PSModulePath, check the Destination
        $CandidateModulePath = Join-Path -Path $Destination -ChildPath $ModuleName
        $Includes = Get-ModuleIdentityFileName -ModuleName $ModuleName
        if (Test-Path -Path $CandidateModulePath\* -Include $Includes -PathType Leaf) {
            $InstalledModule = @{ ModuleBase = $CandidateModulePath }
        }
    }

    if (-not $InstalledModule) {
        # if the module is not installed, we install the module
        return $true
    }

    Write-Verbose "**Hash $ModuleHash"

    if ($ModuleHash -ne "") {
        $InstalledModuleHash = Get-PsGetModuleHash -Path $InstalledModule.ModuleBase
        Write-Verbose "Hash of module in '$($InstalledModule.ModuleBase)' is: $InstalledModuleHash"
        if ($ModuleHash -ne $InstalledModuleHash) {
            # if the hash doesn't match, we install the module
            return $true
        }
    }

    if ($DoNotImport -eq $false){
        ImportModuleGlobal -Name $ModuleName -ModuleBase $InstalledModule.ModuleBase -Force:$Update
    }

    Write-Verbose "$ModuleName already installed. Use -Update if you need update"
    return $false
}

function UnzipModule($inp, $dest){

    $inp = (Resolve-Path $inp).ProviderPath
    
    $PSGET_ZIPFolderPath = [IO.Path]::ChangeExtension($inp, ".zip")  
 
    if(-not (Test-Path $PSGET_ZIPFolderPath)) {
        Rename-Item -Path $inp -NewName $PSGET_ZIPFolderPath -Force 
    }
      
    $inp = $PSGET_ZIPFolderPath;

    Write-Verbose "Unzip $inp to $dest"
    # From http://serverfault.com/questions/18872/how-to-zip-unzip-files-in-powershell/201604#201604
    $shellApp = New-Object -Com Shell.Application        
    $PSGET_ZIPFile = $shellApp.namespace([String]$inp)         

    $ContentTypesXmlPath = Join-Path -Path $PSGET_ZIPFile.Self.Path -ChildPath '[Content_Types].xml'
    if ($PSGET_ZIPFile.items() | Where-Object { $_.Path -eq $ContentTypesXmlPath }) {
        Write-Verbose 'Zip file appears to be created by System.IO.Packaging (eg NuGet)'
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
	if ($fileName -like "*.psd1"){
        return $PSGET_PSD1
    }    
    return $PSGET_PSM1
}

function DumbDownloadModuleFromWeb($DownloadURL, $ModuleName, $Type, $Verb) {
        
    #Create folder to download module content into	
    $TempModuleFolderPath = join-path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + "\$ModuleName")
    New-Item $TempModuleFolderPath -ItemType Directory | Out-Null

    Write-Verbose "Dowloading module from $DownloadURL"

    # Client to download module stuff
    $client = (new-object Net.WebClient)
    $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $DownloadFilePath = [System.IO.Path]::GetTempFileName()
    if ($Verb -eq 'POST') {
        $client.Headers['Content-type'] = 'application/x-www-form-urlencoded'
        [IO.File]::WriteAllBytes($DownloadFilePath, $client.UploadData($DownloadURL, ''))
    }
    else {
        $client.DownloadFile($DownloadURL, $DownloadFilePath)
    }
    
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
    [String]$Type,
    [String]$Verb
)    
    function TryGuessFileName($client, $downloadUrl){    
        ## Try get module name from content disposition header (e.g. attachment; filename="Pscx-2.0.0.1.zip" )
        $contentDisposition = $client.ResponseHeaders["Content-Disposition"]
        Write-Debug "TryGuessFileName: Content-Disposition = '$contentDisposition'"
        $nameMatch = [regex]::match($contentDisposition, "filename=""(?'name'[^/]+\.(psm1|zip))""")
        if ($nameMatch.Groups["name"].Success) {
            return $nameMatch.Groups["name"].Value
        }

        ## try content disposition header without surrounding quotes (eg attachment; filename=pscx.zip)
        if ($contentDisposition -match '\bfilename=(?<name>[^/]+\.(?:psm1|zip))') {
            return $Matches.name
        }
                
        ## Na¿ve try to guess name from URL
        $nameMatch = [regex]::match($downloadUrl, "/(?'name'[^/]+\.(psm1|zip))[\#\?]*")
        if ($nameMatch.Groups["name"].Success) {
            return $nameMatch.Groups["name"].Value
        }
    }        
    
    function TryGuessType($client, $fileName, $DownloadedFile){
        $contentType = $client.ResponseHeaders["Content-Type"]
        if ($contentType -eq "application/zip"){
            return $PSGET_ZIP
        }

        ## check downloaded file for the PKZip header
        if ((Get-Item -Path $DownloadedFile).Length -gt 4) {
            $KnownPKZipHeader = 0x50, 0x4b, 0x03, 0x04
            $FileHeader = Get-Content -Path $DownloadedFile -Encoding Byte -TotalCount 4
            if ([System.BitConverter]::ToString($KnownPKZipHeader) -eq [System.BitConverter]::ToString($FileHeader)) {
                return $PSGET_ZIP
            }
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
    if ($Verb -eq 'POST') {
        $client.Headers['Content-type'] = 'application/x-www-form-urlencoded'
        [IO.File]::WriteAllBytes($DownloadFilePath, $client.UploadData($DownloadURL, ''))
    }
    else {
        $client.DownloadFile($DownloadURL, $DownloadFilePath)
    }    
    
    $CandidateFileName = TryGuessFileName $client $downloadUrl
    Write-Debug "DownloadModuleFromWeb: CandidateFileName = '$CandidateFileName'"
    
    if ($Type -eq ""){
        $Type = TryGuessType $client $CandidateFileName -DownloadedFile $DownloadFilePath
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
    Write-Debug "DownloadModuleFromWeb: ModuleName = '$ModuleName'"
        
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
    [Switch]$AddToProfile = $false,
    [Switch]$Update = $false
)    
    # TODO Handle situation when $_ is null (e.g. $Env:PSModulePath = ";Aaa;")
    $IsDestinationInPSModulePath = ($Env:PSModulePath -split ";" | foreach { Canonicolize-Path $_ })   -contains (Canonicolize-Path $Destination)
    if (-not $IsDestinationInPSModulePath) {
        Write-Warning "Module install destination `"$Destination`" is not included in the PSModulePath environment variable."
    }

    #Handle the edge case where there exists a file in the destination with the same name
    # TODO Use PS utils to check and delete folder
    if([io.file]::Exists($Destination)) {
        del $Destination -force
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
    if ($Update) {
        Write-Host "Module $ModuleName was successfully updated." -Foreground Green
    } else {
        Write-Host "Module $ModuleName was successfully installed." -Foreground Green
    }
    
    if ($DoNotImport -eq $false){
        # TODO consider rechecking hash before calling Import-Module
        ImportModuleGlobal -Name $ModuleName -ModuleBase $ModuleFolderPath -Force:$Update
    }
    
    if ($IsDestinationInPSModulePath -and $AddToProfile) {
        # WARNING $Profile is empty on Win2008R2 under Administrator
        $AllProfile = $PROFILE
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

function FindLatestNugetPackageFromFeed {
    param
    (
        $feed,
        $packageId,
        $preRelease,
        $preReleaseTag
    )

    # From NuGet.SemanticVersion - https://github.com/Haacked/NuGet/blob/master/src/Core/SemanticVersion.cs
    $semVerRegex = "^(?<Version>\d+(\s*\.\s*\d+){0,3})(?<Release>-[a-z][0-9a-z-]*)?$"
    $semVerStrictRegex = "^(?<Version>\d+(\.\d+){2})(?<Release>-[a-z][0-9a-z-]*)?$"

    # find only stable versions
    $stableRegex = "^(\d+(\s*\.\s*\d+){0,3})?$"
    # find stable and prerelease versions
    $preReleaseRegex = "^(\d+(\s*\.\s*\d+){0,3})(-[a-z][0-9a-z-]*)?$"
    # find only a specific prerelease versions
    $specificPreReleaseRegex = "^(\d+(\s*\.\s*\d+){{0,3}}-{0}[0-9a-z-]*)?$" -f $preReleaseTag

    # Set the required search expression   
    $searchRegex = $stableRegex
    if ($preRelease) { $searchRegex = $preReleaseRegex }
    if ($preReleaseTag) { $searchRegex = $specificPreReleaseRegex }

    $packages = $feed | Where-Object { 
    
        ($_.properties.Version) -match $searchRegex
    }

    return ($packages | Select -Last 1)

}

function AddPathToPSModulePath {
    param(
	[System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User,
	[Parameter(Mandatory=$true)]
	[string]$PathToAdd,
    [switch]$PersistEnvironment)

    $ExistingPathValue = "" + [Environment]::GetEnvironmentVariable("PSModulePath", $Scope)
    $PathToAdd = Canonicolize-Path $PathToAdd	

    if (!($ExistingPathValue.Contains($PathToAdd))){
        
        if (!($ExistingPathValue -eq "")){
            $NewPathValue = "$ExistingPathValue;$PathToAdd"    
        } else {
            $NewPathValue = "$PathToAdd"
        }

        if($PersistEnvironment) {
            #Set the new value
            [Environment]::SetEnvironmentVariable("PSModulePath",$NewPathValue, $Scope)
        }
        
        ReImportPSModulePathToSession
        
        Write-Host """$PathToAdd"" is added to the PSModulePath environment variable"        
    } else {
        Write-Verbose """$PathToAdd"" is already exists in PSModulePath environment variable"
    }
<#
.SYNOPSIS
    Adds value to a "Path" type of environment variable (PATH or PSModulePath).  Path type of variables munge the User and Machine values into the value for the current session.
.PARAMETER Scope
    The System.EnvironmentVariableTarget of what type of environment variable to modify ("Machine","User" or "Session")
.PARAMETER PathToAdd
    The actual path to add to the environment variable
.PARAMETER PersistEnvironment
    If specified, will permanently store the variable in registry
.EXAMPLE
    AddPathToPSModulePath -Scope "Machine" -PathToAdd "$env:CommonProgramFiles\Modules"

    Description
    -----------
    This command add the path "$env:CommonProgramFiles\Modules" to the Machine PSModulePath environment variable
#>

}

function ReImportPSModulePathToSession {
    
    $NewSessionValue = ([Environment]::GetEnvironmentVariable("PSModulePath", "User") + ";" +  [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")).Trim(';') 
    
    #Set the value in the current process
    [Environment]::SetEnvironmentVariable("PSModulePath", $NewSessionValue, "Process")
    Set-Content env:\PSModulePath $NewSessionValue
}


function Canonicolize-Path {
    param(
    [Parameter(Mandatory=$true)]
    [string]$Path)
    
    return [IO.Path]::GetFullPath(($path.Trim() + '\'))
<#
.SYNOPSIS
    A simple routine to standardize path formats.  
    A trailing slash is always added because that tends to be safer (i.e. c:\foo\\bar and c:\foo\bar are valid and equivalent, but c:\foobar is not valid or equivalent)

.EXAMPLE

    PS> Canonicolize-Path "C:\\Temp\\\foo"

    C:\Temp\foo\

#>
}

# Back Up TabExpansion if needed
# Idea is stolen from posh-git + ps-get
$teBackup = 'PsGet_DefaultTabExpansion'
if((Test-Path Function:\TabExpansion -ErrorAction SilentlyContinue) -and !(Test-Path Function:\$teBackup -ErrorAction SilentlyContinue)) {
    Rename-Item Function:\TabExpansion $teBackup -ErrorAction SilentlyContinue
}

# Revert old tabexpnasion when module is unloaded
# this does not cover all paths, but most of them
# Idea is stolen from PowerTab
$Module = $MyInvocation.MyCommand.ScriptBlock.Module 
$Module.OnRemove = {
    Write-Verbose "Revert tab expansion back"
    Remove-Item Function:\TabExpansion -ErrorAction SilentlyContinue
    if (Test-Path Function:\$teBackup)
    {
        Rename-Item Function:\$teBackup Function:\TabExpansion
    }
}

# Set up new tab expansion
Function global:TabExpansion {
    param($line, $lastWord)
            
    if ($line -eq "Install-Module $lastword" -or $line -eq "inmo $lastword" -or $line -eq "ismo $lastword" -or $line -eq "upmo $lastword" -or $line -eq "Update-Module $lastword")
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


Set-Alias inmo Install-Module #Obsolete
Set-Alias ismo Install-Module
Set-Alias upmo Update-Module

Export-ModuleMember Install-Module
Export-ModuleMember Update-Module
Export-ModuleMember Get-PsGetModuleInfo
Export-ModuleMember Get-PsGetModuleHash
Export-ModuleMember -Alias inmo
Export-ModuleMember -Alias ismo
Export-ModuleMember -Alias upmo
