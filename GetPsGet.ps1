function Install-PsGet {
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
    Write-Host 'Downloading PsGet from https://github.com/psget/psget/raw/master/PsGet/PsGet.psm1'
    $client = (New-Object Net.WebClient)
    $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $client.DownloadFile("https://github.com/psget/psget/raw/master/PsGet/PsGet.psm1", $Destination + "\PsGet\PsGet.psm1")

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

Install-PsGet