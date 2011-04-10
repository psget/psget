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