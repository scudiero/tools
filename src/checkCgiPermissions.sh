#!/bin/bash
#==================================================================================================
version=2.2.42 # -- dscudiero -- Fri 03/23/2018 @ 14:26:02.39
#==================================================================================================
TrapSigs 'on'

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
# Standard call back functions
#==================================================================================================
	function checkCgiPermissions-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		myArgs+=('fix|fix|switch|fix||script|Fix the file permissions (chmod ug+rx)')
		return 0
	}

	function checkCgiPermissions-Goodbye {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function checkCgiPermissions-Help {
		helpSet='' # can also include any of {env,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0

		[[ -z $* ]] && return 0
		bullet=1
		echo -e "This script can be used to check the courseleaf cgi unix file permissions are set correctly"
		echo -e "\nThe actions performed are:"
		echo -e "\t$bullet) Check the file permissions and compare to '$scriptData2' (from scriptData2), if different then report"
		(( bullet++ ))
		echo -e "\t$bullet) if the -fix flag was specified then the file permssions are set as above"
		echo -e "\nTarget site data files potentially modified (from scriptData1):"
		for file in $(tr ',' ' ' <<< $scriptData1); do
			echo -e "\t- $file"
		done
		return 0
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
GetDefaultsData $myName
ParseArgsStd $originalArgStr
Hello
tmpFile=$(MkTmpFile)

#==================================================================================================
## main
#==================================================================================================
# web/courseleaf/courseleaf.cgi,web/ribbit/index.cgi
checkFiles="$(tr ',' ' ' <<< $scriptData1)"
# .rwxr.x...|.rwxr..r...
checkPermissions1="${scriptData2%%,*}"
checkPermissions2="${scriptData2##*,}"
checkEnvs="$(tr ',' ' '<<< $scriptData3)"

for searchSpec in $checkFiles; do
	Verbose "Checking: $searchSpec"
	SetFileExpansion 'on'
	unset files
	for env in $checkEnvs; do
		#files+=( $(ls -l /mnt/*/*/$env/$searchSpec 2> /dev/null | grep -v ^'l' | grep -v ^"$checkPermissions" | awk 'BEGIN {FS=" "}{print $9}') )
		files+=($(ls -l /mnt/*/*/$env/$searchSpec 2> /dev/null | grep -v ^'l' | grep -v ^"$checkPermissions1" | grep -v ^"$checkPermissions2" | awk 'BEGIN {FS=" "}{print $9}') )
	done
	SetFileExpansion

	for file in "${files[@]}"; do
		if [[ $printedHeader == false ]]; then
			[[ $fix == true ]] && connector='did' || connector='do'
			Msg "\nThe following files $connector not have correct (${checkPermissions:1}) file execute permissions: " | tee -a $tmpFile
			printedHeader=true
		fi
		Msg "\n$file" | tee -a $tmpFile;
		currentPermissions=$(ls -lc $file | awk 'BEGIN {FS=" "}{print $1}')
		fileCtime=$(ls -lc $file | awk 'BEGIN {FS=" "}{printf "%s %s %s", $6, $7, $8}')
		Msg "^Current permissions: '${currentPermissions:1}'" | tee -a $tmpFile;
		Msg "^File ctime: '$fileCtime'" | tee -a $tmpFile;

		if [[ $fix == true ]]; then
			Msg "^*** File permissions have been updated ***" | tee -a $tmpFile;
			$DOIT chmod ugo+rx $file
		fi
		sendMail=true
	done
done

## Send out emails
if [[ $sendMail == true && $noEmails == false ]]; then
	unset addNot
	[[ $fix == false ]] && addNot='NOT '
	Msg "\nNote: The files have ${addNot}been fixed" | tee -a $tmpFile;
	Msg "\nEmails sent to: $emailAddrs" | tee -a $tmpFile
	Msg "\n*** Please do not respond to this email, it was sent by an automated process\n" | tee -a $tmpFile
	#$DOIT mail -s "$myName found discrepancies" $emailAddrs < $tmpFile
	$DOIT mutt -s "$myName detected Errors - $(date +"%m-%d-%Y")" -- $emailAddrs < $tmpFile
fi

[[ -f "$tmpFile" ]] && rm "$tmpFile"

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
## Mon Feb 13 15:59:17 CST 2017 - dscudiero - Make sure we are using our own tmpFile
## 06-23-2017 @ 09.26.32 - (2.2.29)    - dscudiero - Add 'do not respond' to the email
## 09-12-2017 @ 07.35.27 - (2.2.37)    - dscudiero - Check against two different permission templates
## 03-22-2018 @ 12:35:26 - 2.2.41 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:32:04 - 2.2.42 - dscudiero - D
