#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.0.45 # -- dscudiero -- Fri 09/22/2017 @  7:44:21.39
#==================================================================================================
# NOTE: intended to be sourced from the courseleafFeature script, must run in the address space
# of the caller.  Expects values to be set for client, env, siteDir
#==================================================================================================
# Configure Custom emails on a Courseleaf site
#==================================================================================================
TrapSigs 'on'
myIncludes="SetFileExpansion ProtectedCall Pause WriteChangelogEntry GetCourseleafPgm CopyFileWithCheck EditTcfValue"
Import "$standardIncludes $myIncludes"

currentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[0]}))
parentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[1]}))
originalArgStr="$*"

#==================================================================================================
# Data used by the parent with a setVarsOnly call
#==================================================================================================
eval "$(basename ${BASH_SOURCE[0]%%.*})scriptDescription='Install Custom Workflow emails (wfemail)'"

filesStr='/email/sendnow.atj;/web/admin/wfemail;/web/<courseleafDir>/localsteps/default.tcf;/web/<courseleafDir>/index.tcf'
eval "$(basename ${BASH_SOURCE[0]%%.*})potentialChangedFiles=\"$filesStr\""

actionsStr='1) Check to see if already installed'
actionsStr="$actionsStr;2) Copy email '/email/sendnow.atj' and '/web/admin/wfemail' from the skeleton shadow"
actionsStr="$actionsStr;3) Add 'wfemail_prefix:custom' to localsteps/default.tcf"
actionsStr="$actionsStr;4) Insert the 'Workflow Email' action on the console"
eval "$(basename ${BASH_SOURCE[0]%%.*})actions=\"$actionsStr\""

[[ $1 == 'setVarsOnly' ]] && return 0

#==================================================================================================
# functions
#==================================================================================================

#==================================================================================================
# Declare variables and constants
#==================================================================================================
tgtDir=$siteDir
srcDir=$skeletonRoot/release
feature=$currentScript

#==================================================================================================
# Main
#==================================================================================================
## Get the Courseleaf directory
	courseleafDir=$(GetCourseleafPgm "$tgtDir" | cut -d' ' -f1)

## Check to see if it is already there
	local editFile="$tgtDir/web/$courseleafDir/index.tcf"
	dump -1 tgtDir srcDir editFile
	checkStr='|Workflow Emails|wfemail_messages'
	local grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
	if [[ $grepStr != '' ]]; then
		if [[ $force == false ]]; then
			unset ans;
			Prompt 'ans' "Feature '$feature' is already installed, Do you wish to force install" "Yes,No" 'No'; ans="$(Lower ${ans:0:1})"
			[[ $ans != 'y' ]] && Goodbye 'quiet'
		else
			Info "Feature '$feature' is already installed, force option active, refreshing"
		fi
	fi

## Copy files
	local fileSpecs="/email/sendnow.atj /web/admin/wfemail"
	for fileSpec in $fileSpecs; do
		if [[ -f ${srcDir}${fileSpec} ]]; then
			cpOut=$(CopyFileWithCheck ${srcDir}${fileSpec} ${tgtDir}${fileSpec} 'backup')
			if [[ $cpOut == true ]]; then
				Msg2 "^Copied file: $fileSpec" && changesMade=true
			elif [[ $cpOut != '' ]]; then
				Msg2 "^File: $fileSpec not copied, files are identical" && changesMade=true
			else
				Terminate 0 1 "Could not copy file '$fileSpec':\n^$cpOut"
			fi
		elif [[ -d ${srcDir}${fileSpec} ]]; then
			cwd=$(pwd)
			cd ${srcDir}${fileSpec}
			SetFileExpansion 'on'
			dirFiles=($(find *))
			SetFileExpansion
			for dirFile in ${dirFiles[@]}; do
				cpOut=$(CopyFileWithCheck $srcDir/$fileSpec/$dirFile $tgtDir/$fileSpec/$dirFile 'backup')
				if [[ $cpOut == true ]]; then
					Msg2 "^Copied file: $fileSpec/$dirFile" && changesMade=true
				elif [[ $cpOut != '' ]]; then
					Msg2 "^File: $fileSpec/$dirFile not copied, files are identical" && changesMade=true
				else
					Terminate 0 1 "Could not copy file '$fileSpec/$dirFile':\n^$cpOut"
				fi
			done
			cd $cwd
		else
			Terminate 0 1 "FileSpec (${srcDir}${fileSpec}) is not a file nor a directory, cannot process"
		fi
	done

## Edit localsteps/default.tcf, wfemail_prefix:custom
	varName='wfemail_prefix'
	varValue='custom'
	editFile="$tgtDir/web/$courseleafDir/localsteps/default.tcf"
	editMsg=$(EditTcfValue "$varName" "$varValue" "$editFile")
	[[ $editMsg != true ]] && Terminate "Error editing file:\n^^'$editFile'\n^Editing tcf variable\n^^variable:'$varName'\n^^value: '$varValue'\n^Edit message:\n^^$editMsg"

## Edit console file - insert workflow emails if not there
	editFile="$tgtDir/web/$courseleafDir/index.tcf"
	name='Workflow Emails'
	changesMade=$(EditCourseleafConsole 'insert' "$editFile" "$name")
	[[ $changesMade == true ]] && Msg2 "Modified: '$editFile'" || Terminate "Could not edit file '$file':\n\t$changesMade"

## If changes made then rebuild the console page and log
	if [[ $changesMade == true ]]; then
		Msg2 "Rebuilding console..."
		RunCourseLeafCgi $tgtDir "-r /$courseleafDir/index.tcf"
		Msg2
		Note "You need to go and edit the control file '$tgtDir/admin/wfemail.tcf' to ensure that all the emails you wish to activate are defined."
		unset changeLogRecs
		changeLogRecs+=("Feature: $feature")
		WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt" "$parentScript"
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
#==================================================================================================## 04-06-2017 @ 10.10.05 - (1.0.34)    - dscudiero - renamed RunCourseLeafCgi, use new name
## 09-22-2017 @ 07.50.19 - (1.0.45)    - dscudiero - Add to imports
