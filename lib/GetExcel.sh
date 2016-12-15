#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
version="2.0.54" # -- dscudiero -- 12/08/2016 @ 11:00:19.98
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

		Call 'getXlsx' 'std' 'python:py' "$workBook" "$workSheet" "$delimiter" > $tmpFile 2>&1;
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
} #Call
export -f GetExcel

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
