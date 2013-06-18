$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
#. "$here\$sut"


#region Install and Import Pester module
Remove-Module PsGet -Force -ErrorAction SilentlyContinue
import-module -name ($here + "\PsGet\PsGet.psm1") -force 

try {
    Remove-Module Pester -Force -ErrorAction SilentlyContinue
    Import-Module Pester  -ErrorAction stop
} catch {
    Write-Warning "Unable to import module 'Pester' required for testing, attempting to install Pester via PsGet module ... "
    Install-Module pester  -ErrorAction stop
}
#endregion


Invoke-Pester -relative_path $here

