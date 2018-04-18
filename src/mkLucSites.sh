#!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.21 # -- dscudiero -- Tue 04/17/2018 @ 16:59:40.63
#==================================================================================================
#= Description +===================================================================================
# Make sites for the LUC conference
# Pass in 2 parameters
# 	[workbook file name] [workbook sheet name]
#
#==================================================================================================
TrapSigs 'on'
myIncludes="GetExcel PadChar StringFunctions"
Import "$standardInteractiveIncludes $myIncludes"

Import "$imports"
originalArgStr="$*"
scriptDescription=""

#==================================================================================================
# Standard call back functions
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
# trueVars=''
# falseVars=''
# for var in $trueVars; do eval $var=true; done
# for var in $falseVars; do eval $var=false; done
tmpFile=$(MkTmpFile)
passWord="luc$(date +"%Y")"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName

[[ -n $1 ]] && workbookFile="$1"; shift||true
[[ -n $1 ]] && workbookSheet="$1"
Prompt workbookFile "Please specify the input file:" "*file*"

GetExcel -wb "$workbookFile" -ws 'GetSheets' > $tmpFile
sheets=$(tail -n 1 $tmpFile | tr '|' ' ')
Prompt workbookSheet "Please specify the worksheet:" "$(tr ' ' ',' <<< $sheets)"
dump -1 workbookFile workbookSheet

#===================================================================================================
# Main
#===================================================================================================
## Get the list of sheets in the workbook
GetExcel -wb "$workbookFile" -ws "$workbookSheet"  > $tmpFile

##
## control|firstName|lastName|email|institution
## Loop through records and create the sites
SetFileExpansion 'off'
echo > $stdout
while read line; do
	[[ -z $line || $line == '||||' ]] && continue
	[[ $(cut -d'|' -f1 <<< "$line") == '*' ]] && continue
	institution=$(cut -d'|' -f5 <<< "$line")
	line=$(Lower "$line")
	fName=$(cut -d'|' -f2 <<< "$line")
	lName=$(cut -d'|' -f3 <<< "$line")
	userEmail=$(cut -d'|' -f4 <<< "$line")
	[[ -z $fName || -z $lName || -z $userEmail || -z $institution ]] && Error "Invalid record '$line', skipping" && continue
	siteName="${fName}${lName}"
	userId=${userEmail%%@*}
	dump -1 -t line -t fName lName siteName userId institution
	copyEnv --useDev $passWord -nocheck -src p -tgt p -asSite $siteName -forUser $userId/$passWord -nop

	echo | tee -a $stdout
	echo -e "$(TitleCase "$fName") $(TitleCase "$lName") \t--\t $institution" | tee -a $stdout
	echo | tee -a $stdout
	echo -e "Site URL.............https://$passWord-${siteName}.dev7.leepfrog.com" | tee -a $stdout
	echo -e "CourseLeaf Console...https://$passWord-${siteName}.dev7.leepfrog.com/courseleaf" | tee -a $stdout
	echo -e "CIM Courses..........https://$passWord-${siteName}.dev7.leepfrog.com/courseadmin" | tee -a $stdout
	echo | tee -a $stdout
	echo -e "Login UserId.........$userId" | tee -a $stdout
	echo -e "Login Password.......$passWord" | tee -a $stdout
	echo | tee -a $stdout
	echo  $(PadChar) | tee -a $stdout
	echo | tee -a $stdout


done < "$tmpFile"
SetFileExpansion

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================

## Thu Feb 23 13:03:18 CST 2017 - dscudiero - Add error checking on the input lines
## 03-23-2018 @ 11:42:51 - 1.0.19 - dscudiero - Updates for GetExcel/GetExcel
## 03-23-2018 @ 11:56:30 - 1.0.20 - dscudiero - Updated for GetExcel2/GetExcel
## 04-18-2018 @ 09:36:59 - 1.0.21 - dscudiero - Switched to use toolsDev
