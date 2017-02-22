#!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.11 # -- dscudiero -- 02/22/2017 @ 11:31:25.13
#==================================================================================================
#= Description +===================================================================================
# Make sites for the LUC conference
# Pass in 2 parameters
# 	[workbook file name] [workbook sheet name]
#
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription=""

#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-testsh  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-testsh  { # or Goodbye-local
	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
}
function testMode-testsh  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Terminate "You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================
Import 'GetExcel PadChar StringFunctions'

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
# trueVars=''
# falseVars=''
# for var in $trueVars; do eval $var=true; done
# for var in $falseVars; do eval $var=false; done
tmpFile=$(MkTmpFile)
passWord='luc2017'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName

[[ -n $1 ]] && workbookFile="$1"; shift||true
[[ -n $1 ]] && workbookSheet="$1"
Prompt workbookFile "Please specify the input file:" "*file*"

GetExcel "$workbookFile" 'GetSheets' > $tmpFile
sheets=$(tail -n 1 $tmpFile | tr '|' ' ')
Prompt workbookSheet "Please specify the worksheet:" "$(tr ' ' ',' <<< $sheets)"
dump -1 workbookFile workbookSheet

#===================================================================================================
# Main
#===================================================================================================
## Get the list of sheets in the workbook
GetExcel "$workbookFile" "$workbookSheet" > $tmpFile

## Loop through records and create the sites
SetFileExpansion 'off'
while read line; do
	[[ -z $line || $line == '||' ]] && continue
	[[ $(cut -d'|' -f1 <<< "$line") == '*' ]] && continue
	institution=$(cut -d'|' -f5 <<< "$line")
	line=$(Lower "$line")
	fName=$(cut -d'|' -f2 <<< "$line")
	lName=$(cut -d'|' -f3 <<< "$line")
	siteName="${fName}${lName}"
	userEmail=$(cut -d'|' -f4 <<< "$line")
	userId=${userEmail%%@*}
	dump -1 -t line -t fName lName siteName userId
	copyEnv --useLocal $passWord -nocheck -src p -tgt p -asSite $siteName -forUser $userId/$passWord -nop

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

