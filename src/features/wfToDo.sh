#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.0.60 # -- dscudiero -- 03/14/2017 @ 13:05:43.76
#==================================================================================================
# NOTE: intended to be sourced from the courseleafFeature script, must run in the address space
# of the caller.  Expects values to be set for client, env, siteDir
#==================================================================================================
# Configure Custom emails on a Courseleaf site
#==================================================================================================
currentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[0]}))
parentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[1]}))
originalArgStr="$*"
scriptDescription="Install workflow 'todo' on the CourseLeaf console & specific cims"
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
minClVer='3.5.9'

#==================================================================================================
# Main
#==================================================================================================
## Check the cl version
	clverFile="$tgtDir/web/courseleaf/clver.txt"
	[[ ! -r "$clverFile" ]] && Terminate "Could not locate the clver.txt file in the target directory\n\t'$clverFile'"
	clVer=$(cat "$clverFile"); clVer=${clVer%% *}

	[[ $(CompareVersions "$clVer" 'ge' "$minClVer") == false ]] && \
		Terminate "Target site clver ($clVer) is less than the minimum required version for this feature ($minClVer)"

## set file to edit
	editFile=$tgtDir/web/courseleaf/index.tcf
	dump -1 tgtDir srcDir editFile

## Check to see if it is already there
	checkStr='^navlinks.*wftodo'
	grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
	if [[ -n $grepStr ]]; then
		if [[ $force == false ]]; then
			unset ans;
			Prompt 'ans' "Feature '$feature' is already installed, Do you wish to force install" 'Yes No' 'No'; ans="$(Lower ${ans:0:1})"
			[[ $ans != 'y' ]] && Goodbye 1
		else
			Note "Feature '$feature' is already installed, force option active, refreshing"
		fi
	fi

## Check to see if we need to update navlink names
	checkStr='^navlinks:Administration|'
	grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
	if [[ $grepStr != '' ]]; then
		Msg2 "Found 'Administration' sectionlinks and navlinks in the console definitions"
		unset ans; Prompt ans "Do you wish to update these to 'CourseLeaf'" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
		if [[ $ans == 'y' ]]; then
			sed -i s'/navlinks:Administration|/navlinks:CourseLeaf|/g' "$editFile"
			sed -i s'/^sectionlinks:Administration|/sectionlinks:CourseLeaf|/g' "$editFile"
		fi
	fi

## Edit console file - insert refresh system if not there
	displayedHeading=false
	editFile="$tgtDir/web/courseleaf/index.tcf"
	name='To-Do List'
	changesMade=$(EditCourseleafConsole 'insert' "$editFile" "$name")
	[[ $changesMade == true ]] && Msg2 "Modified: $editFile" || Terminate 0 1 "Could not edit file '$editFile':\n\t$changesMade"

## Add todo to CIMs
	echo
	GetCims "$tgtDir"
	echo
	for cim in $(tr ',' ' ' <<< "$cimStr"); do
		Msg2 "Updateing CIM: '$cim'"
		editFile="$tgtDir/web/$cim/workflow.tcf"
		checkStr='^localsteps:'
		grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
		[[ $(Contains "$grepStr" 'todo[') == true ]] && Info 0 2 "To-Do already defined, skipping" && continue
		sed -i s'/];/],todo[To-Do Item];/' "$editFile"
	done

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
#==================================================================================================
