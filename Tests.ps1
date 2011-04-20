$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
import-module -name ($here + "\PsGet\PsGet.psm1")
$UserModulePath = $Env:PSModulePath -split ";" | Select -Index 0

function Assert-ModuleInstalled ($Module) {
    if ((Test-Path $UserModulePath/$Module/$Module.psm1) -eq $false){
		throw "Module $Module was not installed"
	}	
}
function Drop-Module ($Module) {
    if ((Test-Path $UserModulePath/$Module/)){	
		Remove-Item $UserModulePath/$Module/ -Force -Recurse
	}
}

write-host Should support something simple
install-module https://github.com/chaliy/psget/raw/master/TestModules/HelloWorld.psm1 -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support urls that command cannot guess module name
install-module http://bit.ly/ggXoOR -ModuleName "HelloWorld"  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support zipped modules
install-module https://github.com/chaliy/psget/raw/master/TestModules/HelloWorld.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support zipped in child folder modules
install-module https://github.com/chaliy/psget/raw/master/TestModules/HelloWorldInChildFolder.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support local PSM1 modules
install-module $here\TestModules\HelloWorld.psm1  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support local zipped modules
install-module $here\TestModules\HelloWorld.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should support local zipped in child folder modules
install-module $here\TestModules\HelloWorldInChildFolder.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"


write-host Should support modules with install.ps1
install-module $here\TestModules\HelloWorldWithInstall.zip  -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should not install module twice
install-module $here\TestModules\HelloWorld.psm1 -Verbose
install-module $here\TestModules\HelloWorld.psm1 -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should not install module twice when ModuleName specified
install-module $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose
install-module $here\TestModules\HelloWorld.psm1 -ModuleName HelloWorld -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"

write-host Should install module twice when Force specified
install-module $here\TestModules\HelloWorld.psm1 -Verbose
install-module $here\TestModules\HelloWorld.psm1 -Force -Verbose
assert-moduleinstalled "HelloWorld"
drop-module "HelloWorld"