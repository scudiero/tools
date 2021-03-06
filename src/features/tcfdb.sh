#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.2.39 # -- dscudiero -- Wed 05/16/2018 @ 15:42:44.96
#==================================================================================================
# NOTE: intended to be sourced from the courseleafFeature script, must run in the address space
# of the caller.  Expects values to be set for client, env, siteDir
#==================================================================================================
# Configure Custom emails on a Courseleaf site
#==================================================================================================
TrapSigs 'on'
myIncludes="GetCims StringFunctions SetFileExpansion ProtectedCall Pause WriteChangelogEntry InsertLineInFile"
Import "$standardIncludes $myIncludes"

currentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[0]}))
parentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[1]}))
originalArgStr="$*"

#==================================================================================================
# Data used by the parent with a setVarsOnly call
#==================================================================================================
eval "$(basename ${BASH_SOURCE[0]%%.*})scriptDescription='Install The CourseLeaf tcf database (tcfdb)'"

filesStr='/courseleaf.cfg;/web/courseleaf/courseleaf.cgi;/db/tcfdb.sqlite;/clienttransfers/tcfdb.sqlite'
filesStr="$filesStr;/bin/daily.sh;/web/courseleaf/localsteps/default.tcf"
eval "$(basename ${BASH_SOURCE[0]%%.*})potentialChangedFiles=\"$filesStr\""

actionsStr='1) Check to see if already installed'
actionsStr="$actionsStr;2) Check cgi version to make sure tcfdb will run, if old then update"
actionsStr="$actionsStr;3) Create the tcfdb database, copy to /clienttransfers"
actionsStr="$actionsStr;4) Check for correct daily.sh setup, if not setup then setup"
eval "$(basename ${BASH_SOURCE[0]%%.*})actions=\"$actionsStr\""

[[ $1 == 'setVarsOnly' ]] && return 0

#==================================================================================================
# functions
#==================================================================================================

#==================================================================================================
# Declare variables and constants
#==================================================================================================
tgtDir=$siteDir
feature=$(echo $myName | cut -d'.' -f1)
myName="courseleafFeature-$feature"
minCgiVer=9.2.61
unset changesMade

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
Hello
ParseArgsStd $originalArgStr
Init 'getClient getEnv getDirs checkEnvs'
tgtDir=$srcDir
srcDir=$skeletonRoot/release
feature=$(echo $myName | cut -d'.' -f1)
changeLogRecs+=("Feature: $feature")

#==================================================================================================
# Main
#==================================================================================================
## Check to see if it is already there
	editFile=$tgtDir/courseleaf.cfg
	dump -1 tgtDir srcDir editFile
	checkStr='db:tcfdb|sqlite|/db/tcfdb.sqlite'
	grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"

	hasConsoleEntry=false
	[[ $grepStr != '' ]] && hasConsoleEntry=true

	cgiVerIsOk=false
	myCourseleafCgi="$tgtDir/web/courseleaf/courseleaf.cgi"
	[[ -f $tgtDir/web/courseleaf/tcfdb/courseleaf.cgi ]] && myCourseleafCgi="$tgtDir/web/courseleaf/tcfdb/courseleaf.cgi"

	courseleafCgiVer=$($myCourseleafCgi -v | cut -d" " -f 3)
	rel="$(echo $courseleafCgiVer | cut -d'.' -f1)"
	ver="00$(echo $courseleafCgiVer | cut -d'.' -f2)"
	edit="00$(echo $courseleafCgiVer | cut -d'.' -f3)"
	courseleafCgiVer=${rel}${ver: -3}${edit: -3}

	rel="$(echo $minCgiVer | cut -d'.' -f1)"
	ver="00$(echo $minCgiVer | cut -d'.' -f2)"
	edit="00$(echo $minCgiVer | cut -d'.' -f3)"
	minVer=${rel}${ver: -3}${edit: -3}
	[[ $minVer -le $courseleafCgiVer ]] && cgiVerIsOk=true

	if [[ $hasConsoleEntry == true && $cgiVerIsOk == true ]]; then
		if [[ $force == false ]]; then
			unset ans;
			Prompt 'ans' "Feature '$feature' is already installed, Do you wish to force install" "Yes,No" 'No'; ans="$(Lower ${ans:0:1})"
			[[ $ans != 'y' ]] && Goodbye 1
		else
			Note "Feature '$feature' is already installed, force option active, refreshing"
		fi
	fi

