#!/bin/bash
#====================================================================================================
version=2.2.88 # -- dscudiero -- Thu 11/30/2017 @ 13:17:54.03
#====================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue MkTmpFile'
includes="$includes RunSql2 ParseCourseleafFile"
Import "$includes"

originalArgStr="$*"
scriptDescription="This script can be used to save workflow files to your personal Linux home directory space"

#==================================================================================================
# Save off workflow files for safe keeling
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	# Call saveWorkflow -daemon -siteFile "$file" -all -suffix "beforeDelete-$backupSuffix -quiet -nop"
	#==================================================================================================
	function parseArgs-saveWorkflow {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-all,1,switch,allCims,,,"Save all CIMs")
		argList+=(-suffix,3,option,suffix,,,"suffix to add to the end of the file name")
		argList+=(-cims,4,option,cimStr,,,"Comma seperated list of CIMS to backup")
		argList+=(-daemon,6,switch,daemon,,,"Script being called as a daemon to auto save workflows")
		argList+=(-siteFile,4,option,siteFile,,,"Full path of the site directory, only used in daemon mode")
	}
	function Goodbye-saveWorkflow  { # or Goodbye-local
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}
	function testMode-saveWorkflow  { # or testMode-local
		scriptData1="requiredInstanceFiles:workflow.tcf,cimconfig.cfg,custom.atj"
		scriptData2="optionalInstanceFiles:workflow.cfg,workflowFuncs.atj,custom-workflow.atj,workflowFunctions.atj,workflowHelperFunctions.atj,triggers.atj"
		scriptData3="requiredGlobalFiles:/courseleaf/cim/triggers.atj,/courseleaf/stdhtml/workflow.atj"
		scriptData4="optionalGlobalFiles:/courseleaf/locallibs/workflowLib.atj,/courseleaf/localsteps/workflowLib.atj"
		return 0
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
saveAll=false

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet="client,env,script,cims"
GetDefaultsData $myName
ParseArgsStd
Hello
[[ $allCims == true ]] && allCims='allCims' || unset allCims
if [[ $daemon == true ]]; then
	[[ -z $siteFile ]] && Terminate "If the -daemon flag is specified you must also specify a siteFile name"
	data="$(ParseCourseleafFile "$siteDir")"
	client="${data%% *}"
	client="${client%%-*}"
	data="${data#* }"
	env="${data%% *}"

	dump -1 userName siteFile data client env
	GetCims "$siteFile" -all
	srcDir="$siteFile"
	backupFolder="$tmpRoot/$myName/$client-$env-$BASHPID/beforeDelete"
else
	Init "getClient getEnv getDirs checkEnvs getCims $allCims noPreview noPublic"
	backupFolder="$tmpRoot/$myName/$client-$env-$BASHPID/$myName"
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Env:$(TitleCase $env)")
	verifyArgs+=("CIMs:$cimStr")
	verifyContinueDefault='Yes'
	VerifyContinue "You are asking to save workflow files for"
fi

#dump isMe daemon siteFile client env srcDir cimStr backupFolder scriptData1 scriptData2 scriptData3 scriptData4
dump -1 scriptData1 scriptData2 scriptData3 scriptData4
## Get the files to act on from the database
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles
	if [[ $scriptData1 == '' ]]; then
		sqlStmt="select scriptData1 from $scriptsTable where name=\"copyWorkflow\""
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not retrieve workflow files data (scriptData1) from the $scriptsTable.";
		scriptData="${resultSet[0]}"
	fi
	requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData)"

	if [[ $scriptData2 == '' ]]; then
		sqlStmt="select scriptData2 from $scriptsTable where name=\"copyWorkflow\""
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not retrieve workflow files data (scriptData1) from the $scriptsTable.";
		scriptData="${resultSet[0]}"
	fi
	optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData)"

	if [[ $scriptData3 == '' ]]; then
		sqlStmt="select scriptData3 from $scriptsTable where name=\"copyWorkflow\""
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not retrieve workflow files data (scriptData1) from the $scriptsTable.";
		scriptData="${resultSet[0]}"
	fi
	requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData)"

	if [[ $scriptData4 == '' ]]; then
		sqlStmt="select scriptData4 from $scriptsTable where name=\"copyWorkflow\""
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not retrieve workflow files data (scriptData1) from the $scriptsTable.";
		scriptData="${resultSet[0]}"
	fi
	optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData)"

	dump -1 requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles

#==================================================================================================
## Main
#==================================================================================================
## Backup the folders
	echo
	[[ -d $backupFolder ]] && rm -rf $backupFolder || mkdir -p "$backupFolder"
