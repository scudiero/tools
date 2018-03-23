RunSql #!/bin/bash
#==================================================================================================
version=1.1.24 # -- dscudiero -- Fri 03/23/2018 @ 14:36:02.50
#==================================================================================================
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
# Get a report of all the NEXT or CURR urls that are invalide for all clients in support
# (Invald = curl to url returns nothing)
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function client2DaySummary-ParseArgsStd  { # or parseArgs-local
	#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	myArgs+=('email|emailAddrs|option|emailAddrs||script|Email addresses to send reports to when running in batch mode')
	myArgs+=('report|reportName|option|emailAdreportNamedrs||script|The origional report name')
	myArgs+=('role|role|option|role||script|The role to run the report on, values in {support,salesRep,csmRep}')
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
genReport=false
numFound=0
clientsDir="/mnt/internal/site/stage/web/clients"

declare -A roleMap
roleMap['support']='support'
roleMap['sales']='salesRep'
roleMap['implementation']='csmRep'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
unset client
ParseArgsStd $originalArgStr
[[ $reportName != '' ]] && GetDefaultsData "$reportName" "$reportsTable"

[[ $client != '' ]] && orgUnit="$(TitleCase "$client")" || orgUnit='Support'
if [[ $role == '' ]]; then
	searchString="$orgUnit Summary"
	role="${roleMap[$(Lower $orgUnit)]}"
else
	searchString="$(TitleCase $role) Summary"
fi
dump -2 client reportName emailAddrs orgUnit searchString role

clientsDir="/mnt/internal/site/stage/web/clients"
#===================================================================================================
# Main
#===================================================================================================

## Build a map of client to contact person
	declare -A dataMap
	unset keysArray
	[[ $ignoreList != '' ]] && ignoreList="and name not in (\"$(sed s'/,/","/g' <<< $ignoreList)\")"
	sqlStmt="select name,products,productsinsupport,$role from $clientInfoTable where recordStatus=\"A\" $ignoreList order by $role,name"
	RunSql $sqlStmt
	for result in "${resultSet[@]}"; do
		clientCode=$(cut -d'|' -f1 <<< $result)
		products=$(cut -d'|' -f2 <<< $result)
		[[ -z $products || $products == 'NULL' ]] && continue
		productsInSupport=$(cut -d'|' -f3 <<< $result)
		[[ -z $productsInSupport || $productsInSupport == 'NULL' ]] && continue
		contactInfo=$(cut -d'|' -f4 <<< $result)
		if [[ $contactInfo == 'NULL' ]]; then
			contactName="Unassigned (i.e. no entry for role '$role' found in contacts/clientRoles)"
			contactEmail=NULL
			contactId=NULL
		else
			contactName=$(cut -d'/' -f1 <<< $contactInfo)
			contactEmail=$(cut -d'/' -f2 <<< $contactInfo)
			contactId=$(cut -d'@' -f1 <<< $contactEmail)
		fi
		dump -2 -n clientCode contactName contactEmail contactId

		## Check the clients tcf file looking for the xxxxxx summary line
			file="$clientsDir/$clientCode/index.tcf"
			if [[ ! -r $file ]]; then
				[[ $batchMode != true ]] && Warning 0 1 "Could not read '$file', skipping" || Note 0 1 "Could not read '$file', skipping"
				continue
			fi
			ifs="$IFS"; IFS=$'\n'; while read line; do
			if [[ $line == "text:<h3>$searchString</h3>" ]]; then
				read line
				if [[ $line == 'text:<p>Living, updated 2-paragraph summary of client status on each product.</p>' ]]; then
					if [[ ${dataMap["$contactName"]+abc} ]]; then
						tmpStr="${dataMap["$contactName"]}"
						dataMap["$contactName"]="$tmpStr,$clientCode"
					else
						dataMap["$contactName"]="$contactId,$contactEmail|$clientCode"
						keysArray+=("$contactName")
					fi
					genReport=true
				fi
			fi
			done < $file; IFS="$ifs"
	done
	DumpMap 1 "$(declare -p dataMap)"

##  Generate output
	dump -2 genReport
	if [[ $genReport == true ]]; then
		Msg
		Msg "Report: $myName"
		Msg "Date: $(date)"
		[[ $shortDescription != '' ]] && Msg "$shortDescription"
		Msg
		Msg "The following client pages have not had their '$searchString' paragraphs modified from the default"
		Msg "Client list based on the $warehouseDb/$clientInfoTable as of $(date)"

		for key in "${keysArray[@]}"; do
			data=${dataMap["$key"]}
			contactInfo="$(cut -d'|' -f1 <<< "$data")"
			data="$(cut -d'|' -f2 <<< "$data")"
			Msg
			Msg "$key:"
			found=0
			for token in $(tr ',' ' ' <<< "$data"); do
				Msg "^$token"
				ProtectedCall "((found++))"
			done
			Msg "^Found $found clients"
		done
	fi

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Mon Feb 13 16:09:19 CST 2017 - dscudiero - make sure we have our own tmpFile
## 04-17-2017 @ 07.42.20 - (1.1.12)    - dscudiero - remove import of dumpmap
## 05-08-2017 @ 09.13.11 - (1.1.18)    - dscudiero - filter out sites that do not have products or productsInSupport
## 05-26-2017 @ 06.39.23 - (1.1.21)    - dscudiero - General syncing of dev to prod
## 03-22-2018 @ 13:02:49 - 1.1.23 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:35:35 - 1.1.24 - dscudiero - D
