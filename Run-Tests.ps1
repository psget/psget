param([switch]$EnableExit)
<#
.SYNOPSIS
This script is just the bootstrapper for running the pester tests.  It takes care of ensuring that the Pester module is installed.
.PARAMETER EnableExit
This switch is just passed to the Invoke-Pester command.  It is required to get exit codes back to batch scripts.
#>
$here = (Split-Path -parent $MyInvocation.MyCommand.Definition)


#region Install and Import Pester module
Import-Module ($here + "\PsGet\PsGet.psm1") -Force 

try {
    Import-Module Pester -Force
} catch {
    Write-Warning "Unable to import module 'Pester' required for testing, attempting to install Pester via PsGet module ... "
    Install-Module pester
}
#endregion

Invoke-Pester -relative_path $here -EnableExit:$EnableExit
