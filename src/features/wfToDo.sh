#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.0.91 # -- dscudiero -- Thu 03/22/2018 @ 14:21:24.32
#==================================================================================================
# NOTE: intended to be sourced from the courseleafFeature script, must run in the address space
# of the caller.  Expects values to be set for client, env, siteDir
#==================================================================================================
# Configure Custom emails on a Courseleaf site
#==================================================================================================
TrapSigs 'on'
myIncludes="ProtectedCall EditCourseleafConsole Pause WriteChangelogEntry RunCourseLeafCgi"
Import "$standardIncludes $myIncludes"

currentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[0]}))
parentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[1]}))
originalArgStr="$*"
TrapSigs 'on'

#==================================================================================================
# Data used by the parent with a setVarsOnly call
#==================================================================================================
eval "$(basename ${BASH_SOURCE[0]%%.*})scriptDescription='Install Workflow todo on the CourseLeaf console & specified CIMs'"

filesStr='/web/courseleaf/index.tcf;/web/<cims>/workflow.tcf'
eval "$(basename ${BASH_SOURCE[0]%%.*})potentialChangedFiles=\"$filesStr\""

actionsStr='1) Check to see if already installed'
actionsStr="$actionsStr;2) Check the console navlinks for 'Administration', if found update to 'Courseleaf'"
actionsStr="$actionsStr;3) Insert the 'To-Do List' action on the console"
actionsStr="$actionsStr;4) Update user selected CIM instances to add to the selectable step modifiers"
eval "$(basename ${BASH_SOURCE[0]%%.*})actions=\"$actionsStr\""

[[ $1 == 'setVarsOnly' ]] && return 0

#==================================================================================================
# functions
#==================================================================================================

#=========================Check=========================================================================
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
	dump -1 tgtDir srcDir

## Check to see if it is already there
	editFile=$tgtDir/web/courseleaf/index.tcf
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
	editFile=$tgtDir/web/courseleaf/index.tcf
	checkStr='^navlinks:Administration|'
	grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
	if [[ $grepStr != '' ]]; then
		Msg "Found 'Administration' sectionlinks and navlinks in the console definitions"
		unset ans; Prompt ans "Do you wish to update these to 'CourseLeaf'" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
		if [[ $ans == 'y' ]]; then
			sed -i s'/navlinks:Administration|/navlinks:CourseLeaf|/g' "$editFile"
			sed -i s'/^sectionlinks:Administration|/sectionlinks:CourseLeaf|/g' "$editFile"
		else
			Terminate "Sorry, cannot edit the CourseLeaf console definition file without updates above"
		fi
	fi

## Edit console file - insert To-Do List if not there
	displayedHeading=false
	editFile="$tgtDir/web/courseleaf/index.tcf"
	name='To-Do List'
	changesMade=$(EditCourseleafConsole 'insert' "$editFile" "$name")
	[[ $changesMade == true ]] && Msg "Modified: $editFile" || Terminate 0 1 "Could not edit file '$editFile':\n\t$changesMade"

## Add todo to CIMs
	echo
	allowMultiCims=true
	GetCims "$tgtDir"
	echo
	for cim in $(tr ',' ' ' <<< "$cimStr"); do
		Msg "Updateing CIM: '$cim'"
		editFile="$tgtDir/web/$cim/workflow.tcf"
		checkStr='^localsteps:'
		grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
		[[ $(Contains "$grepStr" 'todo[') == true ]] && Info 0 2 "To-Do already defined, skipping" && continue
		sed -i s'/];/],todo[To-Do Item];/' "$editFile"
	done

	if [[ $changesMade == true ]]; then
		Msg "Rebuilding console..."
		RunCourseLeafCgi $tgtDir "-r /courseleaf/index.tcf"
		unset changeLogRecs
		changeLogRecs+=("Feature: $feature")
		myName=$parentScript
		WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"
		Msg
		Pause "Feature '$currentScript': Installed, please press any key to continue"
	else
		Msg
		Pause "Feature '$currentScript': No changes were made"
	fi

#==================================================================================================
## Done
#==================================================================================================
return  ## We are called as a subprocess, just return to our parent

#==================================================================================================
## Change Log
#==================================================================================================
## Tue Mar 14 13:21:18 CDT 2017 - dscudiero - Check to make sure the user requests that the console definitions are updated to 'CourseLeaf'
## 04-06-2017 @ 10.10.14 - (1.0.62)    - dscudiero - renamed RunCourseLeafCgi, use new name
## 04-13-2017 @ 11.02.55 - (1.0.63)    - dscudiero - Fixed problem where we were only allowing the selection of a signel cim
## 09-22-2017 @ 07.50.27 - (1.0.90)    - dscudiero - Add to imports
## 03-22-2018 @ 14:36:22 - 1.0.91 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
