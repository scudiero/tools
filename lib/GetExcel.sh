#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="2.0.63" # -- dscudiero -- Wed 04/12/2017 @ 15:35:51.94
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
		local tmpFile=$(MkTmpFile $FUNCNAME)

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
## Thu Feb  9 08:06:19 CST 2017 - dscudiero - make sure we are using our own tmpFile
## 04-12-2017 @ 13.25.17 - ("2.0.62")  - dscudiero - x
## 04-12-2017 @ 15.36.02 - ("2.0.63")  - dscudiero - remove debug statements
