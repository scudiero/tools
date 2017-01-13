## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/12/2017 @ 12:53:06.73
#===================================================================================================
# Display a selection list of clients, returns data in the client global variable
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function SelectClient {
	local returnVarName=$1
	local resultRec
	local selectRespt
	local menuList=()

	## Get the max width of client abbreviations
	local sqlStmt="select max(length(name)) from $clientInfoTable"
	RunSql2 $sqlStmt
	maxNameWidth=${resultSet[0]}

	## Get the clients data
	local sqlStmt="select distinct clients.name,clients.longName from $clientInfoTable,$siteInfoTable \
	where clients.idx=sites.clientId and sites.host = \"$hostName\" order by clients.name"
	RunSql2 $sqlStmt
	for resultRec in "${resultSet[@]}"; do
		resultRec=$(tr "\t" "|" <<< "$resultRec" )

		local clientCode=$(printf "%-${maxNameWidth}s" "$(cut -d"|" -f1 <<< "$resultRec")")
		local clientName=$(cut -d"|" -f2 <<< "$resultRec")
		menuList+=("$clientCode $clientName ")
	done

	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	printf "\nPlease specify the number of the client you wish to use:\n\n"
	SelectMenu 'menuList' 'selectResp' '\nClient number (or 'X' to quit) > '
	[[ $selectResp == '' ]] && Goodbye 0
	selectResp="$(cut -d ' ' -f1 <<< "$selectResp")"
	eval $returnVarName=\"$selectResp\"

	return 0
} #SelectClient
export -f SelectClient

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:18 CST 2017 - dscudiero - General syncing of dev to prod
