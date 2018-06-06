#!/bin/bash
#===================================================================================================
version=1.0.42 # -- dscudiero -- Fri 05/25/2018 @  9:11:21.20
#===================================================================================================
TrapSigs 'on'
myIncludes="SetFileExpansion"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Take a tools script off-line or display the current scripts off-line"

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
[[ $(Contains "$administrators" "$userName") != true ]] && Terminate "You do not have sufficient permissions to run this scrip"

GetDefaultsData $myName

if [[ -n $originalArgStr ]]; then
	for script in $originalArgStr; do
		echo touch "$TOOLSPATH/bin/${script%.*}.offline"
		touch "$TOOLSPATH/bin/${script%.*}.offline"
		Msg "^$script is now offline"
	done
else
	Msg "Current offline scripts:"
	SetFileExpansion 'on'
	for file in $(ls $TOOLSPATH/bin/*.offline 2> /dev/null); do
		file="${file%.*}"
		Msg "^${file##*/}"
	done
	SetFileExpansion
	Msg
fi

Goodbye
#===================================================================================================
## Check-in log
#===================================================================================================
## Mon Apr 11 08:42:19 CDT 2016 - dscudiero - output all offline scripts if nothing passed in
## Thu May  5 09:20:53 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:44 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Jul 27 12:41:23 CDT 2016 - dscudiero - Fix problem where it was picking up N/A scripts
## 10-03-2017 @ 16.13.44 - (1.0.17)    - dscudiero - Refactored to allow report on all offline scripts
## 02-02-2018 @ 10.46.37 - 1.0.18 - dscudiero - Add userid check
## 03-22-2018 @ 14:07:07 - 1.0.20 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 05-25-2018 @ 09:13:53 - 1.0.42 - dscudiero - Re-factor to use .offline files
## 06-05-2018 @ 15:14:19 - 1.0.42 - dscudiero - Cosmetic/minor change/Sync
## 06-06-2018 @ 07:34:50 - 1.0.42 - dscudiero - Turn file expansion on if no args past
## 06-06-2018 @ 07:39:12 - 1.0.42 - dscudiero - Cosmetic/minor change/Sync
