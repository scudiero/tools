#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="2.0.60" # -- dscudiero -- 01/18/2017 @ 13:36:50.58
#=======================================================================================================================
# Retrieve data from a Excel xlsx spreadsheet
# Usage: GetExcel <workBook> <workSheet>
# Returns data as standard out
#=======================================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#=======================================================================================================================
function GetExcel {
		local workBook="$1"; shift
		local workSheet="$1"; shift
		local delimiter=${1-|}
		local tmpFile=$(mkTmpFile)

		Call 'getXlsx' 'utility' 'std' 'python:py' "$workBook" "$workSheet" "$delimiter" > $tmpFile 2>&1;

		local grepStr=$(ProtectedCall "grep '*Fatal Error*' $tmpFile")
		[[ $grepStr == '' ]] && grepStr=$(ProtectedCall "grep '*Error*' $tmpFile")
		if [[ $grepStr != '' || $(tail -n 1 $tmpFile) == '-1' ]]; then
			Msg2 $E "Could not retrieve data from workbook, please see below"
			tail -n 10 $tmpFile > $tmpFile.2
			while read -r line; do echo -e "\t$line"; done < $tmpFile.2;
			[[ -f $tmpFile.2 ]] && rm -f $tmpFile.2
			[[ -f $tmpFile ]] && rm -f $tmpFile
			Msg2
			Goodbye -1
		fi
		cat $tmpFile

		[[ -f $tmpFile.2 ]] && rm -f $tmpFile.2
		[[ -f $tmpFile ]] && rm -f $tmpFile

	return 0
} #GetExcel
export -f GetExcel

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## Tue Jan  3 11:57:15 CST 2017 - dscudiero - Add 'utility' to call of getXlsx
## Wed Jan  4 13:53:35 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan 18 13:37:05 CST 2017 - dscudiero - misc cleanup
