#!/bin/bash
#==================================================================================================
version=2.4.68 # -- dscudiero -- Fri 03/23/2018 @ 14:42:11.15
#==================================================================================================
TrapSigs 'on'

myIncludes="ProtectedCall StringFunctions"
Import "$standardIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Check for private sites and notify the user owning the sites."

#= Description +===================================================================================
# Check to see if the user has any private dev sites
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
Hello
GetDefaultsData $myName
ParseArgsStd $originalArgStr
tmpFile=$(MkTmpFile)

#==================================================================================================
# Pull script defined data from the script record in the scripts database
#==================================================================================================
[[ $scriptData1 != '' ]] && deleteLimitDays=$scriptData1 || deleteLimitDays=10
dump -2 deleteLimitDays

#==================================================================================================F
## main
#==================================================================================================
## If client is specified then check files for that user, otherwise
## Get the list of userids from the employee table
	userId=$client
	if [[ $userId == '' ]]; then
		Verbose 1 "Pulling employee userid data from $contactsSqliteFile...\n"
		sqlStmt="SELECT db_email FROM employees WHERE db_isactive=\"Y\""
		RunSql "$contactsSqliteFile" "$sqlStmt"
	else
		unset resultSet
		Verbose 1 "Note: Using userid passed in: $userId\n"
		resultSet+=($userId)
	fi

