function Install-PsGet(){
    $UserModulePath = $Env:PSModulePath -split ";" | Select -Index 0
    new-item ($UserModulePath + "\PsGet\") -ItemType Directory -Force | out-null
    Write-Host Downloading PsGet from https://github.com/chaliy/psget/raw/master/PsGet/PsGet.psm1
    (new-object Net.WebClient).DownloadFile("https://github.com/chaliy/psget/raw/master/PsGet/PsGet.psm1", $UserModulePath + "\PsGet\PsGet.psm1")    
    import-module PsGet    
    Write-Host "PsGet is installed and ready to use" -Foreground Green
    Write-Host "USAGE:"
    Write-Host "    import-module PsGet"
    Write-Host "    install-module PsUrl"
    Write-Host ""
    Write-Host "For more details:"
    Write-Host "    get-help install-module" 
    Write-Host "Or visit http://psget.net" 
}

Install-PsGet