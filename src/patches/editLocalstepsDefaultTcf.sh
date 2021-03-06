#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#=======================================================================================================================
#= Description #========================================================================================================
# See 'scriptDescription' below
# Note: This script cannot be run standalone, it is meant to be sourced by the courseleafPatch script
# Note: This file is sourced by the courseleafPatch script, please be careful
#=======================================================================================================================
scriptDescription="Check/Edit /web/<progDir>/localsteps/default.tcf"

##	1) Remove uploadurl from the default.tcf file(requested by Ben 04/05/18)
if [[ $(CompareVersions "$(GetProductVersion 'cat' "$siteDir")" 'ge' '3.5.10') == true ]]; then
	editFile="$localstepsDir/default.tcf"
	if [[ -f "$editFile" ]]; then
		Msg; Msg "^$CPitemCntr) $scriptDescription..."
		changesMade=false
		fromStr='uploadurl:'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i "/^$fromStr/d" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			changesMade=false
		fi
		fromStr='cimuploadurl:'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i "/^$fromStr/d" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			changesMade=false
		fi
		[[ $changesMade != true ]] && Msg "^^No changes made"
		((CPitemCntr++))
	fi
fi

#=======================================================================================================================
## Check-in Log
#=======================================================================================================================
## 06-18-2018 @ 08:28:30 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-18-2018 @ 08:30:55 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-18-2018 @ 15:50:29 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
