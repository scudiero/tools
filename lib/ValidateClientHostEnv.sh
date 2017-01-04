## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.4" # -- dscudiero -- 01/04/2017 @ 13:51:03.34
#===================================================================================================
# verify that client / host / env combo valid
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ValidateClientHostEnv {
	client=$1
	env=$2
	sqlStmt="select idx from $clientInfoTable where name=\"$client\" "
	RunSql 'mysql' $sqlStmt
	clientId=${resultSet[0]}

	if [[ "$clientId" = "" ]]; then
		printf "Client value of '$client' not found in leepfrog.$clientInfoTable"
		return 0
	fi
	sqlStmt="select siteId from $siteInfoTable where clientId=\"$clientId\" and host=\"$hostName\" "
	RunSql 'mysql' $sqlStmt
	siteId=${resultSet[0]}
	if [[ "$siteId" = "" ]]; then
		printf "Client value of '$client' not valid on host '$hostName'"
		return 0
	fi
	if [[ "$env" != "" ]]; then
		sqlStmt="select siteId from $siteInfoTable where clientId=\"$clientId\" and env=\"$env\" "
		RunSql 'mysql' $sqlStmt
		siteId=${resultSet[0]}
		if [[ "$siteId" = "" ]]; then
			printf "Environment value of '$env' not valid for client '$client'"
			return 0
		fi
	fi

	return 0
} #ValidateClientHostEnv
export -f ValidateClientHostEnv

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:37 CST 2017 - dscudiero - General syncing of dev to prod
