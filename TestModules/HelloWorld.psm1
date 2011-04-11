##
##    PowerShell module to output hello worlds!
##

#requires -Version 2.0
function Write-HelloWorld {	
	Write-Host "Hello world!" -Foreground Green
<#
.Synopsis
    Outputs Hello World!
	
.Example
    Write-HelloWorld    

#>
}

Export-ModuleMember Write-HelloWorld