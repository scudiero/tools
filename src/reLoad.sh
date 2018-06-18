#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.0 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#=======================================================================================================================
#= Description #========================================================================================================
#
#
#=======================================================================================================================
TrapSigs 'on'
myIncludes="Msg ProtectedCall StringFunctions RunSql"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
	function reLoad-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}

	function reLoad-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function reLoad-Help  {
		helpSet='client,env' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0

		[[ -z $* ]] && return 0
		echo -e "This script can be used to copy workflow related files from one environment to another."
		echo -e "\nThe actions performed are:"
		bullet=1; echo -e "\t$bullet) Action 1"
		(( bullet++ )); echo -e "\t$bullet) Action 2"
		echo -e "\nTarget site data files potentially modified:"
		echo -e "\tfile 1"
		echo -e "\tfile 2"
# or
# 		if [[ -n "$someArrayVariable" ]]; then
# 			for file in $(tr ',' ' ' <<< $someArrayVariable); do echo -e "\t\t- $file"; done
# 		fi
		return 0
	}

	function reLoad-testMode  { # or testMode-local
		return 0
	}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
GetDefaultsData -f $myName
ParseArgsStd $originalArgStr
Hello

unset type; Prompt type "What type of data do you wish to reload" 'Defaults Auth Workwith'; type=${type:0:1}; type="${type,,[a-z]}"

case $type in
	d) 	
		Here 1
		;;
	a)
		Here 2
		;;
	w)
		Here 3
		;;
esac



# unset verifyArgs
# verifyArgs+=("Client:$client")
# verifyArgs+=("Env:$(TitleCase $env)")
# verifyArgs+=("CIMs:$cimStr")
# verifyArgs+=("Output File:$outFile")
# verifyContinueDefault='Yes'
# VerifyContinue "You are asking to generate a workflow spreadsheet for"
#
# myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
# [[ $logInDb != false && $myLogRecordIdx != "" ]] && ProcessLogger 'Update' $myLogRecordIdx 'data' "$myData"

#============================================================================================================================================
# Main
#============================================================================================================================================


#============================================================================================================================================
#============================================================================================================================================
## Done
#============================================================================================================================================
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
