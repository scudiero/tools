#!/bin/bash
#===================================================================================================
version=1.0.28 # -- dscudiero -- Fri 05/25/2018 @  8:52:43.36
#===================================================================================================
TrapSigs 'on'
myIncludes="RunSql"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"; originalArgStr="${originalArgStr#$myName }"
scriptDescription="Bring a tools script on-line"

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
GetDefaultsData $myName

[[ $(Contains "$administrators" "$userName") != true ]] && Terminate "You do not have sufficient permissions to run this scrip"

if [[ -n $originalArgStr ]]; then
	for script in $originalArgStr; do
		[[ -f "$TOOLSPATH/bin/${script%.*}.offline" ]] && { rm -f "$TOOLSPATH/bin/${script%.*}.offline"; Msg "^$script is now on-line"; }
	done
fi

Goodbye
#===================================================================================================
## Check-in log
#===================================================================================================
## Thu May  5 09:21:05 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:53 CDT 2016 - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 07.39.17 - (1.0.13)    - dscudiero - Add RunSql to the include list
## 10-03-2017 @ 16.14.01 - (1.0.23)    - dscudiero - Refactored to allow for report of all online scripts
## 02-02-2018 @ 10.46.41 - 1.0.24 - dscudiero - D
## 03-22-2018 @ 14:07:12 - 1.0.26 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 05-25-2018 @ 09:14:19 - 1.0.28 - dscudiero - Re-factor to use .offline files
## 06-05-2018 @ 15:14:41 - 1.0.28 - dscudiero - Cosmetic/minor change/Sync
## 06-05-2018 @ 15:21:23 - 1.0.28 - dscudiero - Cosmetic/minor change/Sync
