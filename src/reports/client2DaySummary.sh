RunSql2 #!/bin/bash
#==================================================================================================
version=1.1.21 # -- dscudiero -- Thu 05/25/2017 @ 16:55:12.96
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
function parseArgs-client2DaySummary  { # or parseArgs-local
	#argList+=(-ignoreXmlFiles,7,switch,ignoreXmlFiles,,script,'Ignore extra xml files')
	argList+=(-reportName,6,option,reportName,,script,'The origional report name')
	argList+=(-emailAddrs,5,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	argList+=(-role,4,option,role,,script,'The role to run the report on, values in {support,salesRep,csmRep}')
}
function Goodbye-client2DaySummary  { # or Goodbye-local
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	return 0
}
function testMode-client2DaySummary  { # or testMode-local
	return 0
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
ParseArgsStd
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
	RunSql2 $sqlStmt
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
		Msg2
		Msg2 "Report: $myName"
		Msg2 "Date: $(date)"
		[[ $shortDescription != '' ]] && Msg2 "$shortDescription"
		Msg2
		Msg2 "The following client pages have not had their '$searchString' paragraphs modified from the default"
		Msg2 "Client list based on the $warehouseDb/$clientInfoTable as of $(date)"

		for key in "${keysArray[@]}"; do
			data=${dataMap["$key"]}
			contactInfo="$(cut -d'|' -f1 <<< "$data")"
			data="$(cut -d'|' -f2 <<< "$data")"
			Msg2
			Msg2 "$key:"
			found=0
			for token in $(tr ',' ' ' <<< "$data"); do
				Msg2 "^$token"
				ProtectedCall "((found++))"
			done
			Msg2 "^Found $found clients"
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
