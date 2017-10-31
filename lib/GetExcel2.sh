#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="2.1.5" # -- dscudiero -- Tue 10/31/2017 @ 10:47:15.89
#=======================================================================================================================
# Retrieve data from a Excel xlsx spreadsheet
# Usage: GetExcel <workBook> <workSheet>
# Returns data as standard out
#=======================================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#=======================================================================================================================
function GetExcel2 {
	myIncludes="SetFileExpansion FindExecutable"
	Import "$standardIncludes $myIncludes"

	function GetExcelCleanup { SetFileExpansion 'on' ; rm -rf ${tmpFile}* >& /dev/null ; SetFileExpansion ; }
	function MyContains { local string="$1" ; local subStr="$2" ; [[ "${string#*$subStr}" != "$string" ]] && echo true || echo false ; return 0; }

	## Local defaults
		local workBook workSheet delimiter='|'
		local tmpFile=$(MkTmpFile $FUNCNAME)
		local verboseLevelSave=$verboseLevel;

	## Parse defaults
		while [[ $# -gt 0 ]]; do
		    [[ $1 =~ ^-wb|--workbook$ ]] && { workBook="$2"; shift 2; continue; }
		    [[ $1 =~ ^-ws|--workSheet$ ]] && { workSheet="$2"; shift 2; continue; }
		    [[ $1 =~ ^-d|--delimiter$ ]] && { delimiter="$2"; shift 2; continue; }
		    [[ -z $workBook ]] && { workBook="$1"; shift 1 || true; continue; }
		    workSheet="$workSheet $1"
		    shift 1 || true
		done
		[[ ${workSheet:0:1} == ' ' ]] && workSheet="${workSheet:1}"

	[[ -z $workBook || ! -f $workBook ]] && Terminate "$FUNCNAME: Could not locate workbook file '$workBook'"
	if [[ $(Contains "$workBook" ' ') == true ]]; then
		cp -fp "$workBook" "$tmpFile.workbook"
		workBook="$tmpFile.workbook"
	fi

	## Resolve the executable file"
	executeFile=$(FindExecutable '-python' 'getXlsx2')
	[[ -z $executeFile ]] && Terminate "$myName.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"

	## Call the 'real' program to parse the spreadsheet
		PYDIR="$TOOLSPATH/Python/linux/64/3.4.3.2"
		export PYDIR="$PYDIR"
		pathSave="$PATH"
		export PATH="$PYDIR:$PATH"
		verboseLevel=0
			cmdStr="$PYDIR/bin/python -u $executeFile -wb "$workBook" -ws "$workSheet""
		 	local resultStr="$($cmdStr)"
	 	verboseLevel=$verboseLevelSave
		export PATH="$pathSave"
		[[ -z $resultStr ]] && { GetExcelCleanup; Terminate "$FUNCNAME: Could not retrieve data for the '$workSheet' worksheet\n\tin the '$workBook' workbook."; }

	## Check for errors
		if [[ $(MyContains "resultStr" "*Fatal Error*") == true ]]; then
			GetExcelCleanup
			Terminate "$FUNCNAME: Could not retrieve data for the '$workSheet' worksheet\n\tin the '$workBook' workbook.\n\n$resultStr" }
		fi

	## Set output to an array
		unset resultSet
		#[[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<< "$resultStr"
		[[ $resultStr != '' ]] && readarray -t resultSet <<< "${resultStr}"

	GetExcelCleanup
	return 0
} #GetExcel2
export -f GetExcel2

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
## 05-18-2017 @ 12.35.13 - ("2.0.67")  - dscudiero - Remove the -vv from the call to getXlsx.py
## 09-20-2017 @ 12.09.52 - ("2.0.69")  - dscudiero - Add protectedcall to includes list
## 10-02-2017 @ 17.07.34 - ("2.1.0")   - dscudiero - Return a bad condition code if data retrieval fails
## 10-03-2017 @ 07.06.23 - ("2.1.0")   - dscudiero - REformat comments
## 10-03-2017 @ 13.50.36 - ("2.1.0")   - dscudiero - Added code to check to see if results were returned, if not terminate
## 10-03-2017 @ 13.52.12 - ("2.1.0")   - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 16.06.00 - ("2.1.0")   - dscudiero - Eliminated the use of a temporary file for data retrieval
## 10-04-2017 @ 13.09.39 - ("2.1.0")   - dscudiero - Regress the parsing for resultSet
## 10-05-2017 @ 12.08.27 - ("2.1.0")   - dscudiero - use getXlsx2 if it is there
## 10-05-2017 @ 12.12.30 - ("2.1.0")   - dscudiero - Cosmetic change or general syncing of dev to prod
## 10-05-2017 @ 12.25.38 - ("2.1.0")   - dscudiero - Cosmetic/minor change
## 10-05-2017 @ 12.26.43 - ("2.1.0")   - dscudiero - Cosmetic/minor change
## 10-12-2017 @ 14.25.59 - ("2.1.1")   - dscudiero - Use readarray to build the resultSet array
## 10-31-2017 @ 10.57.27 - ("2.1.5")   - dscudiero - Cleanup includes list
