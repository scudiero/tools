#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.0.25 # -- dscudiero -- 03/07/2017 @ 14:32:06.01
#==================================================================================================
# NOTE: intended to be sourced from the courseleafFeature script, must run in the address space
# of the caller.  Expects values to be set for client, env, siteDir
#==================================================================================================
# Configure Custom emails on a Courseleaf site
#==================================================================================================
originalArgStr="$*"
scriptDescription="Install System Refresh tool on the CourseLeaf console"
TrapSigs 'on'
parentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[0]}))

#==================================================================================================
# functions
#==================================================================================================

#==================================================================================================
# Declare variables and constants
#==================================================================================================
tgtDir=$siteDir
srcDir=$skeletonRoot/release
feature=$(echo $myName | cut -d'.' -f1)
myName="courseleafFeature-$feature"

#==================================================================================================
# Main
#==================================================================================================
## Check to see if it is already there
	editFile=$tgtDir/web/courseleaf/index.tcf
	dump -1 tgtDir srcDir editFile
	checkStr='^navlinks.*refreshsystem'
	grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
	if [[ $grepStr != '' ]]; then
		if [[ $force == false ]]; then
			unset ans;
			Prompt 'ans' "Feature '$feature' is already installed, Do you wish to force install" "Yes,No" 'No'; ans="$(Lower ${ans:0:1})"
			[[ $ans != 'y' ]] && Goodbye 1
		else
			Note "Feature '$feature' is already installed, force option active, refreshing"
		fi
	fi

## Edit console file - insert refresh system if not there
	displayedHeading=false
	editFile="$tgtDir/web/courseleaf/index.tcf"
	name='Refresh System'
	changesMade=$(EditCourseleafConsole 'insert' "$editFile" "$name")
	[[ $changesMade == true ]] && Msg2 "Modified: $editFile" || Terminate 0 1 "Could not edit file '$file':\n\t$changesMade"

	name='Rebuild PageDB'
	changesMade=$(EditCourseleafConsole 'delete' "$editFile" "$name")
	[[ $changesMade == true ]] && Msg2 "Modified: $editFile" || Terminate 0 1 "Could not edit file '$file':\n\t$changesMade"

	if [[ $changesMade == true ]]; then
		Msg2 "Rebuilding console..."
		RunCoureleafCgi $tgtDir "-r /courseleaf/index.tcf"
		unset changeLogRecs
		changeLogRecs+=("Feature: $feature")
		myName=$parentScript
		WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"
		Msg2
		Pause "Feature '$currentScript': Installed, please press any key to continue"
	else
		Msg2
		Pause "Feature '$currentScript': No changes were made"
	fi

#==================================================================================================
## Done
#==================================================================================================
return  ## We are called as a subprocess, just return to our parent

#==================================================================================================
## Change Log
#==================================================================================================## Tue Mar  7 14:44:41 CST 2017 - dscudiero - Update description
