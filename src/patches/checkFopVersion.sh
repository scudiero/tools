#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#= Description #========================================================================================================
# See 'scriptDescription' below
# Note: This script cannot be run standalone, it is meant to be sourced by the courseleafPatch script
# Note: This file is sourced by the courseleafPatch script, please be careful
#=======================================================================================================================
scriptDescription="Check fop versions"

## Retrieve the fop version from skel and tgt
grepStr=$(ProtectedCall "grep '/usr/local/*/fop' $skeletonRoot/bin/fop")
skelFopVer=${grepStr##*/fop-}; skelFopVer=${skelFopVer%%/*}
grepStr=$(ProtectedCall "grep '/usr/local/*/fop' $tgtDir/bin/fop | grep -v ^[#] ")
tgtFopVer=${grepStr%%/fop *}; tgtFopVer=${tgtFopVer##*/}; tgtFopVer=${tgtFopVer#*-};

## If not the same then notify
if [[ $tgtFopVer != $skelFopVer ]]; then
	Msg; Msg "^$CPitemCntr) $scriptDescription..."
	Warning 0 2 "The fop version called in the /bin/fop file ($tgtFopVer) is not the same as the skeleton ($skelFopVer)\n\
	\t\tPlease contact Mark Jones"
	((CPitemCntr++))
fi

#=======================================================================================================================
## Check-in Log
#=======================================================================================================================