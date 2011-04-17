PsGet Utils
=============

Set of commands ( right now only one :) ) to install modules from local file or from the web.

Features
========

1. Install modules from web or local file
2. Install modules to user profile or for all users ( elevated access required )
3. Install multifile modules from ZIP
4. Import module after install
5. Alter you profle to load module every time that PowerShell starts
6. Execute Install.ps1 if found in module folder

Examples
========

For example `PsUrl` module is located at https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1 , to install it just execute

    install-module https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1
    
Another example is zipped modules. Zipped `posh-git` module is located at https://github.com/dahlbyk/posh-git/zipball/master , to install it just execute

    install-module https://github.com/dahlbyk/posh-git/zipball/master
    
Also this command will execute Install.ps1 that is install scrtipt for `posh-git`.

Sometimes PsGet cannot guess module name. In this case you can specify it manually.

    install-module http://bit.ly/ggXoOR -ModuleName "HelloWorld"

And of course it supports local files. Both ZIP and PSM1
    
    install-module \TestModules\HelloWorld.zip

    install-module \TestModules\HelloWorld.psm1
    
Command also can import installed module

    install-module https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1 -Import
    
Or even make given module to start with your profile

    install-module https://github.com/chaliy/psurl/raw/master/PsUrl/PsUrl.psm1 -Startup

Installation
============

While this tool streamlines installation of the modules, it should be installed manually for now.

1. Copy `PsGet.psm1` to your modules folder (e.g. `$Env:PsGet\PsGet\` )
2. Execute `Import-Module PsGet` (or add this command to your profile)
3. Enjoy!

Experimental Installation
=========================

    (new-object System.Net.WebClient).DownloadString("https://github.com/chaliy/psget/raw/master/GetPsGet.ps1") | invoke-expression
    
FAQ
===

Q: Error "File xxx cannot be loaded because the execution of scripts is disabled on this system. Please see "get-help about_signing" for more details."
A: By default, PowerShell restricts execution of all scripts. This is all about security. To "fix" this run PowerShell as Administrator and call 
    
    Set-ExecutionPolicy RemoteSigned
    
For mode details run get-help about_signing or git-help [about_Execution_Policies](visit http://msdn.microsoft.com/en-us/library/dd347641.aspx).

Roadmap
=======

Roadmap is not sorted in any order. This is just list what is think should be done.

1. Support for other than PSM1 types of modules
2. Support for modules with more than one file with NuGet packages
3. Support for registry of modules. So for example install-module PsUrl will successfully resolve URL and install right module
4. Support for NuGet repositories
5. Support for versions of the modules

Credits
=======

Module based on http://poshcode.org/1875 Install-Module by Joel Bennett  