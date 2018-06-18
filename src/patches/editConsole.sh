#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#= Description #========================================================================================================
# See 'scriptDescription' below
# Note: This script cannot be run standalone, it is meant to be sourced by the courseleafPatch script
# Note: This file is sourced by the courseleafPatch script, please be careful
#=======================================================================================================================
scriptDescription="Check/Edit the console page"

## Edit the console page
##	1) change title to 'CourseLeaf Console' (requested by Mike 02/09/17)
## 	2) remove 'System Refresh' (requested by Mike Miller 09/13/17)
## 	3) remove 'localsteps:links|links|links' (requested by Mike Miller 09/13/17)
## 	4) Add 'navlinks:CAT|Rebuild Course Bubbles and Search Results'
editFile="$tgtDir/web/$courseleafProgDir/index.tcf"
if [[ -w "$editFile" ]]; then
	Msg; Msg "^$CPitemCntr) $scriptDescription..."
	changesMade=false
	fromStr='title:Catalog Console'
	toStr='title:CourseLeaf Console'
	grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
	if [[ -n $grepStr ]]; then
		backupFile "$editFile" "$backupRootDir"
		sed -i s"!^$fromStr!$toStr!" $editFile
		[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
		updateFile="/$courseleafProgDir/index.tcf"
		changeLogRecs+=("$updateFile updated to change title")
		Msg "^^Updated '$updateFile' to change 'title:Catalog Console' to 'title:CourseLeaf Console'"
		rebuildConsole=true
		changesMade=true
	fi

	fromStr='navlinks:CAT|Refresh System|refreshsystem'
	toStr='// navlinks:CAT|Refresh System|refreshsystem'
	grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
	if [[ -n $grepStr ]]; then
		backupFile "$editFile" "$backupRootDir"
		sed -i s"!^$fromStr!$toStr!" $editFile
		[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
		updateFile="/$courseleafProgDir/index.tcf"
		changeLogRecs+=("$updateFile updated to change title")
		Msg "^^Updated '$updateFile' to remove 'Refresh System'"
		rebuildConsole=true
		changesMade=true
	fi

	fromStr='localsteps:links|links|links'
	toStr='// localsteps:links|links|links'
	grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
	if [[ -n $grepStr ]]; then
		backupFile "$editFile" "$backupRootDir"
		sed -i s"!^$fromStr!$toStr!" $editFile
		[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
		updateFile="/$courseleafProgDir/index.tcf"
		changeLogRecs+=("$updateFile updated to change title")
		Msg "^^Updated '$updateFile' to remove 'localsteps:links|links|links"
		rebuildConsole=true
		changesMade=true
	fi

	#navlinks:CAT|Rebuild Course Bubbles and Search Results|mkfscourses^^<h4>Rebuild Course Bubbles and Search Results</h4>Rebuild the course description pop-up bubbles, and also search results.^steptitle=Rebuilding Course Bubbles and Search Results
	fromStr='localsteps:links|links|links'
	toStr='// localsteps:links|links|links'
	grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
	if [[ -n $grepStr ]]; then
		backupFile "$editFile" "$backupRootDir"
		sed -i s"!^$fromStr!$toStr!" $editFile
		[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
		updateFile="/$courseleafProgDir/index.tcf"
		changeLogRecs+=("$updateFile updated to change title")
		Msg "^^Updated '$updateFile' to remove 'localsteps:links|links|links"
		rebuildConsole=true
		changesMade=true
	fi
	[[ $changesMade != true ]] && Msg "^^No changes made"
	((CPitemCntr++))
else
	Msg
	Warning 0 2 "Could not locate '$editFile', please check the target site"
fi

#=======================================================================================================================
## Check-in Log
#=======================================================================================================================
## 06-18-2018 @ 08:28:27 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-18-2018 @ 08:30:52 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-18-2018 @ 15:50:24 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
