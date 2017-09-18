#!/bin/bash
#==================================================================================================
version=1.0.67 # -- dscudiero -- Thu 09/14/2017 @ 16:26:12.33
#==================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue MkTmpFile'
includes="$includes SelectMenuNew RunSql2 StringFunctions"
Import "$includes"

originalArgStr="$*"
scriptDescription="This script can be used to monitor a file and be notified if that file changes"

#= Description +===================================================================================
# Create an entry in the mopnitorFile table to monitor changes to a file
#
#==================================================================================================

#==================================================================================================
# Standard call back functions
#==================================================================================================
	function parseArgs-monitorFile  { # or parseArgs-$myName
		argList+=(-file,4,option,file,,script,'The full file name to monitor')
		return 0
	}
	function Goodbye-monitorFile  { # or Goodbye-$myName
		SetFileExpansion 'on'
		rm -rf $tmpRoot > /dev/null 2>&1
		SetFileExpansion
		return 0
	}
	function testMode-monitorFile  { # or testMode-$myName
		[[ $userName != 'dscudiero' ]] && Msg "T You do not have sufficient permissions to run this script in 'testMode'"
		return 0
	}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
unset userList newFile

#==================================================================================================
# Standard arg parsing
#==================================================================================================
helpSet='script'
GetDefaultsData $myName
ParseArgsStd
Hello

[[ ${myRhel:0:1} -lt 6 ]] && Msg2 $T "Sorry you may not monitor any files residing on systems not running Red Hat R6 or greater."

#==================================================================================================
# Initialization
#==================================================================================================
## If user specified file on command line then see if it verify it
	if [[ $file != '' ]]; then
		if [[ -f $file ]]; then
			sqlStmt="Select count(*) from monitorfiles where file=\"$file\""
			RunSql2 "$sqlStmt"
			count=${resultSet[0]}
			[[ $count -eq 0 ]] && newFile=true
		else
			Msg2 "$(ColorE "*Error* --") File does not exist\n^'$file'" && unset file
		fi
	fi
## If file was not specified then prompt the user
	if [[ $file == '' ]]; then
		if [[ $verify != true ]]; then Msg2 $T "No value specified for file and verify is off"; fi
		unset menuList menuItem
		## Get a list of currently defined monitoried files
		sqlStmt="Select file from monitorfiles where userlist is null or userlist not like \"%$userName%\" order by file"
		RunSql2 "$sqlStmt"
		if [[ ${#resultSet[@]} -eq 0 ]]; then
			Msg2 "You are already monitoring all of the files in the monitorfiles table:"
			sqlStmt="Select file from monitorfiles order by file"
			RunSql2 "$sqlStmt"
			for result in "${resultSet[@]}"; do
				Msg2 "^$result"
			done
			Msg2; unset ans; Prompt ans "Do you wish to add a new monitor file" 'Yes No' 'No'; ans=$(Lower ${ans:0:1})
			[[ $ans != 'y' ]] && Goodbye 0
			file='Specify a new file name'
		else
			## Build menuList
			menuList+=("|File Name")
			for result in "${resultSet[@]}"; do
				menuList+=("|$result")
			done
			menuList+=("|Specify a new file name")
			## Display Menu
			Msg2
			Msg2 "Please select a file that is currently being monitored:"
			Msg2
			SelectMenuNew 'menuList' 'file' "\nFile ordinal number $(ColorK '(ord)') (or 'x' to quit) > "
			[[ $file == '' ]] && Goodbye 0 || file=$(cut -d'|' -f1 <<< $file)
		fi
		if [[ $file == 'Specify a new file name' ]]; then
			unset file
			Prompt file 'Please enter the file (including full path)' '*file*'
			userList=$userName
			newFile=true
		fi
	fi

## retrieve the userList if necessary
	if [[ $userList == '' ]]; then
		sqlStmt="Select userlist from monitorfiles where file=\"$file\""
		RunSql2 "$sqlStmt"
		#[[ ${#resultSet[@]} -eq 0 ]] && Msg2 $T "No records returned from $warehouseDb.monitorfiles table when looking up the userlist for '$file'"
		[[ ${resultSet[0]} == '' || ${resultSet[0]} == 'NULL' ]] && userList='' || userList="${resultSet[0]}"
		[[ $(Contains ",$userList," ",$userName,") == false ]] && userList="$userList,$userName" || Msg2 $T "You are already on the monitor list for file\n^'$file'"
		[[ ${userList:0:1} == ',' ]] && userList=${userList:1}
	fi

## Verify continue
	unset verifyArgs
	verifyArgs+=("File:$file")
	VerifyContinue "You are asking to monitor changed to the file"

## Log usage
	myData="File: '$file'"
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================
## Add file and user to the subscription list
	if [[ $newFile == true ]]; then
		lastModEtime=$(stat -c %Y $file)
		sqlStmt="insert into monitorfiles values(NULL,\"$file\",\"$hostName\",$lastModEtime,\"$userList\")"
	else
		sqlStmt="update monitorfiles set userList=\"$userList\" where file=\"$file\""
	fi
	RunSql2 $sqlStmt
## Add a 'viewed' record for this file for this user
	sqlStmt="insert into $newsInfoTable values(NULL,\"$file\",\"$userName\",NOW(),\"$(date +%s)\")"
	RunSql2 $sqlStmt

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Thu Apr 28 13:36:36 CDT 2016 - dscudiero - Script to add files to the monitor files table
## Thu Apr 28 14:59:20 CDT 2016 - dscudiero - Add update viewed records
## Thu Apr 28 16:52:25 CDT 2016 - dscudiero - Added host to the monitoredFile data
## Thu Apr 28 16:58:37 CDT 2016 - dscudiero - Removed junk left in from testsh
## Fri Apr 29 16:25:44 CDT 2016 - dscudiero - Check to make sure we are on a system running rhel6 or greater
## Tue Aug 23 11:22:14 CDT 2016 - dscudiero - Updated to correctly parse output of selectMenuNew
## Thu Oct  6 16:40:04 CDT 2016 - dscudiero - Set dbAcc level to Update for db writes
## Thu Oct  6 16:59:26 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct  7 08:00:42 CDT 2016 - dscudiero - Take out the dbAcc switching logic, moved to framework RunSql
## 04-17-2017 @ 10.31.36 - (1.0.66)    - dscudiero - fixed for selectMenuNew changes
