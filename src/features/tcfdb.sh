#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.2.17 # -- dscudiero -- 03/07/2017 @ 14:34:34.04
#==================================================================================================
# NOTE: intended to be sourced from the courseleafFeature script, must run in the address space
# of the caller.  Expects values to be set for client, env, siteDir
#==================================================================================================
# Configure Custom emails on a Courseleaf site
#==================================================================================================
Import GetCims
originalArgStr="$*"
scriptDescription="Install Custom Workflow Emails (wfemail)"
TrapSigs 'on'
parentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[0]}))

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
ParseArgsStd
Hello
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
	Msg2 "Checking '$editFile'"
	grepStr=$(ProtectedCall "grep \"^$searchStr\" $editFile")
	if [[ $grepStr == '' ]]; then
		Msg2 "^Adding: $searchStr"
		afterLine="$(ProtectedCall "grep '^db:' $editFile | tail -1")"
		[[ $afterLine == '' ]] && Terminate 0 1 "Could not compute location to insert line:\n\t$searchStr\n\tinto file:\n\t$editFile"
		unset insertMsg; insertMsg=$(InsertLineInFile "$searchStr" "$editFile" "$afterLine")
		[[ $insertMsg != true ]] && Terminate 0 1 "Error inserting line into file '$editFile':\n\t$inserMsg"
		changeLogRecs+=("Added 'db:tcfdb|sqlite|/db/tcfdb.sqlite' to courseleaf.cfg")
		changesMade=true
	fi
	Msg2 "^Checking completed"

## update the courseleaf.cgi file
	Msg2; Msg2 "Checking courseleaf.cgi file version..."
	if [[ $cgiVerIsOk != true ]]; then
		## Set cgis dir
			cgisDirRoot=$cgisRoot/rhel${myRhel:0:1}
			[[ ! -d $cgisDirRoot ]] && Msg2 $T "Could not locate cgi source directory:\n\t$cgiRoot"
			if [[ -d $cgisDirRoot/release ]]; then
				cgisDir=$cgisDirRoot/release
			else
				cwd=$(pwd)
				cd $cgisDirRoot
				cgisDir=$(ls -t | tr "\n" ' ' | cut -d ' ' -f1)
				#Msg "WT Could not find the 'release' directory in the cgi root directory, using '$cgisDir'"
				cgisDir=${cgisDirRoot}/$cgisDir
			fi
			[[ ! -d $cgisDir ]] && Terminate "Could not find skeleton directory: $cgisDir"

		## Copy the cgi file
			unset courseleafCgiVer
			if [[ -f $cgisDir/courseleaf.cgi ]]; then
				myCourseleafCgi=$tgtDir/web/courseleaf/tcfdb/courseleaf.cgi
				[[ ! -d $(dirname $myCourseleafCgi) ]] && mkdir -p $(dirname $myCourseleafCgi)
				result=$(CopyFileWithCheck "$cgisDir/courseleaf.cgi" "$myCourseleafCgi" 'courseleaf')
				if [[ $result == true ]]; then
					chmod 755 $tgtDir/web/courseleaf/courseleaf.cgi
					courseleafCgiVer=$($tgtDir/web/courseleaf/courseleaf.cgi -v | cut -d" " -f 3)
					Msg2 "^courseleaf.cgi ($courseleafCgiVer) copied"
					changeLogRecs+=("Updated: courseleaf.cfg")
				else
					Terminate "Could not copy courseleaf.cgi.\n\t$result"
				fi
			else
				Terminate "Could not locate source courseleaf.cgi, courseleaf cgi not refreshed."
			fi
			changesMade=true
	else
		Msg2 "^CGI version is OK ($myCourseleafCgi)"
	fi
	Msg2 "^Checking completed"

## Create the tcfdb database
	Msg2; Msg2 "Creating tcfdb instance, finding base database..."
	## Delete any existing tcfdb.sqlite file
		cwd=$(pwd)
		[[ -f $tgtDir/db/tcfdb.sqlite ]] && $DOIT rm -f $tgtDir/db/tcfdb.sqlite

	# Find the base database file, look in the cims
		unset baseDbFile
		allCims=true
		GetCims "$tgtDir"
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
		[[ $baseDbFile == '' ]] && Msg2 $T "Could not determine the base sqlite file to use"
		$DOIT cp -fp "$baseDbFile" $tgtDir/db/tcfdb.sqlite
		Msg2 "^Using base database file: '$baseDbFile'"

	## Add tcfdb tables
		Msg2 "^Exporting courseleaf data (takes a while)..."
		cwd=$(pwd)
	 	$DOIT cd "$tgtDir/web/courseleaf"
		$myCourseleafCgi --sqlexport /
		$DOIT cd $cwd

 	## Attach User Provisioning
 		Msg2 "^Attaching the 'users' data..."
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
		Msg2 "^Attaching the 'eco system' data..."
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
		Msg2 "^Moving database file to /clienttransfers"
		[[ -f $tgtDir/clienttransfers/tcfdb.sqlite ]] && mv -f $tgtDir/clienttransfers/tcfdb.sqlite $tgtDir/clienttransfers/tcfdb.sqlite.bak
		$DOIT cp -f $tgtDir/db/tcfdb.sqlite $tgtDir/clienttransfers/tcfdb.sqlite

	changeLogRecs+=("Created: /clienttransfers/tcfdb.sqlite")
	Msg2 "^Database creation completed"


## Check daily.sh
	Msg2; Msg2 "Checking /bin/daily.sh..."
	if [[ ! -f $tgtDir/bin/daily.sh ]]; then
		Msg2 "^This client does not have a /bin/daily.sh file, copy from the skeleton..."
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
				Msg2 "^/localsteps/default.tcf file updated"
				changeLogRecs+=("Updated: /localsteps/default.tcf")
			fi
		else
			Warning 0 1 "This site's localsteps/default.tcf file needs to be configured, see 'https://stage-internal.leepfrog.com/development/libraries/dailysh/' For additional information."
		fi
	else
		Warning 0 1 "This site is not running the 'new' daily.sh script, the site will need to be updated use the new script to ensure that the tcfdb is refreshed nightly, see 'https://stage-internal.leepfrog.com/development/libraries/dailysh/' For additional information."
	fi
	Msg2 "^Checking completed"

# If changes made then log to changelog.txt
	if [[ ${#changeLogRecs[@]} -gt 1 ]]; then
		myName=$parentScript
		WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"
		Pause "Feature '$feature' installed, please press any key to continue"
	else
		Pause "Feature '$currentScript': No changes were made"
	fi

#==================================================================================================
## Done
#==================================================================================================
return  ## We are called as a subprocess, just return to our parent

#==================================================================================================
## Change Log
#==================================================================================================## Tue Mar  7 14:44:52 CST 2017 - dscudiero - Update description
