param([switch]$EnableExit)
<#
.SYNOPSIS
This script is just the bootstrapper for running the pester tests.  It takes care of ensuring that the Pester module is installed.
.PARAMETER EnableExit
This switch is just passed to the Invoke-Pester command.  It is required to get exit codes back to batch scripts.
#>
$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)


#region Install and Import Pester module
Remove-Module PsGet -Force -ErrorAction SilentlyContinue
import-module -name ($here + "\PsGet\PsGet.psm1") -force 

try {
    Remove-Module Pester -Force -ErrorAction SilentlyContinue
    Import-Module Pester  -ErrorAction stop
} catch {
    Write-Warning "Unable to import module 'Pester' required for testing, attempting to install Pester via PsGet module ... "
    Install-Module pester  -ErrorAction stop -persist -global
}
#endregion

Invoke-Pester -relative_path $here -EnableExit:$EnableExit

