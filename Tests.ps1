$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
import-module -name ($here + "\PsGet\PsGet.psm1") -force
$UserModulePath = $Env:PSModulePath -split ";" | Select -Index 0

function Assert-ModuleInstalled ($Module) {
    if ((Test-Path $UserModulePath/$Module/$Module.psm1) -eq $false){
		throw "Module $Module was not installed"
	}	
}
function Assert-Equals ($Actual, $Expected) {
    if ($Actual -ne $Expected){
		throw "Actual $Actual is not equal to expected $Expected"
	}	
}
function Assert-NotNull ($Actual) {
    if ($Actual -eq $null){
		throw "Actual is null"
	}	
}
function Drop-Module ($Module) {
    if ((Test-Path $UserModulePath/$Module/)){	
		Remove-Item $UserModulePath/$Module/ -Force -Recurse
	}
}

write-host Should support something simple
install-module -ModuleUrl https://github.com/chaliy/psget/raw/master/TestModules/HelloWorld.psm1 -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support urls that command cannot guess module name
install-module -ModuleUrl http://bit.ly/ggXoOR -ModuleName "HelloWorld"  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support zipped modules
install-module -ModuleUrl https://github.com/chaliy/psget/raw/master/TestModules/HelloWorld.zip  -Verbose
assert-moduleinstalled "HelloWorldZip"
drop-module "HelloWorldZip"

write-host Should support zipped in child folder modules
install-module -ModuleUrl https://github.com/chaliy/psget/raw/master/TestModules/HelloWorldInChildFolder.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support zipped with child modules
# The problem was with PSCX, they have many child modules
# And PsGet was loading one of child module instead.
# This test ensues that only main module is loaded
# Related to Issue #12
install-module -ModulePath $here\TestModules\HelloWorldFolderWithChildModules.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support local PSM1 modules
install-module -ModulePath $here\TestModules\HelloWorld.psm1  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support local zipped modules
install-module -ModulePath $here\TestModules\HelloWorld.zip  -Verbose
assert-moduleinstalled "HelloWorldZip"
drop-module "HelloWorldZip"

write-host Should support local zipped in child folder modules
install-module -ModulePath $here\TestModules\HelloWorldInChildFolder.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"


write-host Should support modules with install.ps1
install-module -ModulePath $here\TestModules\HelloWorldWithInstall.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should not install module twice
install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose
install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should not install module twice when ModuleName specified
install-module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose
install-module -ModulePath $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should install module twice when Force specified
install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Verbose
install-module -ModulePath $here\TestModules\HelloWorld.psm1 -Force -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should install module from repo
install-module HelloWorld -DirectoryURL "https://github.com/chaliy/psget/raw/master/TestModules/Directory.xml" -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should install zipped module from repo
install-module HelloWorldZip -DirectoryURL "https://github.com/chaliy/psget/raw/master/TestModules/Directory.xml" -Verbose
assert-moduleinstalled "HelloWorldZip"
drop-module "HelloWorldZip"

#write-host "Should crash if module was not found in repo"
#install-module Foo -DirectoryURL "https://github.com/chaliy/psget/raw/master/TestModules/Directory.xml" -Verbose

write-host "Should retrieve information about module by ID"
$retrieved = Get-PsGetModuleInfo HelloWorld -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose
Assert-NotNull $retrieved
Assert-Equals $retrieved.Id HelloWorld

write-host "Should retrieve information about module and wildcard"
$retrieved = Get-PsGetModuleInfo Hello* -DirectoryUrl:"file://$here\TestModules\Directory.xml" -Verbose
Assert-Equals $retrieved.Count 2

write-host Should support alternate install destination
install-module -ModuleUrl https://github.com/chaliy/psget/raw/master/TestModules/HelloWorld.psm1 -Destination $Env:TEMP\Modules -Verbose
if (-not (Test-Path -Path $Env:TEMP\Modules\HelloWorld\HelloWorld.psm1)) {
    throw "Module was not installed to alternate destination"
}
Remove-Item -Path $Env:TEMP\Modules -Recurse -Force

$DefaultUserPSModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
$DefaultSystemPSModulePath = Join-Path -Path $PSHOME -ChildPath Modules

$DefaultPSModulePath = $DefaultUserPSModulePath,$DefaultSystemPSModulePath -join ';'

$OriginalPSModulePath = $Env:PSModulePath
$OriginalDestinationModulePath = $PSGetDefaultDestinationModulePath
try {

    write-host Should install to user modules when PSModulePath has been prefixed
    $Env:PSModulePath = "$Env:ProgramFiles\TestPSModulePath;$DefaultPSModulePath"
    install-module -ModulePath $here\TestModules\HelloWorld.psm1  -Verbose
    if (-not (Test-Path -Path $DefaultUserPSModulePath\HelloWorld\HelloWorld.psm1)) {
        throw "Module was not installed to user module path"
    }
    Remove-Item -Path $DefaultUserPSModulePath\HelloWorld -Recurse -Force

} finally {
    # restore paths
    $Env:PSModulePath = $OriginalPSModulePath
    $PSGetDefaultDestinationModulePath = $OriginalDestinationModulePath
}

write-host Should hash module in a folder
$Hash = Get-PsGetModuleHash -Path $here\TestModules\HelloWorldFolder
Assert-Equals $Hash 563E329AFF0785E4A2C3039EF7F60F9E2FA68888CE12EE38C1406BDDC09A87E1

write-host Should install module matching the expected hash
Install-Module -ModulePath $here\TestModules\HelloWorldFolder\HelloWorld.psm1 -ModuleHash 563E329AFF0785E4A2C3039EF7F60F9E2FA68888CE12EE38C1406BDDC09A87E1 -Verbose
assert-moduleinstalled HelloWorld
drop-module HelloWorld

write-host Should not install a module with a conflicting hash
try {
    Install-Module -ModulePath $here\TestModules\HelloWorldFolder\HelloWorld.psm1 -ModuleHash AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA -Verbose
} catch { $_ }
if (Test-Path $UserModulePath/HelloWorld/HelloWorld.psm1) {
    throw "Module HelloWorld was installed but should not have been installed."
}
drop-module HelloWorld