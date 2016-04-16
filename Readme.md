PsGet Utils
=============

Set of commands to install PowerShell modules from central directory, local files, or the web.

Installation
============

In your prompt execute:

	(new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | iex

And if you get something like this:

	Downloading PsGet from https://github.com/psget/psget/raw/master/PsGet/PsGet.psm1
	PsGet is installed and ready to use

You are done. The PowerShell script downloads `GetPsGet.ps1` and sends it to `Invoke-Expression` to install the PsGet Module.

Alternatively, you can install manually

1. Copy `PsGet.psm1` to your modules folder (e.g. `$Env:PsGet\PsGet\` )
2. Execute `Import-Module PsGet` (or add this command to your profile)
3. Enjoy!

Features
========

1. Install modules from central directory, local files, or the web
2. Install modules to user profile or for all users (elevated access required)
3. Install multifile modules from ZIP
4. Import module after install
5. Alter your profile to load a given module PowerShell starts up
6. Execute Install.ps1
7. Tab completion for modules, ismo Ps<Tab>

Examples
========
To install something from central directory just type:

    install-module PsUrl
    
This command queries central directory to find required information about the PsUrl module and install it if found.

As another example on [how to install the `PsUrl` module](https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1), use

    install-module -ModuleUrl https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1
    
With zipped modules like `posh-git`, you can install [zip package](https://github.com/dahlbyk/posh-git/zipball/master) via

    install-module -ModuleUrl https://github.com/dahlbyk/posh-git/zipball/master
    
This command executes `Install.ps1` which installs script for `posh-git`. (`posh-git` is in the directory, so `install-module posh-git` is enough.)

And of course, it supports local files, both ZIP and PSM1:

    install-module -ModulePath \TestModules\HelloWorld.zip
    install-module -ModulePath \TestModules\HelloWorld.psm1
    
You can also have a given module start with your profile:

    install-module PsUrl -Startup   

NuGet can even install the modules:

    install-module -nugetpackageid SomePowerShellModuleOnNuget
    install-module -nugetpackageid SomePrivatePowerShellModule -nugetsource http://mynugetserver/nuget/feed/

If you need update module, execute `Update-Module` which downloads the latest version and replace local one

    update-module PsUrl

FAQ
===

Q: Error `File [x] cannot be loaded because the execution of scripts is disabled on this system. Please see "get-help about_signing" for more details.`
A: By default, PowerShell restricts execution of all scripts which is all about security. As a "fix", please run PowerShell as Administrator and call 
    
    Set-ExecutionPolicy RemoteSigned
    
For mode details, run `get-help` [about_Execution_Policies](http://msdn.microsoft.com/en-us/library/dd347641.aspx).

Q: How to add my module to the directory?
A: Review a [small section](https://github.com/psget/psget/wiki/How-to-add-your-module-to-the-directory) of the [wiki](https://github.com/psget/psget/wiki)


Roadmap
=======

The roadmap is not sorted in any order; it is simply a list for what should be done.

1. Support for beyond just PSM1 types of modules
2. Support for modules with more than one file with NuGet packages
3. Support for versions of the modules
4. Git/Hg/Svn sources git

Resources
=========

1. [Blog about PsGet](http://blog.chaliy.name/tagged/psget)
2. [PowerShell wrapper for NuGet](http://code.andrewnurse.net/psget) — also has name PsGet and now [on GitHub](https://github.com/anurse/PS-Get).
3. [Instruction how to pack PowerShell module to NuGet package](http://haacked.com/archive/2011/04/19/writing-a-nuget-package-that-adds-a-command-to-the.aspx)

Contributing
============

If you are interested in contributing to PsGet, please read this [page](https://github.com/psget/psget/wiki/How-can-I-contribute-to-PsGet) from [wiki](https://github.com/psget/psget/wiki)

Credits
=======

Module based on [Install-Module by Joel Bennett](http://poshcode.org/1875)

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/psget/psget/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
