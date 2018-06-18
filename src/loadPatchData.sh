#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
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
	function loadPatchData-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}

	function loadPatchData-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function loadPatchData-Help  {
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

	function loadPatchData-testMode  { # or testMode-local
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
# helpSet='client,env' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed
# scriptHelpDesc+=("This script can be used to ...")
# scriptHelpDesc+=("Line 2")
# scriptHelpDesc+=("^Line 3")
# scriptHelpDesc+=("\nTarget site data files potentially modified:")
# scriptHelpDesc+=("^As above")
# helpNotes+=('1) If the noPrompt flag is active then the local repo will always be refreshed from the')
# helpNotes+=('   master before the copy step.')
#

GetDefaultsData -f $myName
ParseArgsStd $originalArgStr
Hello

# Init "getClient getEnv getDirs checkEnvs getCims checkProdEnv"
#
## Set outfile -- look for std locations
# if [[ -d $localClientWorkFolder ]]; then
# 	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir $localClientWorkFolder/$client; fi
# 	outFile=$localClientWorkFolder/$client/$client-$env-CatalogPageData.xls
# else
# 	outFile=/home/$userName/$client-$env-CatalogPageData.xls
# fi
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
# [[ $warehouseDb != 'warehouseDev' ]] && mySqlConnectString="$(sed s"/warehouse/$warehouseDev/"g <<< $mySqlConnectString)"
# export warehouseDb='warehouseDev'
#============================================================================================================================================

#/usr/bin/tee fo.xml | /bin/nice /usr/local/fop-2.1/fop -a -c fop.xconf -fo - -pdf - 2>foperr<
#/usr/bin/tee fo.xml | /usr/local/fop/fop -a -c fop.xconf -fo - -pdf - 2>foperr<



skeletonRoot="${skeletonRoot}/release"
tgtDir='/mnt/dev6/web/wisc-dscudiero'

## Retrieve the fop version from skel and tgt
grepStr=$(ProtectedCall "grep '/usr/local/*/fop' $skeletonRoot/bin/fop")
skelFopVer=${grepStr##*/fop-}; skelFopVer=${skelFopVer%%/*}
grepStr=$(ProtectedCall "grep '/usr/local/*/fop' $tgtDir/bin/fop | grep -v ^[#] ")
tgtFopVer=${grepStr%%/fop *}; tgtFopVer=${tgtFopVer##*/}; tgtFopVer=${tgtFopVer#*-};

## If not the same then notify
[[ $tgtFopVer != $skelFopVer ]] && \
	Warning 0 1 "The fop version called in the /bin/fop file ($tgtFopVer) is not the same as the skeleton ($skelFopVer)\n\
	\tPlease contact Mark Jones"


#============================================================================================================================================
#============================================================================================================================================
## Done
#============================================================================================================================================
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
