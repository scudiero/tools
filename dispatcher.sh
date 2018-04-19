#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="1.5.5" # -- dscudiero -- Thu 04/19/2018 @  7:11:28.06
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

myName='dispatcher'
me='dscudiero'
function fastDump { 
	[[ $(/usr/bin/logname 2>&1) != $me || $DEBUG != true ]] && return 0
	local token ans; for token in $*; do 
		[[ $token == -p ]] && { echo -e "\n*** Paused, press enter to continue ***"; read ans; [[ -n $ans ]] && exit; } || \
		echo -e "\t$token = >${!token}<"; 
	done
}
[[ $(/usr/bin/logname 2>&1) == $me && $DEBUG == true ]] && echo -e "\n*** In $myName ($version)\n\t\$* = >$*<"

## Parse through arguments looking for keywords
	useLocal=false
	useDev=false
	pauseAtExit=false
	viaCron=false
	for token in $*; do
		if [[ ${token:0:2} == '--' ]]; then
			token="${token:2}" ; token=${token,,[a-z]}
			[[ $token == 'viacron' ]] && { viaCron=true; shift || true; }
			[[ $token == 'uselocal' ]] && { useLocal=true; shift || true; }
			[[ $token == 'usedev' ]] && { useDev=true; shift || true; }
			[[ $token == 'pauseatexit' || $token == 'pauseonexit' ]] && { export PAUSEATEXIT=true; shift || true; }
		fi
	done
	fastDump viacron useLocal useDev PAUSEATEXIT

## Make sure we have a TOOLSPATH and it is valid
	[[ -z $TOOLSPATH ]] && echo -e "\n*Error* -- dispatcher: Global variable 'TOOLSPATH' is not set, cannot continue\n" && exit -1
	[[ ! -d $TOOLSPATH ]] && echo -e "\n*Error* -- dispatcher: Global variable 'TOOLSPATH' is set but is not a directory, cannot continue\n" && exit -1
	[[ ! -r $TOOLSPATH/bootData ]] && echo -e "\n*Error* -- dispatcher: Global variable 'TOOLSPATH' is set but you cannot access the boot record, cannot continue\n" && exit -1

## Load boot data
	source "$TOOLSPATH/bootData"
	[[ -r "$HOME/tools/bootData" ]] && source "$HOME/tools/bootData"

## Set global variables
	export TOOLSWAREHOUSEDB="$warehouseDb"
	export TOOLSLIBPATH="$TOOLSPATH/lib"
	export TOOLSSRCPATH="$TOOLSPATH/src"
	export SCRIPTINCLUDES

	[[ -n $TOOLSWAREHOUSEDBNAME ]] && warehouseDb="$TOOLSWAREHOUSEDBNAME"
	export TOOLSWAREHOUSEDBNAME="$warehouseDbName"

	[[ -n $TOOLSWAREHOUSEDBHOST ]] && warehouseDbHost="$TOOLSWAREHOUSEDBHOST"
	export TOOLSWAREHOUSEDBHOST="$warehouseDbHost"

	export TOOLSDEFAULTSPATH="$TOOLSPATH/shadows/toolsDefaults"

## Parse off the script to call name
	unset scriptArgs
	loadPgm="$(basename $0)"; 
	[[ $loadPgm == 'dispatcher.sh' ]] && { loadPgm="$1"; shift || true; }
	[[ $loadPgm == 'testsh' ]] && { scriptArgs=' --noLog --noLogInDb'; useLocal=true; }

## Find the loader based on passed arguments
	loaderDir="$TOOLSPATH"
	unset USEDEV USELOCAL
	if [[ $useLocal == true || $useDev == true ]]; then
		[[ $useLocal == true && $useDev == true ]] && unset useDev
		if [[ $useDev == true && -r "$TOOLSDEVPATH" ]]; then
			loaderDir="$TOOLSDEVPATH"
		elif [[ $useLocal == true && -r $HOME/tools/loader.sh  ]]; then
			loaderDir="$HOME/tools"
		fi
		[[ -d "$loaderDir/lib" ]] && export TOOLSLIBPATH="$loaderDir/lib:$TOOLSLIBPATH"
		[[ -d "$loaderDir/src" ]] && export TOOLSSRCPATH="$loaderDir/src:$TOOLSSRCPATH"
	fi
	export USEDEV=$useDev
	export USELOCAL=$useLocal
	export LOADER="$loaderDir/loader.sh"
	export VIACRON=$viaCron

## call script loader
	fastDump loaderDir USEDEV USELOCAL loadPgm
	if [[ $viaCron == true ]]; then
		source "$loaderDir/loader.sh" $loadPgm --batchMode $*
		return 0
	else
		[[ $(/usr/bin/logname 2>&1) == $me && $DEBUG == true ]] && echo -e "\n\tsource $loaderDir/loader.sh $loadPgm $scriptArgs $*"; fastDump -p;
		source "$loaderDir/loader.sh" $loadPgm $scriptArgs $*
	fi

exit

#===================================================================================================
## Check-in log
#===================================================================================================
## 06-02-2017 @ 14.53.07 - dscudiero - General syncing of dev to prod
## 06-02-2017 @ 15.03.26 - dscudiero - Move boot loader to here
## 06-02-2017 @ 15.05.38 - dscudiero - Add TOOLSWAREHOUSEDB
## 06-05-2017 @ 13.47.22 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 08.49.22 - dscudiero - If called from cron then source the loader, otherwise call the loader
## 06-08-2017 @ 09.06.36 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 09.07.38 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 10.03.49 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 10.51.25 - dscudiero - add debug statements
## 06-08-2017 @ 11.38.51 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 12.21.24 - dscudiero - add debug
## 06-12-2017 @ 07.26.00 - dscudiero - Make sure we have TOOLSPATH set
## 06-12-2017 @ 11.01.10 - dscudiero - add debug
## 06-12-2017 @ 11.08.50 - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.09.48 - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.18.41 - dscudiero - export the value of toolspath
## 06-12-2017 @ 11.24.02 - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.24.54 - dscudiero - remove debug statements
## 06-14-2017 @ 07.49.36 - dscudiero - Add debug messages
## 06-14-2017 @ 08.08.05 - dscudiero - Remove debug statements
## 06-26-2017 @ 07.50.30 - dscudiero - Add warhousedbHost, renamed warehousedb to warehousedbname
## 06-26-2017 @ 10.19.37 - dscudiero - set TOOLSWAREHOUSEDB
## 09-07-2017 @ 07.15.08 - dscudiero - add debug statement
## 09-07-2017 @ 08.11.55 - dscudiero - Add debug for me
## 09-07-2017 @ 08.52.42 - dscudiero - add setting of SCRIPTINCLUDES
## 09-08-2017 @ 16.28.53 - dscudiero - Check for the --useLocal directive as the first token before using local loader
## 09-28-2017 @ 09.02.58 - dscudiero - Add setting of TOOLSDEFAULTSPATH
## 10-16-2017 @ 13.56.18 - dscudiero - Comment out loader log statements
## 04-18-2018 @ 09:34:07 - 1.5.3 - dscudiero - Refactored to add useDev
## 04-18-2018 @ 13:41:25 - 1.5.4 - dscudiero - Add debug statements
## 04-19-2018 @ 07:12:56 - 1.5.5 - dscudiero - Re-factor how we detect viaCron
