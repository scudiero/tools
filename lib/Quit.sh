## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.6" # -- dscudiero -- Fri 01/26/2018 @  8:30:21.71
#===================================================================================================
# Quick quit
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Quit {
	exitCode=$1
	Goodbye 'quickQuit'
} #Quit
function quit { Quit $* ; }
function QUIT { trap - ERR EXIT; set +xveE; rm -rf $tmpRoot/* > /dev/null 2>&1; exit; }

export -f Quit
export -f quit
export -f QUIT

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:14 CST 2017 - dscudiero - General syncing of dev to prod
## 01-26-2018 @ 08.33.24 - 2.0.6 - dscudiero - Only clean up directories and files under tmpRoot
