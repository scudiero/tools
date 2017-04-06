#!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.36 # -- dscudiero -- Thu 04/06/2017 @ 10:08:40.20
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports SelectMenuNew RunCourseLeafCgi"
Import "$imports"
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
#
#
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-clientMoved  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-clientMoved  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-clientMoved  { # or testMode-local
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done


declare -A roleMap
roleMap['support']='support'
roleMap['sales']='salesRep'
roleMap['implementation']='csmRep'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client'
scriptHelpDesc="This script can be used to modify the warehouse data when a client is moved to a new server"

GetDefaultsData $myName
ParseArgsStd
Hello
Init "getClient"

unset origHost origDevShare origProdShare
## Get current information
	sqlStmt="select distinct host,share from $siteInfoTable where name=\"$client\" and env=\"next\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		origHost=$(cut -d'|' -f1 <<< ${resultSet[0]})
		origProdShare=$(cut -d'|' -f2 <<< ${resultSet[0]})
	fi
	sqlStmt="select distinct share from $siteInfoTable where name=\"$client\" and env=\"dev\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		origDevShare=$(cut -d'|' -f2 <<< ${resultSet[0]})
	fi

## New host name
	if [[ $(grep -o ',' <<< "$linuxHosts" | wc -l) -gt 1 ]]; then
		menuList=("|New Host")
		for token in $(tr ',' ' ' <<< $linuxHosts); do
			[[ $origHost != '' && $origHost == $token ]] && continue
			menuList+=("|${token}")
		done
		Msg2; Msg2 "Please specify the ordinal number of the new linux host."
		Note "If the client's new host is not listed here then the site's data has already been updated."
		SelectMenuNew 'menuList' 'newHost' '\nHost ordinal (or 'x' to quit) > '
		[[ $newHost == '' ]] && Goodbye 'quickquit' || newHost=$(cut -d'|' -f1 <<< $newHost)
	else
		newHost=$linuxHosts
	fi

## New Production Server
	sqlStmt="Select value from defaults where name=\"prodServers\" and host=\"$newHost\""
	RunSql2 $sqlStmt
	defaultProdShares=${resultSet[0]}
	if [[ $(grep -o ',' <<< "$defaultProdShares" | wc -l) -gt 1 ]]; then
		menuList=("|New Prod Server")
		for token in $(tr ',' ' ' <<< $defaultProdShares); do
			[[ $origProdShare != '' && $origProdShare == $token ]] && continue
			menuList+=("|${token}")
		done
		Msg2; Msg2 "Please specify the ordinal number of the new production server:"
		SelectMenuNew 'menuList' 'newProdShare' '\nServerHost ordinal (or 'x' to quit) > '
		[[ $newProdShare == '' ]] && Goodbye 'quickquit' || newProdShare=$(cut -d'|' -f1 <<< $newProdShare)
	else
		newProdShare=$defaultProdShares
	fi

## New Dev Server
	sqlStmt="Select value from defaults where name=\"devServers\" and host=\"$newHost\""
	RunSql2 $sqlStmt
	defaultDevShares=${resultSet[0]}
	if [[ $(grep -o ',' <<< "$defaultDevShares" | wc -l) -gt 1 ]]; then
		menuList=("|New Dev Server")
		for token in $(tr ',' ' ' <<< $defaultDevShares); do
			[[ $origDevShare != '' && $origDevShare == $token ]] && continue
			menuList+=("|${token}")
		done
		Msg2; Msg2 "Please specify the ordinal number of the new production server:"
		SelectMenuNew 'menuList' 'newDevShare' '\nServerHost ordinal (or 'x' to quit) > '
		[[ $newDevShare == '' ]] && Goodbye 'quickquit' || newDevShare=$(cut -d'|' -f1 <<< $newDevShare)
	else
		newDevShare=$defaultDevShares
	fi

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("New Host:$newHost")
verifyArgs+=("New Dev Share:$newDevShare")
verifyArgs+=("New Prod Share:$newProdShare")
VerifyContinue "You are asking to update the warehouse data for"

myData="Client: '$client', New Host: '$newHost', New Dev Share: '$newDevShare', New ProdShare: '$newProdShare' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================

sqlStmt="Update $siteInfoTable set host=\"$newHost\" where name=\"$client\""
RunSql2 $sqlStmt

sqlStmt="Update $siteInfoTable set share=\"$newDevShare\" where name=\"$client\" and env=\"dev\""
RunSql2 $sqlStmt

sqlStmt="Update $siteInfoTable set share=\"$newProdShare\" where name=\"${client}\" and env not in (\"dev\",\"preview\",\"public\")"
RunSql2 $sqlStmt

sqlStmt="Update $siteInfoTable set host=\"$newHost\" where name=\"${client}-test\" and env=\"test\""
RunSql2 $sqlStmt
sqlStmt="Update $siteInfoTable set share=\"$newProdShare\" where name=\"${client}-test\" and env=\"test\""
RunSql2 $sqlStmt

Msg2 "Data Warehouse data updated to reflect the clients new location"

lfinternal=$(ProtectedCall "grep lfinternal /etc/group")
if [[ $lfinternal != '' ]]; then
	if [[ $(Contains "$lfinternal" "$userName") == true ]]; then
		RunCourseLeafCgi "$stageInternal" "-r /clients/$client"
		Msg2 "Internal client page republished to reflect change"
		RunCourseLeafCgi "$stageInternal" "-r /support/tools/quicklinks"
		Msg2 "Internal quicklinks page republished to reflect change"
	else
		Msg2 $W "Your account does not have access to the internal site file system, skipping client page republishing, please go to the client page on the internal site and republish the client page."
	fi
else
	Msg2 $W "The 'lfinternal' group was not defined in '/etc/group', skipping client page republishing, please go to the client page on the internal site and republish the client page."
fi

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================## Tue Sep  6 16:08:57 CDT 2016 - dscudiero - Update the data wharehouse when a client is moved to a new server.
## Fri Sep  9 09:23:34 CDT 2016 - dscudiero - Fix sqlStmt
## Mon Sep 12 09:10:47 CDT 2016 - dscudiero - Fix sqlStmt
## Wed Sep 14 08:46:22 CDT 2016 - dscudiero - Added seperate call to update test env records
## Mon Sep 26 09:11:26 CDT 2016 - dscudiero - Refactored data gathering as selection listes
## Wed Sep 28 09:52:35 CDT 2016 - dscudiero - Added step to rebuild the client page
## Wed Sep 28 09:55:03 CDT 2016 - dscudiero - Added step to rebuild the quicklinks page
## Tue Oct  4 09:10:15 CDT 2016 - dscudiero - Fix problem rebuilding quickinks page
## Tue Oct  4 09:20:02 CDT 2016 - dscudiero - Update host for test sites
## Tue Oct  4 12:19:42 CDT 2016 - dscudiero - Edit out current host and share from the selection listes
## Wed Oct  5 09:46:17 CDT 2016 - dscudiero - Check to see if the user has access to the internal site befor rebuilding the client pages
## Mon Oct 17 08:48:30 CDT 2016 - dscudiero - Removed extra set of calls to rebuild pages
## 04-06-2017 @ 10.09.28 - (1.0.36)    - dscudiero - renamed RunCourseLeafCgi, use new name
