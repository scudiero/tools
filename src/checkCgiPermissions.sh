#!/bin/bash
#==================================================================================================
version=2.2.27 # -- dscudiero -- 02/07/2017 @  7:56:14.89
#==================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
Import "$includes"
originalArgStr="$*"
scriptDescription="Check cgi file permissions"

#==================================================================================================
## Check to see if any .cgi files do not have execute permissions
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 04-05-13 -- 	dgs - Initial coding
# 04-18-13 -- 	dgs - Refactored script
#				Added current info about a file to output
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	#==================================================================================================
	function parseArgs-checkCgiPermissions {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-fix,1,switch,fix,,script,'Fix the file permissions (chmod ug+rx)')
	}
	function Goodbye-checkCgiPermissions  {
		:
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

sendMail=false
fix=false
printedHeader='false'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script'

GetDefaultsData $myName
ParseArgsStd
Hello

#==================================================================================================
## main
#==================================================================================================
checkFiles="$(tr ',' ' ' <<< $scriptData1)"
checkPermissions="$scriptData2"
checkEnvs="$(tr ',' ' '<<< $scriptData3)"

for searchSpec in $checkFiles; do
	Verbose "Checking: $searchSpec"
	SetFileExpansion 'on'
	unset files
	for env in $checkEnvs; do
		files+=( $(ls -l /mnt/*/*/$env/$searchSpec 2> /dev/null | grep -v ^'l' | grep -v ^"$checkPermissions" | awk 'BEGIN {FS=" "}{print $9}') )
	done
	SetFileExpansion

	for file in "${files[@]}"; do
		if [[ $printedHeader == false ]]; then
			[[ $fix == true ]] && connector='did' || connector='do'
			Msg2 "\nThe following files $connector not have correct (${checkPermissions:1}) file execute permissions: " | tee -a $tmpFile
			printedHeader=true
		fi
		Msg2 "\n$file" | tee -a $tmpFile;
		currentPermissions=$(ls -lc $file | awk 'BEGIN {FS=" "}{print $1}')
		fileCtime=$(ls -lc $file | awk 'BEGIN {FS=" "}{printf "%s %s %s", $6, $7, $8}')
		Msg2 "^Current permissions: '${currentPermissions:1}'" | tee -a $tmpFile;
		Msg2 "^File ctime: '$fileCtime'" | tee -a $tmpFile;

		if [[ $fix == true ]]; then
			Msg2 "^*** File permissions have been updated ***" | tee -a $tmpFile;
			$DOIT chmod ugo+rx $file
		fi
		sendMail=true
	done
done

## Send out emails
if [[ $sendMail == true && $noEmails == false ]]; then
	unset addNot
	[[ $fix == false ]] && addNot='NOT '
	Msg2 "\nNote: The files have ${addNot}been fixed" | tee -a $tmpFile;
	Msg2 "\nEmails sent to: $emailAddrs" | tee -a $tmpFile
	#$DOIT mail -s "$myName found discrepancies" $emailAddrs < $tmpFile
	$DOIT mutt -s "$myName detected Errors - $(date +"%m-%d-%Y")" -- $emailAddrs < $tmpFile
fi

#==================================================================================================
## Bye-bye
#==================================================================================================
Goodbye 0

#==================================================================================================
## Change Log
#==================================================================================================
## Tue Mar 15 10:57:14 CDT 2016 - dscudiero - Switch to use SetFileExpansion function
## Tue Mar 15 10:58:24 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Mar 18 12:49:56 CDT 2016 - dscudiero - Updated to make sure noglob settings are correct
## Thu Apr  7 08:42:37 CDT 2016 - dscudiero - Pull config data from the databaser
## Thu Apr 28 07:53:03 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Apr 28 07:56:00 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Jul 11 08:33:33 CDT 2016 - dscudiero - Remove extra SetFilexpansion call
## Mon Aug 22 08:59:27 CDT 2016 - dscudiero - Switch to use mutt for email
## Wed Oct  5 10:17:58 CDT 2016 - dscudiero - Tweak emailing
## Tue Feb  7 07:56:26 CST 2017 - dscudiero - Fix problem printing out file names
