#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="1.0.1" # -- dscudiero -- Fri 04/27/2018 @  9:11:39.39
#=======================================================================================================================
# Retrieve data from a Excel xlsx spreadsheet
#==================================================================================================================================
# Usage [options] 
# Options:
# 	-wb | --workbook <workbook file name> -- required
# 	-ws | --worksheet <worksheet name> or 'sheets' -- required
# 	-de  | --delimiter <Output cell delimiter char> -- optional, defaults to "|"
# 	-skip | --skipBlankLines skip over blank lines -- optional, defaults to false
# 	-da | --cellData <text> -- optional, if specified it implies write operation
# 	-c | --cellAddress <cell address in the format X,Y> -- optional, if not specified it assumes append as a full row to the current file
# 	-f | --cellFormat <format> -- optional, the format to apply to the cell
# 	-v  | -verboseLevel <level> -- optional, defaults to 0
# Returns data as standard out
#=======================================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
#=======================================================================================================================
function ExcelUtilities {
	#myIncludes="SetFileExpansion"
	#Import "$standardIncludes $myIncludes"

	# Run the excel request
		#SetFileExpansion 'off'
		unset resultSet
 		jar="$TOOLSPATH/jars/$excelUtils.jar"
 		[[ $useDev == true && -f $TOOLSDEVPATH/jars/$excelUtils.jar ]] && jar="$TOOLSDEVPATH/jars/$javaPgm.jar"
 		[[ $useLocal == true && -f $HOME/tools/jars/$excelUtils.jar ]] && jar="$HOME/tools/jars/$excelUtils.jar"
  		set +eE; readarray -t resultSet <<< "$(java -jar $jar $* 2>&1; rc=$?;)"; set -eE
		#SetFileExpansion

	## Check for errors
	##TODO this is a stupid way to do this
		errorStrings=('Exception in thread "main"')
		local i errorFound=false
		for ((i=0; i<${#resultSet[@]}; i++)); do
			[[ ${resultSet[$i]:0:13} == '*Fatal Error*' ]] && errorFound=true && break
		done		
		if [[ $errorFound == true ]]; then
			Error "$FUNCNAME: MS Excel operation failed:"
			for ((i=0; i<${#resultSet[@]}; i++)); do
				echo "     ${resultSet[$i]}"
			done
			echo
			Terminate "Processing cannot continue"
		fi

	return 0
} #GetExcel2
export -f ExcelUtilities

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## 04-26-2018 @ 14:10:24 - 1.0.0 - dscudiero - Turn on auto numbering
## 04-27-2018 @ 09:21:02 - 1.0.1 - dscudiero - Fix name