## Loop through all users in the employee table looking for dev sites
if [[ ${#resultSet[@]} -ne 0 ]]; then
	for resultRec in "${resultSet[@]}"; do
		emailAddr="$resultRec"
		userId=$(echo $emailAddr | cut -d '@' -f 1)
		[[ $(Contains "$ignoreList" "$userId") == true ]] && continue
		foundFiles=false
		dirsFound=($(ProtectedCall "ls /mnt/*/web/* | grep '/dev[0-99]/' | grep '\-$userId'"))
		if [[ ${#dirsFound[@]} -gt 0 ]]; then
			if [[ -f $tmpFile ]]; then rm $tmpFile; fi
			foundFiles=true
			echo; echo > "$tmpFile"
			Msg | tee -a $tmpFile
			Msg "^The following private dev sites where found for userid: '$userId' on host: '$hostName'" | tee -a $tmpFile
			Msg | tee -a $tmpFile
			for dir in "${dirsFound[@]}"; do
				## Get the newest last modified date for the site
				pushd "${dir%%:*}" >& /dev/null
				newestModEpoch=$(find . -type f -printf '%T@ %p\n' | sort | tail -1 | cut -f1 -d" " | cut -f1 -d".") #Note: A = Access time, T = Modificaton time
				newestAccEpoch=$(find . -type f -printf '%A@ %p\n' | sort | tail -1 | cut -f1 -d" " | cut -f1 -d".") #Note: A = Access time, T = Modificaton time
				#cd ..
				todaysEpoch=$(date +'%s')
				modDelta=$(( todaysEpoch - newestModEpoch ))
				modDaysOld=$(( modDelta / 86400 ))  ## Convert to days
				accDelta=$(( todaysEpoch - newestAccEpoch ))
				accDaysOld=$(( accDelta / 86400 ))  ## Convert to days
				dump -2 -n $dir newestModEpoch newestAccEpoch todaysEpoch modDelta modDaysOld accDelta accDaysOld
				## Auto delete old files
				# if [[ ${dir:(-11)} == '.AutoDelete' ]]; then
				# 	if [[ $accDaysOld -gt $deleteLimitDays ]]; then
				# 		[[ $userName = 'dscudiero' ]] && saveWorkflow $client -p -all -suffix "beforeDelete-$fileSuffix" -nop -quiet
				# 		mv $dir $dir.DELETE
				# 		$DOIT rm -rf $dir.DELETE &
				# 		Msg "^$dir - Was marked for deleteion and is over the threshold ($accDaysOld > $deleteLimitDays), it was deleted" | tee -a $tmpFile
				# 	fi
				# else
					Msg "^^$(basename $dir) - Last modified $modDaysOld day(s) ago and last accessed $accDaysOld day(s) ago" | tee -a $tmpFile
				# f
				popd >& /dev/null
			done

			Msg "\nRemember, you can use the 'cleanDev' script to easily remove any sites that are no longer needed." >> $tmpFile
			Msg "^See https://internal.leepfrog.com/support/tools/ for additional informaton." >> $tmpFile
			Verbose 2 "$(dump foundFiles noEmails)"
			if [[ $foundFiles == true && $noEmails != true ]]; then
				Verbose "Emails sent to: $resultRec"
				Msg "\n*** Please do not respond to this email, it was sent by an automated process\n" >> $tmpFile
				$DOIT mutt -a "$tmpFile" -s "$hostName -- Private Dev Sites - $(date +"%m-%d-%Y")" -- $emailAddr < $tmpFile
			fi
		fi
	done
else
	Warning "Could not retrieve employee informaton from $contactsSqliteFile"
fi

if [[ -f $tmpFile ]]; then rm $tmpFile; fi

#==================================================================================================
# Quit and go home
#==================================================================================================
Goodbye 0

#==================================================================================================
# Change log
#==================================================================================================
# 11-30-15 - dgs - Updated remove code to print message## Fri Mar 18 14:23:47 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Apr 18 08:23:17 CDT 2016 - dscudiero - Wrap ls command in a ProtectedCall
## Wed Apr 27 16:32:37 CDT 2016 - dscudiero - Switch to use RunSql
## Mon Jun 13 07:09:31 CDT 2016 - dscudiero - Fixed dev directory assignments for build7
## Mon Jul 11 08:43:55 EDT 2016 - dscudiero - use mail command instead of mutt since mutt is not on build7
## Mon Jul 11 07:46:45 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jul 14 16:33:04 CDT 2016 - dscudiero - Refactored logic
## Fri Jul 15 09:00:37 CDT 2016 - dscudiero - Call saveworkflow before delete if user is dscudiero
## Mon Aug  1 08:01:27 CDT 2016 - dscudiero - Switch to use sendmail
## Mon Aug 15 08:05:24 CDT 2016 - dscudiero - Fix problem with the emailaddress for the notificiaton email
## Mon Aug 22 08:59:35 CDT 2016 - dscudiero - Switch to use mutt for email
## Mon Feb 13 15:59:23 CST 2017 - dscudiero - Make sure we are using our own tmpFile
## Thu Mar 16 12:35:31 CDT 2017 - dscudiero - Change employee query to be <> 'N'
## Thu Mar 16 12:40:45 CDT 2017 - dscudiero - Undo last change
## 04-04-2017 @ 09.37.18 - (2.4.34)    - dscudiero - Add last modify date to the output
## 04-04-2017 @ 09.38.29 - (2.4.35)    - dscudiero - make autodelete based on last access date
## 04-04-2017 @ 09.39.55 - (2.4.36)    - dscudiero - Tweak messaging
## 05-05-2017 @ 12.36.22 - (2.4.53)    - dscudiero - General syncing of dev to prod
## 06-23-2017 @ 09.26.40 - (2.4.54)    - dscudiero - Add 'do not respond' to the email
## 07-17-2017 @ 06.56.31 - (2.4.55)    - dscudiero - remove blank line
## 08-28-2017 @ 07.25.34 - (2.4.56)    - dscudiero - misc cleanup
## 09-05-2017 @ 08.56.58 - (2.4.57)    - dscudiero - g
## 09-05-2017 @ 16.22.22 - (2.4.58)    - dscudiero - Make sure there is a tmpFile
## 10-23-2017 @ 08.10.36 - (2.4.61)    - dscudiero - Switch to Msg
## 10-23-2017 @ 11.57.55 - (2.4.64)    - dscudiero - Reformatted messaging
## 11-01-2017 @ 15.59.57 - (2.4.65)    - dscudiero - Switch to use ParseArgsStd
## 11-13-2017 @ 07.36.26 - (2.4.65)    - dscudiero - Add the hostname to the email subject
## 12-11-2017 @ 06.45.08 - (2.4.66)    - dscudiero - Add hostname to the messaging
## 03-22-2018 @ 12:35:32 - 2.4.67 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:32:12 - 2.4.68 - dscudiero - D
