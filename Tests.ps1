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