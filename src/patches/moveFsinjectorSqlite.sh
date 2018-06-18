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
scriptDescription="Move fsinjector.sqlite to the ribbit folder"

## Requested by Mike 06/03/17
checkFile="$tgtDir/web/ribbit/fsinjector.sqlite"
if [[ ! -f $checkFile ]]; then
	Msg "^Checking /web/ribbit/fsinjector.sqlite..."
	[[ -f "$tgtDir/db/fsinjector.sqlite" ]] && mv -f "$tgtDir/db/fsinjector.sqlite" "$checkFile"
	editFile="$cfgFile"
	fromStr=$(ProtectedCall "grep '^db:fsinjector|sqlite|' $editFile")
	toStr='db:fsinjector|sqlite|/ribbit/fsinjector.sqlite'
	[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
	sed -i s"_^${fromStr}_${toStr}_" "$editFile"
	Msg "^^Updated '$editFile' to change changed the mapfile record for 'db:fsinjector' to point to the ribbit directory"
	((CPitemCntr++))
fi
