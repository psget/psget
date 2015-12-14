
param (
  $url = "https://github.com/psget/psget/raw/master/PsGet/PsGet.psm1"
)

function Find-Proxy() {
    if ((Test-Path Env:HTTP_PROXY) -Or (Test-Path Env:HTTPS_PROXY)) {
        return $true
    }
    Else {
        return $false
    }
}

function Get-Proxy() {
    if (Test-Path Env:HTTP_PROXY) {
        return $Env:HTTP_PROXY
    }
    ElseIf (Test-Path Env:HTTPS_PROXY) {
        return $Env:HTTPS_PROXY
    }
}

function Get-File {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Url,

        [Parameter(Mandatory=$true)]
        [String] $SaveToLocation
    )
    $command = (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)
    if($command -ne $null) {
        if (Find-Proxy) {
            $proxy = Get-Proxy
            Write-Host "Proxy detected"
            Write-Host "Using proxy address $proxy"
            Invoke-WebRequest -Uri $Url -OutFile $SaveToLocation -Proxy $proxy
        }
        else {
            Invoke-WebRequest -Uri $Url -OutFile $SaveToLocation
        }
    }
    else {
        $client = (New-Object Net.WebClient)
        $client.UseDefaultCredentials = $true
        if (Find-Proxy) {
            $proxy = Get-Proxy
            Write-Host "Proxy detected"
            Write-Host "Using proxy address $proxy"
            $webproxy = new-object System.Net.WebProxy
            $webproxy.Address = $proxy
            $client.proxy = $webproxy
        }
        $client.DownloadFile($Url, $SaveToLocation)
    }
}

function Install-PsGet {
  
    param (
      [string]
      # URL to the respository to download PSGet from
      $url
    )
  
    $ModulePaths = @($env:PSModulePath -split ';')
    # $PsGetDestinationModulePath is mostly needed for testing purposes,
    if ((Test-Path -Path Variable:PsGetDestinationModulePath) -and $PsGetDestinationModulePath) {
        $Destination = $PsGetDestinationModulePath
        if ($ModulePaths -notcontains $Destination) {
            Write-Warning 'PsGet install destination is not included in the PSModulePath environment variable'
        }
    }
    else {
        $ExpectedUserModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
        $Destination = $ModulePaths | Where-Object { $_ -eq $ExpectedUserModulePath }
        if (-not $Destination) {
            $Destination = $ModulePaths | Select-Object -Index 0
        }
    }
    New-Item -Path ($Destination + "\PsGet\") -ItemType Directory -Force | Out-Null
    Write-Host ('Downloading PsGet from {0}' -f $url)
    Get-File -Url $url -SaveToLocation "$Destination\PsGet\PsGet.psm1"

    $executionPolicy = (Get-ExecutionPolicy)
    $executionRestricted = ($executionPolicy -eq "Restricted")
    if ($executionRestricted) {
        Write-Warning @"
Your execution policy is $executionPolicy, this means you will not be able import or use any scripts including modules.
To fix this change your execution policy to something like RemoteSigned.

        PS> Set-ExecutionPolicy RemoteSigned

For more information execute:

        PS> Get-Help about_execution_policies

"@
    }

    if (!$executionRestricted) {
        # ensure PsGet is imported from the location it was just installed to
        Import-Module -Name $Destination\PsGet
    }
    Write-Host "PsGet is installed and ready to use" -Foreground Green
    Write-Host @"
USAGE:
    PS> import-module PsGet
    PS> install-module PsUrl

For more details:
    get-help install-module
Or visit http://psget.net
"@
}

Install-PsGet -Url $url
