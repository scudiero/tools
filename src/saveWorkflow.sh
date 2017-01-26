#!/bin/bash
#====================================================================================================
version=2.2.42 # -- dscudiero -- 01/26/2017 @ 12:25:31.46
#====================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Save workflow files"

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
	#==================================================================================================
	function parseArgs-saveWorkflow {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-all,1,switch,allCims,,,"Save all CIMs")
		argList+=(-suffix,3,option,suffix,,,"suffix to add to the end of the file name")
		argList+=(-cims,4,option,cimStr,,,"Comma seperated list of CIMS to backup")
	}
	function Goodbye-saveWorkflow  { # or Goodbye-local
		rm -rf $tmpRoot > /dev/null 2>&1
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
Init "getClient getEnv getDirs checkEnvs getCims $allCims noPreview noPublic"

dump -1 scriptData1 scriptData2 scriptData3 scriptData4
## Get the files to act on from the database
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles suffix
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
## Set target location
	tgtDir=$localClientWorkFolder/$client/$env.backup
	[[ -d $localClientWorkFolder/attic/$client ]] && tgtDir=$localClientWorkFolder/attic/$client/$env.backup
	[[ ! -d $tgtDir ]] && mkdir -p $tgtDir

## Clean up old stuff
	cwd=$(pwd)
	cd $tgtDir
	dirs=$(find -maxdepth 1 -type d -printf "%f ")
	for dir in ${dirs[@]}; do
		[[ $dir == '.' ]] && continue
		cd $dir
		tarFile="$dir.tar.gz"
		SetFileExpansion 'on'
		tar -czf ../$tarFile * |> /dev/null
		SetFileExpansion
		rm -rf $dir
		cd ..
	done
	cd $cwd	

## Backup the folders
	tgtDir=$tgtDir/$backupSuffix
	[[ ! -d $tgtDir ]] && mkdir -p $tgtDir
	## Insance files
		for dir in $(echo $cimStr | tr ',' ' '); do
			Msg2 "Saving: $dir"
			if [[ ! -d $tgtDir/$dir ]]; then $DOIT mkdir -p $tgtDir/$dir ; fi
			for file in $(echo "$requiredInstanceFiles $optionalInstanceFiles" | tr ',' ' '); do
				[[ -f $srcDir/web/$dir/$file ]] && $DOIT cp -rfp $srcDir/web/$dir/$file $tgtDir/$dir/$file
			done
		done #CIMs

	## Global files
		Msg2 "Saving: System files"
			for file in $(echo "$requiredGlobalFiles $optionalGlobalFiles" | tr ',' ' '); do
			[[ -f $srcDir/web$file ]] && mkdir -p $(dirname $tgtDir/web$file) && $DOIT cp -rfP $srcDir/web$file $tgtDir/web$file 
		done

	## Create a tar file
		cwd=$(pwd)
		cd $tgtDir
		[[ $suffix == '' ]] && tarFile="$(basename $tgtDir).tar.gz" || tarFile="$(basename $tgtDir)-$suffix.tar.gz"
		SetFileExpansion 'on'
		tar -czf ../$tarFile * |> /dev/null
		SetFileExpansion
		rm -rf $tgtDir
		Msg2 "Files saved to: $(pwd)/$tarFile"
		cd $cwd

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