## Insance files
	for dir in $(echo $cimStr | tr ',' ' '); do
		Msg2 "Saving: $dir"
		for file in $(echo "$requiredInstanceFiles $optionalInstanceFiles" | tr ',' ' '); do
			if [[ -f $srcDir/web/$dir/$file ]]; then
				[[ ! -d $(dirname $backupFolder/web/$dir/$file) ]] && $DOIT mkdir -p "$(dirname $backupFolder/web/$dir/$file)"
				$DOIT cp -rfp $srcDir/web/$dir/$file $backupFolder/web/$dir/$file
			fi
		done
	done #CIMs

## Global files
	Msg2 "Saving: System files"
		for file in $(echo "$requiredGlobalFiles $optionalGlobalFiles" | tr ',' ' '); do
			if [[ -f $srcDir/web$file ]]; then
				[[ ! -d $(dirname $backupFolder/web$file) ]] && $DOIT mkdir -p "$(dirname $backupFolder/web$file)"
				$DOIT cp -rfP $srcDir/web$file $backupFolder/web$file
			fi
		done

## Tar up the workflow files
	pushd "$backupFolder" >& /dev/null
	numFiles=$(find .//. ! -name . -print | grep -c //)
	if [[ $numFiles -gt 0 ]]; then
		tarDir=$localClientWorkFolder/$client/workflowBackups
		[[ ! -d $tarDir ]] && mkdir -p "$tarDir"
		tarFile="$tarDir/${env}--$backupSuffix.tar.gz"
		ProtectedCall "tar -cpzf \"$tarFile\" ./*"; rc=$?
		[[ $rc -ne 0 ]] && Error "Non-zero return code from tar"
		cd ..
		rm -rf "/${backupFolder#*/}"
	else
		Error "$myName: No files to save"
	fi
	popd >& /dev/null

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0
#==================================================================================================
## Checkin log
#==================================================================================================
## Wed Apr 27 15:55:53 CDT 2016 - dscudiero - Switch to use RunSql
## Wed Apr 27 15:57:54 CDT 2016 - dscudiero - Switch to use RunSql
## Tue Jul  5 09:36:10 CDT 2016 - dscudiero - Fix problem createing backup directory
## Thu Aug 11 12:44:42 CDT 2016 - dscudiero - Refactored to use new files as defined in the db
## Tue Sep  6 07:54:54 CDT 2016 - dscudiero - Fix problem where it was not saving all files
## Tue Sep  6 08:19:50 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jan 26 12:26:59 CST 2017 - dscudiero - Misc cleanup
## Mon Mar  6 12:07:35 CST 2017 - dscudiero - fixed problem overwritting the same file if suffix was passed
## 05-04-2017 @ 14.16.56 - (2.2.52)    - dscudiero - Add daemon mode to support automatic cleanup
## 05-04-2017 @ 15.28.14 - (2.2.53)    - dscudiero - remove debug code
## 05-16-2017 @ 10.26.39 - (2.2.62)    - dscudiero - Renamed the target tar file to match copyWorkflow
## 05-17-2017 @ 07.10.40 - (2.2.64)    - dscudiero - Added processid to the temp folder name
## 05-19-2017 @ 08.51.28 - (2.2.68)    - dscudiero - Added debug statements
## 05-24-2017 @ 08.31.07 - (2.2.70)    - dscudiero - Put call to tar in a protectedCall
## 05-24-2017 @ 12.18.18 - (2.2.71)    - dscudiero - Fix issue with the ProtectedCall syntax
## 06-06-2017 @ 09.49.36 - (2.2.72)    - dscudiero - removed debug statements
## 06-13-2017 @ 08.50.14 - (2.2.73)    - dscudiero - Add debug statement
## 06-13-2017 @ 08.51.01 - (2.2.74)    - dscudiero - General syncing of dev to prod
## 08-28-2017 @ 07.28.29 - (2.2.75)    - dscudiero - turn off debug statement
## 08-31-2017 @ 07.43.10 - (2.2.76)    - dscudiero - add debug stuff
## 09-01-2017 @ 08.18.19 - (2.2.79)    - dscudiero - Add debug statements
## 09-07-2017 @ 08.02.48 - (2.2.80)    - dscudiero - Add debug messages
## 09-13-2017 @ 06.59.34 - (2.2.84)    - dscudiero - remove debug statements
## 09-13-2017 @ 11.22.19 - (2.2.84)    - dscudiero - Change the parsing of the client and env for daemon mode
## 11-30-2017 @ 13.26.45 - (2.2.88)    - dscudiero - Switch to use the -all flag on the GetCims call
