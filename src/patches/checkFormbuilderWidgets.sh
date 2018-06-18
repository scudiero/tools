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
scriptDescription="Check to see if there are any old formbuilder widgets"

if [[ $client != 'internal' && -n $locallibsDir && -d "$locallibsDir/locallibs" ]]; then
	Msg "^$CPitemCntr) $scriptDescription..."
	checkDir="$locallibsDir/locallibs/widgets"
	fileCount=$(ls "$checkDir" 2> /dev/null | grep 'banner_' | wc -l)
	[[ $fileCount -gt 0 ]] && Warning 0 1 "Found 'banner' widgets in '$checkDir', these are probably deprecated, please ask a CIM developer to evaluate."
	fileCount=$(ls "$checkDir" 2> /dev/null | grep 'psoft_' | wc -l)
	[[ $fileCount -gt 0 ]] && Warning 0 1 "Found 'psoft' widgets in '$checkDir', these are probably deprecated, please ask a CIM developer to evaluate."
	((CPitemCntr++))
fi
