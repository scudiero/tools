#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.0.26" # -- dscudiero -- Fri 11/02/2018 @ 16:38:37
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

Main() {
	#=======================================================================================================================
	# Declare local variables and constants
	#=======================================================================================================================
	tmpFile=$(mkTmpFile)

	GetDefaultsData -f $myName
	ParseArgsStd $originalArgStr

	sqlStmt="select idx,name from $clientInfoTable order by idx"
	RunSql $sqlStmt
	clients=(${resultSet[*]})

	for ((j=0; j<${#clients[@]}; j++)); do
		clientData="${clients[$j]}"
		clientId="${clientData%%|*}"; clientData="${clientData#*|}"
		clientName="${clientData%%|*}"; clientData="${clientData#*|}"
		Verbose 1 1 "\n$clientName"
		## Cleanup current records
		sqlStmt="delete from $clientRolesTable where clientId=$clientId"
		RunSql $sqlStmt

		## Get the clientroles data from the transactional database
		sqlStmt="select clientKey,employeeKey,role from clientroles where clientKey=\"$clientId\""
		RunSql "$contactsSqliteFile" $sqlStmt
		clientRolesData=(${resultSet[*]})
		if [[ ${#clientRolesData[@]} -gt 0 ]]; then
			for ((i=0; i<${#clientRolesData[@]}; i++)); do
				result="${clientRolesData[$i]}"
				dump 2 result
				clientId="${result%%|*}"; result="${result#*|}"
				employeeKey="${result%%|*}"; result="${result#*|}"
				role="${result%%|*}"; result="${result#*|}"
				dump 2 -t clientId employeeKey role
				## Get employee info
				userid=NULL; firstName=NULL; lastName=NULL; email=NULL
				sqlStmt="select substr(email,1,instr(email,'@')-1),firstName,lastName,email from $employeeTable where employeeKey=\"$employeeKey\""
				RunSql $sqlStmt
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					result="${resultSet[0]}"
					dump 2 -t result
					userid="\"${result%%|*}\""; result="${result#*|}"
					firstName="\"${result%%|*}\""; result="${result#*|}"
					lastName="\"${result%%|*}\""; result="${result#*|}"
					email="\"${result%%|*}\""; result="${result#*|}"
					dump 2 -t2 clientId firstName lastName email
				fi
				## Create insert record
				values="$clientId,\"internal\",$employeeKey,NULL,\"$role\",$userid,$firstName,$lastName,$email,now()"
				Verbose 1 2 "$values"
				sqlStmt="insert into $clientRolesTable values($values)"
				RunSql $sqlStmt
			done ## clientRoles
		fi		
	done ## clients

return 0


} ## Main

	#=======================================================================================================================
	# Standard call back functions
	#=======================================================================================================================
	function loadClientRoles-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}

	function loadClientRoles-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function loadClientRoles-Help  {
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

	function loadClientRoles-testMode  { # or testMode-local
		return 0
	}



#============================================================================================================================================
Main "$@"
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
## 11-02-2018 @ 16:39:26 - 1.0.26 - dscudiero - Load the clientContactsRole table
