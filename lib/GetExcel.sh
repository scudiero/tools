#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="2.0.66" # -- dscudiero -- Thu 05/18/2017 @ 12:12:29.26
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
		function GetExcelCleanup { SetFileExpansion 'on' ; rm -rf ${tmpFile}* >& /dev/null ; SetFileExpansion ; }

		[[ ! -f $workBook ]] && Terminate "$FUNCNAME: Could not locate workbook file '$workBook'"
		if [[ $(Contains "$workBook" ' ') == true ]]; then
			cp -fp "$workBook" "$tmpFile.workbook"
			workBook="$tmpFile.workbook"
		fi

		verboseLevelSave=$verboseLevel ; verboseLevel=0
		Call 'getXlsx' 'utility' 'std' 'python:py' "$workBook" "$workSheet" "$delimiter" -vv > $tmpFile 2>&1;
		verboseLevel=$verboseLevelSave
		local grepStr=$(ProtectedCall "grep '*Fatal Error*' $tmpFile")
		[[ $grepStr == '' ]] && grepStr=$(ProtectedCall "grep '*Error*' $tmpFile")
		if [[ $grepStr != '' || $(tail -n 1 $tmpFile) == '-1' ]]; then
			Msg2 $E "Could not retrieve data from workbook, please see below"
			tail -n 10 $tmpFile > $tmpFile.2
			while read -r line; do echo -e "\t$line"; done < $tmpFile.2;
			GetExcelCleanup
			Msg2
			Goodbye -1
		fi
		cat $tmpFile
		GetExcelCleanup

	return 0
} #GetExcel

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## Tue Jan  3 11:57:15 CST 2017 - dscudiero - Add 'utility' to call of getXlsx
## Wed Jan  4 13:53:35 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan 18 13:37:05 CST 2017 - dscudiero - misc cleanup
## Thu Feb  9 08:06:19 CST 2017 - dscudiero - make sure we are using our own tmpFile
## 04-12-2017 @ 13.25.17 - ("2.0.62")  - dscudiero - x
## 04-12-2017 @ 15.36.02 - ("2.0.63")  - dscudiero - remove debug statements
## 05-17-2017 @ 12.26.49 - ("2.0.64")  - dscudiero - Turn off messages when running the python procedure
## 05-18-2017 @ 12.13.01 - ("2.0.66")  - dscudiero - General syncing of dev to prod
