#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#= Description #========================================================================================================
# See 'scriptDescription' below
# Note: This script cannot be run standalone, it is meant to be sourced by the courseleafPatch script
# Note: This file is sourced by the courseleafPatch script, please be careful
#=======================================================================================================================
scriptDescription="Rebuild console & approve pages"

## Rebuild console & approve pages
if [[ $rebuildConsole == true ]]; then
	Msg; Msg "^$CPitemCntr) $scriptDescription..."
	RunCourseLeafCgi "$tgtDir" "-r /$courseleafProgDir/index.html" | Indent | Indent
	RunCourseLeafCgi "$tgtDir" "-r /$courseleafProgDir/approve/index.html" | Indent | Indent
	((CPitemCntr++))
fi
## 06-18-2018 @ 08:28:37 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
