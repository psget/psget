function Install-PsGet(){
	$UserModulePath = $Env:PSModulePath -split ";" | Select -Index 0	
	new-item ($UserModulePath + "\PsGet\") -ItemType Directory -Force | out-null
	(new-object System.Net.WebClient).DownloadFile("https://github.com/chaliy/psget/raw/master/PsGet/PsGet.psm1", $UserModulePath + "\PsGet\PsGet.psm1")
	import-module PsGet
}

Install-PsGet