## Add tcfdb db declaration
	editFile="$tgtDir/courseleaf.cfg"
	searchStr='db:tcfdb|sqlite|/db/tcfdb.sqlite'
	Msg "Checking '$editFile'"
	grepStr=$(ProtectedCall "grep \"^$searchStr\" $editFile")
	if [[ $grepStr == '' ]]; then
		Msg "^Adding: $searchStr"
		afterLine="$(ProtectedCall "grep '^db:' $editFile | tail -1")"
		[[ $afterLine == '' ]] && Terminate 0 1 "Could not compute location to insert line:\n\t$searchStr\n\tinto file:\n\t$editFile"
		unset insertMsg; insertMsg=$(InsertLineInFile "$searchStr" "$editFile" "$afterLine")
		[[ $insertMsg != true ]] && Terminate 0 1 "Error inserting line into file '$editFile':\n\t$inserMsg"
		changeLogRecs+=("Added 'db:tcfdb|sqlite|/db/tcfdb.sqlite' to courseleaf.cfg")
		changesMade=true
	fi
	Msg "^Checking completed"

## update the courseleaf.cgi file
	if [[ $cgiVerIsOk != true ]]; then
		## Get the cgisDir
			courseleafCgiDirRoot="$skeletonRoot/release/web/courseleaf"
			useRhel="rhel${myRhel:0:1}"
			courseleafCgiSourceFile="$courseleafCgiDirRoot/courseleaf.cgi"
			[[ -f "$courseleafCgiDirRoot/courseleaf-$useRhel.cgi" ]] && courseleafCgiSourceFile="$courseleafCgiDirRoot/courseleaf-$useRhel.cgi"
			courseleafCgiVer="$($courseleafCgiSourceFile -v  2> /dev/null | cut -d" " -f3)"
			dump -1 courseleafCgiSourceFile courseleafCgiVer

		Msg; Msg "Updating courseleaf.cgi file to version $courseleafCgiVer..."
		## Copy the cgi file
			unset courseleafCgiVer
			result=$(CopyFileWithCheck "$courseleafCgiSourceFile" "$myCourseleafCgi" 'courseleaf')
			if [[ $result == true ]]; then
				chmod 755 $tgtDir/web/courseleaf/courseleaf.cgi
				changeLogRecs+=("Updated: courseleaf.cfg")
				changesMade=true
			else
				Terminate "Could not copy courseleaf.cgi.\n\t$result"
			fi
	fi

