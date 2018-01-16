#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
version=4.3.122 # -- dscudiero -- Fri 01/12/2018 @ 15:39:14.50
#=======================================================================================================================
TrapSigs 'on'
myIncludes="SetSiteDirs SetFileExpansion RunSql2 StringFunctions ProtectedCall FindExecutable PushPop"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Sync the data warehouse '$siteInfoTable' table with the transactional data from the contacts db data and the live site data"

#=======================================================================================================================
# Run nightly from cron
# 	Script to update site_info database with all sites and their versions
#=======================================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 08-30-13 -- 	dgs - Initial coding
# 05-06-14	--	dgs	-Deal with old cims that are in '/cim/' not 'xxxxadmin' (see UA)
# 05-20-14	--	dgs	-Added test env and added site url
# 07-08-15 --	dgs -Do not write a record if a client record was not found
# 07-17-15 --	dgs - Migrated to framework 5
#=======================================================================================================================

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
	function buildWorkWithDataFile-ParseArgsStd2 {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		quick=false
		myArgs+=("quick|quick|switch|quick||script|Do quickly, skip processing the admins information")
		myArgs+=("table|tableName|option|tableName||script|The name of the database table to load")
	}
	function buildWorkWithDataFile-Goodbye  { # or Goodbye-$myName
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
insertInLine=false
fork=false
addedCalledScriptArgs="-secondaryMessagesOnly"

## Find the location of the worker script, speeds up subsequent calls
	workerScript='insertSiteInfoTableRecord'
	workerScriptFile="$(FindExecutable "$workerScript")"
	[[ -z $workerScriptFile ]] && Terminate "Could find the workerScriptFile file ('$workerScript')"

forkCntr=0; siteCntr=0; clientCntr=0;
[[ $testMode == true ]] && export warehousedb="$warehouseDev"

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
Hello
Info "Loading script defaults..."
GetDefaultsData $myName
Info "Parsing arguments..."
ParseArgsStd2 $originalArgStr
if [[ $batchMode != true ]]; then
	verifyMsg="You are asking to re-generate the data warehouse 'WorkWith' client data file"
	VerifyContinue "$verifyMsg"
fi

#=======================================================================================================================
# Main
#=======================================================================================================================

Msg3 "^Building the 'WorkWith' client data file..."
unset client
if [[ -z $client ]]; then
 	[[ ! -d $(dirname "$workwithDataFile") ]] && mkdir -p "$(dirname "$workwithDataFile")"
 	outFile="${workwithDataFile}.new"
 	echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE CLIENTS/SITES TABLES IN THE DATA WAREHOUSE" > "$outFile"
	sqlStmt="select ignoreList from $scriptsTable where name=\"buildClientInfoTable\""
 	RunSql2 $sqlStmt
 	ignoreList="${resultSet[$i]}"; ignoreList=${ignoreList##*:}; ignoreList="'${ignoreList//,/','}'"
	sqlStmt="select name,longName,hosting,products from $clientInfoTable where recordstatus=\"A\" and name not in ($ignoreList) order by name"
 	RunSql2 $sqlStmt
	for rec in "${resultSet[@]}"; do clients+=("$rec"); done
else
	clients=($client)
	outFile="/dev/stdout"
fi

for ((i=0; i<${#clients[@]}; i++)); do
	clientRec="${clients[$i]}"
	client=${clientRec%%|*}
	Verbose 1 "^client: $client ($i of ${#clients[@]})"
	unset envList envListStr
	sqlStmt="select env,host,share,cims from $siteInfoTable where name in (\"$client\",\"$client-test\") and env not in ('preview','public')"
		RunSql2 $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				envListStr="${resultSet[$ii]}"; 
				env=${envListStr%%|*}; envListStr="${envListStr#*|}"
				host=${envListStr%%|*}; envListStr="${envListStr#*|}"
				server=${envListStr%%|*}; envListStr="${envListStr#*|}"
				envListStr="${envListStr//\|/:}"
				envList="$envList;$env-$host/${server}#${envListStr}"
			done
	fi
		clientRec="$clientRec|${envList:1}"
	echo "$clientRec" >> "$outFile"
done

if [[ $outFile != '/dev/stdout' ]]; then
	[[ -f "$workwithDataFile" ]] && mv -f "$workwithDataFile" "${workwithDataFile}.bak"
	mv -f "$outFile" "$workwithDataFile"
fi

Msg3 "^...Done"

#=======================================================================================================================
## Bye-bye
#=======================================================================================================================
Goodbye 0 'alert'

