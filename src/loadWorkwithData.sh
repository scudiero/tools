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
	function loadAuthData-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}

	function loadAuthData-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function loadAuthData-Help  {
		helpSet='client,env' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0
		[[ -z $* ]] && return 0
		echo -e "This script can be used to refresh the tools 'auth' data shadow ($authShadowDir) from the database data."
		return 0
	}

	function loadAuthData-testMode  { # or testMode-local
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
declare -A userData scriptsData

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
GetDefaultsData -f $myName
ParseArgsStd $originalArgStr
Hello

if [[ $batchMode != true ]]; then
	unset ans; Prompt ans "You are asking to reload the tools 'Workwith', do you wish to continue" 'Yes No'; ans="${ans:0:1}"; ans="${ans,,[a-z]}"
	[[ $ans != 'y' ]] && Goodbye 3
fi

#============================================================================================================================================
# Main
#============================================================================================================================================
 ## Create the data dump for the workwith tool
 	Verbose 1 "^Building the 'WorkWith' client data file..."
 	unset client
	if [[ -z $client ]]; then
	 	[[ ! -d $(dirname "$workwithDataFile") ]] && mkdir -p "$(dirname "$workwithDataFile")"
	 	outFile="${workwithDataFile}.new"
	 	echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE CLIENTS/SITES TABLES IN THE DATA WAREHOUSE" > "$outFile"
		sqlStmt="select ignoreList from $scriptsTable where name=\"buildClientInfoTable\""
	 	RunSql $sqlStmt
	 	ignoreList="${resultSet[$i]}"; ignoreList=${ignoreList##*:}; ignoreList="'${ignoreList//,/','}'"
		sqlStmt="select name,longName,hosting,products,productsinsupport from $clientInfoTable where recordstatus=\"A\" and name not in ($ignoreList) order by name"
	 	RunSql $sqlStmt
		for rec in "${resultSet[@]}"; do clients+=("$rec"); done
	else
		clients=($client)
		outFile="/dev/stdout"
	fi

	for ((i=0; i<${#clients[@]}; i++)); do
		clientRec="${clients[$i]}"
		client=${clientRec%%|*}
		Verbose 1 "^^client: $client ($i of ${#clients[@]})"
		unset envList envListStr
		sqlStmt="select env,host,share,cims from $siteInfoTable where name in (\"$client\",\"$client-test\") and env not in ('preview','public')"
 		RunSql $sqlStmt
 		if [[ ${#resultSet[@]} -gt 0 ]]; then
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				envListStr="${resultSet[$ii]}"; 
				env=${envListStr%%|*}; envListStr="${envListStr#*|}"
				host=${envListStr%%|*}; envListStr="${envListStr#*|}"
				server=${envListStr%%|*}; envListStr="${envListStr#*|}"
				envListStr="${envListStr//\|/:}"
				envList="$envList;$env-$host/$server#$envListStr"
			done
 		fi
 		clientRec="$clientRec|${envList:1}"
		echo "${clientRec//NULL/}" >> "$outFile"
	done

	if [[ $outFile != '/dev/stdout' ]]; then
		[[ -f "$workwithDataFile" ]] && mv -f "$workwithDataFile" "${workwithDataFile}.bak"
		mv -f "$outFile" "$workwithDataFile"
	fi

	Verbose 1 "^...Done"


#============================================================================================================================================
## Done
#============================================================================================================================================
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