## Create the tcfdb database
	Msg; Msg "Creating tcfdb instance, finding base database..."
	## Delete any existing tcfdb.sqlite file
		cwd=$(pwd)
		[[ -f $tgtDir/db/tcfdb.sqlite ]] && $DOIT rm -f $tgtDir/db/tcfdb.sqlite

	# Find the base database file, look in the cims
		unset baseDbFile
		GetCims "$tgtDir" -all
		if [[ ${#cims[@]} -gt 0 ]]; then
			for cim in "${cims[@]}"; do
				## Get the dbname field from the cimconfig.cfg file, parse of the dbname
				grepStr=$(ProtectedCall "grep '^dbname:' $tgtDir/web/$cim/cimconfig.cfg")
			if [[ $grepStr != '' ]]; then
				grepStr=$(echo $grepStr | tr -d '\040\011\012\015')
				dbName=$(echo $grepStr | cut -d':' -f2)
				## Lookup dbname mapping in courseleaf.cfg
				grepStr=$(ProtectedCall "grep \"^db:$dbName|\" $tgtDir/courseleaf.cfg")
				if [[ $grepStr != '' ]]; then
					grepStr=$(echo $grepStr | tr -d '\040\011\012\015')
					dbFile=$(echo $grepStr | cut -d'|' -f3)
					## If the file exists then check to see if there is any data
					if [[ -r ${tgtDir}${dbFile} ]]; then
						## Get the base table name from the cimconfig .cfg file, see if there is any data in the table
						grepStr=$(ProtectedCall "grep '^dbbasetable:' $tgtDir/web/$cim/cimconfig.cfg")
						if [[ $grepStr != '' ]]; then
							grepStr=$(echo $grepStr | tr -d '\040\011\012\015')
							dbTable=$(echo $grepStr | cut -d':' -f2)
							sqlStmt="select count(*) from $dbTable;"
							count=$(sqlite3 ${tgtDir}${dbFile} "$sqlStmt")
							[[ $count -gt 0 ]] && baseDbFile="${tgtDir}${dbFile}" && break
						fi
					fi
				fi
			fi
			changesMade=true
		done
		fi

	## If baseDbFile is set then we found a viable sqlite file, otherwise use the coursedb file
		if [[ $baseDbFile == '' ]]; then
			grepStr=$(ProtectedCall "grep \"^db:coursedb|\" $tgtDir/courseleaf.cfg")
			if [[ $grepStr != '' ]]; then
				grepStr=$(echo $grepStr | tr -d '\040\011\012\015')
				dbFile=$(echo $grepStr | cut -d'|' -f3)
				baseDbFile="${tgtDir}${dbFile}"
				#if [[ -r ${tgtDir}${dbFile} ]]; then
				#	sqlStmt="select count(*) from course;"
				#	count=$(sqlite3 ${tgtDir}${dbFile} "$sqlStmt")
				#	[[ $count -gt 0 ]] && baseDbFile="${tgtDir}${dbFile}"
				#fi
			fi
		fi

	## If baseDbFile is still not set then error out
		[[ $baseDbFile == '' ]] && Msg $T "Could not determine the base sqlite file to use"
		$DOIT cp -fp "$baseDbFile" $tgtDir/db/tcfdb.sqlite
		Msg "^Using base database file: '$baseDbFile'"

	## Add tcfdb tables
		Msg "^Exporting courseleaf data (takes a while)..."
		cwd=$(pwd)
	 	$DOIT cd "$tgtDir/web/courseleaf"
		$myCourseleafCgi --sqlexport /
		$DOIT cd $cwd

 	## Attach User Provisioning
 		Msg "^Attaching the 'users' data..."
		## get the clusers file name
		unset clusersDbFile
		grepStr=$(ProtectedCall "grep '^db:clusers|' $tgtDir/courseleaf.cfg")
		grepStr=$(echo $grepStr | tr -d '\040\011\012\015')
		clusersDbFile=$(echo $grepStr | cut -d'|' -f3)
		if [[ $clusersDbFile != '' ]]; then
 			SetFileExpansion 'off'
	 			sqlStmt="attach '${tgtDir}${clusersDbFile}' as clusers; create table main.users as select * from clusers.users;"
	 			$DOIT sqlite3 $tgtDir/db/tcfdb.sqlite "$sqlStmt"
	 		SetFileExpansion
			changesMade=true
		else
			Warning "Could not locate the clusers file, it will not be attached"
		fi

	## Attach Eco System DB
		Msg "^Attaching the 'eco system' data..."
		sqlStmt="drop table if exists courseref;"
		$DOIT sqlite3 $tgtDir/db/tcfdb.sqlite "$sqlStmt"
		## get the courseref file name
		unset courseRefDbFile
		grepStr=$(ProtectedCall "grep '^db:courseref|' $tgtDir/courseleaf.cfg")
		grepStr=$(echo $grepStr | tr -d '\040\011\012\015')
		courseRefDbFile=$(echo $grepStr | cut -d'|' -f3)
		if [[ $courseRefDbFile != '' ]]; then
			SetFileExpansion 'off'
			sqlStmt="attach '${tgtDir}${courseRefDbFile}' as courseref; create table main.courseref as select * from courseref.courseref"
			$DOIT sqlite3 $tgtDir/db/tcfdb.sqlite "$sqlStmt"
			SetFileExpansion
			changesMade=true
		else
			Warning "Could not locate the coursedb file, it will not be attached"
		fi

	## Copy to client transfers folder
		Msg "^Moving database file to /clienttransfers"
		[[ -f $tgtDir/clienttransfers/tcfdb.sqlite ]] && mv -f $tgtDir/clienttransfers/tcfdb.sqlite $tgtDir/clienttransfers/tcfdb.sqlite.bak
		$DOIT cp -f $tgtDir/db/tcfdb.sqlite $tgtDir/clienttransfers/tcfdb.sqlite

	changeLogRecs+=("Created: /clienttransfers/tcfdb.sqlite")
	Msg "^Database creation completed"


## Check daily.sh
	Msg; Msg "Checking /bin/daily.sh..."
	if [[ ! -f $tgtDir/bin/daily.sh ]]; then
		Msg "^This client does not have a /bin/daily.sh file, copy from the skeleton..."
		$DOIT cp "$skeletonRoot/release/bin/daily.sh" "$tgtDir/bin/daily.sh"
		Warning 0 1 "This site did not have a daily.sh script, Please contact the System Administration (UNIX) team and have them schedule the cron task for this client."
	fi
	grepStr=$(ProtectedCall "grep '^## DO NOT MODIFY THIS FILE ##' $tgtDir/bin/daily.sh")
	if [[ $grepStr != '' ]]; then
		grepStr=$(ProtectedCall "grep '^dailycron:' $tgtDir/web/courseleaf/localsteps/default.tcf")
		if [[ $grepStr != '' ]]; then
			grepStr=$(echo $grepStr | tr -d '\040\011\012\015')
			currentData=$(cut -d':' -f2 <<< $grepStr)
			[[ $currentData == "" ]] && Warning 0 1 "This site's localsteps/default.tcf file needs to be configured, see 'https://stage-internal.leepfrog.com/development/libraries/dailysh/' For additional information."
			if [[ $(Contains "$grepStr" 'tcfdb') != true ]]; then
				fromStr="$grepStr"
				[[ $currentData == "" ]] && toStr="${fromStr}tcfdb" || toStr="${fromStr},tcfdb"
				$DOIT sed -i s"_^${fromStr}_${toStr}_" $tgtDir/web/courseleaf/localsteps/default.tcf
				Msg "^/localsteps/default.tcf file updated"
				changeLogRecs+=("Updated: /localsteps/default.tcf")
			fi
		else
			Warning 0 1 "This site's localsteps/default.tcf file needs to be configured, see 'https://stage-internal.leepfrog.com/development/libraries/dailysh/' For additional information."
		fi
	else
		Warning 0 1 "This site is not running the 'new' daily.sh script, the site will need to be updated use the new script to ensure that the tcfdb is refreshed nightly, see 'https://stage-internal.leepfrog.com/development/libraries/dailysh/' For additional information."
	fi
	Msg "^Checking completed"

# If changes made then log to changelog.txt
	if [[ ${#changeLogRecs[@]} -gt 1 ]]; then
		myName=$parentScript
		WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"
		Pause "Feature '$feature' installed, please press any key to continue"
	else
		Pause "Feature '$currentScript': No changes were made"
	fi

[[ -x $HOME/bin/logit ]] && $HOME/bin/logit -cl "${client:--}" -e "${tgtEnv:--}" -ca 'features' "$myName - Installed $feature"

#==================================================================================================
## Done
#==================================================================================================
return  ## We are called as a subprocess, just return to our parent

#==================================================================================================
## Change Log
#==================================================================================================## Tue Mar  7 14:44:52 CST 2017 - dscudiero - Update description
## Tue Mar 14 12:18:47 CDT 2017 - dscudiero - Tweak messaging
## 07-19-2017 @ 14.37.40 - (1.2.19)    - dscudiero - Update how the cgi files are sourced
## 09-22-2017 @ 07.50.23 - (1.2.32)    - dscudiero - Add to imports
## 11-02-2017 @ 11.48.48 - (1.2.33)    - dscudiero - Switch Msg to Msg
## 11-02-2017 @ 12.06.35 - (1.2.34)    - dscudiero - Added InsertLineInFile
## 11-30-2017 @ 13.26.39 - (1.2.35)    - dscudiero - Switch to use the -all flag on the GetCims call
## 03-22-2018 @ 14:36:17 - 1.2.36 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:34:35 - 1.2.37 - dscudiero - D
## 03-23-2018 @ 17:05:44 - 1.2.38 - dscudiero - Msg3 -> Msg
## 05-16-2018 @ 15:45:49 - 1.2.39 - dscudiero - Added activityLog logging
