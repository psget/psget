PsGet Utils
=============

Set of commands to install PowerShell modules from central directory, local file or from the web.

Features
========

1. Install modules from central directory
2. Install modules from web or local file
3. Install modules to user profile or for all users ( elevated access required )
4. Install multifile modules from ZIP
5. Import module after install
6. Alter you profle to load module every time that PowerShell starts
7. Execute Install.ps1 if found in module folder
31. Tab completion for modules, ismo Ps<Tab>

Examples
========
To install something from central directory just type:

    install-module PsUrl
    
This command will query central directory to find required information about PsUrl module and install it if found.

Another example is how to install `PsUrl` module located at https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1 , to install it just execute

    install-module -ModuleUrl https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1
    
or zipped modules like `posh-git`. Zip package is located at https://github.com/dahlbyk/posh-git/zipball/master , to install it just execute

    install-module -ModuleUrl https://github.com/dahlbyk/posh-git/zipball/master
    
Also this command will execute Install.ps1 that is install scrtipt for `posh-git`. (pls note `posh-git` is in the directory so `install-module posh-git` is enough).

And of course it supports local files. Both ZIP and PSM1
    
    install-module -ModulePath \TestModules\HelloWorld.zip

    install-module -ModulePath \TestModules\HelloWorld.psm1
    
Command also can make given module to start with your profile

    install-module PsUrl -Startup   

Modules can also be installed from NuGet:

    install-module -nugetpackageid SomePowerShellModuleOnNuget

	install-module -nugetpackageid SomePrivatePowerShellModule -nugetsource http://mynugetserver/nuget/feed/

If you need update module execute `Update-Module`, this will dowload last version and replace local one

    update-module PsUrl

Installation
============

In your prompt execute:

(new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | iex

You are done. This nice line of PowerShell script will dowload GetPsGet.ps1 and send it to Invoke-Expression to install PsGet Module.

Alternativelly you can do installation manually

1. Copy `PsGet.psm1` to your modules folder (e.g. `$Env:PsGet\PsGet\` )
2. Execute `Import-Module PsGet` (or add this command to your profile)
3. Enjoy!

FAQ
===

Q: Error "File xxx cannot be loaded because the execution of scripts is disabled on this system. Please see "get-help about_signing" for more details."
A: By default, PowerShell restricts execution of all scripts. This is all about security. To "fix" this run PowerShell as Administrator and call 
    
    Set-ExecutionPolicy RemoteSigned
    
For mode details run get-help about_signing or get-help [about_Execution_Policies](http://msdn.microsoft.com/en-us/library/dd347641.aspx).

Q: How to add my module to the directory?
A: Review small instruction on PsGet Wiki - How to add your module to the directory


Roadmap
=======

Roadmap is not sorted in any order. This is just list what is think should be done.

1. Support for other than PSM1 types of modules
2. Support for modules with more than one file with NuGet packages
3. Support for versions of the modules
4. Git/Hg/Svn sourcesgit

Resources
=========

1. Blog about PsGet - http://blog.chaliy.name/tagged/psget
2. PowerShell wrapper for NuGet http://code.andrewnurse.net/psget (yes also has name PsGet), now also [on GitHub](https://github.com/anurse/PS-Get).
3. Instruction how pack PowerShell module to NuGet package - http://haacked.com/archive/2011/04/19/writing-a-nuget-package-that-adds-a-command-to-the.aspx

Contributing
============

If you are interested in contributing to PsGet, please read the following page on the wiki:
https://github.com/psget/psget/wiki/How-can-I-contribute-to-PsGet

Credits
=======

Module based on http://poshcode.org/1875 Install-Module by Joel Bennett  

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/psget/psget/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
