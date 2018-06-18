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
scriptDescription="Edit /web/<progDir>/localsteps/default.tcf"

##	1) Remove uploadurl from the default.tcf file(requested by Ben 04/05/18)
if [[ $(CompareVersions "$(GetProductVersion 'cat' "$siteDir")" 'ge' '3.5.10') == true ]]; then
	Msg "^$CPitemCntr) $scriptDescription..."
	editFile="$localstepsDir/default.tcf"
	if [[ -f "$editFile" ]]; then
		fromStr='uploadurl:'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i "/^$fromStr/d" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
		fi
		fromStr='cimuploadurl:'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i "/^$fromStr/d" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
		fi
	fi
	((CPitemCntr++))
fi
