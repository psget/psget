PsGet Utils
=============

Set of commands ( right now only one :) ) to install modules from local file or from the web.


Example
=======

For example PsUrl module is located at https://github.com/chaliy/psurl/raw/master/PsUrl.psm1 , to install it just execute

    install-module https://github.com/chaliy/psurl/raw/master/PsUrl.psm1

Installation
============

While this tool streamlines installation of the modules, it should be installed manually for now.

1. Copy PsGet.psm1 to your modules folder (e.g. $Env:PsGet\PsGet\ )
2. Execute Import-Module PsGet (or add this command to your profile)
3. Enjoy!

Roadmap
=======

Roadmap is not sorted in any order. This is just list what is think sould be done.

1. Support for other then PSM1 types of modules
2. Support for modules with more then one file (ZIP or NuGet packages)
3. Support for registry of modules. So for example install-module PsUrl will succesfully resolve url and install right module
4. Support for NuGet repositories
5. Self installation script

Credits
=======

Module based on http://poshcode.org/1875 Install-Module by Joel Bennett  