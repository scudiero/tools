## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.0" # -- dscudiero -- Mon 11/05/2018 @ 14:37:38
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SetClientDataObject {
	Import "SetSiteDirs"

	[[ -z $1 ]] && return 0
	client="$1"
	local client env envs result i sqlStmt pvtDir clonedFrom
	## Set primary client data
	sqlStmt="select longName,hosting,products,productsInSupport from $clientInfoTable where name=\"$client\" and recordStatus=\"A\""
	RunSql $sqlStmt
	if [[ -n ${resultSet[0]} ]]; then
		result="${resultSet[0]}"
		clientData["${client}.code"]="$client"; 
		clientData["${client}.longName"]="${result%%|*}"; result="${result#*|}"
		clientData["${client}.hosting"]="${result%%|*}"; result="${result#*|}"
		clientData["${client}.products"]="${result%%|*}"; result="${result#*|}"
		clientData["${client}.productsInSupport"]="${result%%|*}"; 
		#result="${result#*|}"
	else
		return 0
	fi 

	## Set env data
	sqlStmt="select env,share,host,cims,siteDir,siteDirWindows from $siteInfoTable where name=\"$client\" or name=\"$client-test\""
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		unset envs;
		for ((i=0; i<${#resultSet[@]}; i++)); do
			#echo "resultSet[$i] = >${resultSet[$i]}<"
			result="${resultSet[$i]}"
			env="${result%%|*}"; result="${result#*|}"
			envs="$envs,$env";
			clientData["${client}.${env}.server"]="${result%%|*}"; result="${result#*|}"
			clientData["${client}.${env}.host"]="${result%%|*}"; result="${result#*|}"
			clientData["${client}.${env}.cims"]="${result%%|*}"; result="${result#*|}"
			clientData["${client}.${env}.siteDir"]="${result%%|*}"; result="${result#*|}"
			clientData["${client}.${env}.siteDirWindows"]="${result%%|*}"
			[[ -n clientData["${client}.${env}.siteDirWindows"] ]] && clientData["${client}.${env}.siteDirWindows"]="\\${result%%|*}"
			#result="${result#*|}"
		done
		clientData["${client}.envs"]="${envs:1}"
	fi

	## Check to see if there is a dev or pvt env
	SetSiteDirs
	if [[ -n $pvtDir ]]; then
		env='pvt';
		envs="$envs,$env";
		clientData["${client}.${env}.siteDir"]="$pvtDir";
		if [[ -r "$pvtDir/.clonedFrom" ]]; then 
			clonedFrom="$(cat "$pvtDir/.clonedFrom")"
			clientData["${client}.pvt.clonedFrom"]="$clonedFrom"
			clientData["${client}.${env}.server"]="${clientData["${client}.${clonedFrom}.server"]}"
			clientData["${client}.${env}.host"]="${clientData["${client}.${clonedFrom}.host"]}"
			clientData["${client}.${env}.cims"]="${clientData["${client}.${clonedFrom}.cims"]}"
		fi
		clientData["${client}.envs"]="${envs}"
	fi

	# for mapCtr in "${!clientData[@]}"; do
	# 	echo -e "\tkey: '$mapCtr', value: '${clientData[$mapCtr]}'";
	# done;
	return 0
} #Alert
export -f Alert

#===================================================================================================
# Checkin Log
#===================================================================================================