#!/bin/bash
version=1.0.18 # -- dscudiero -- 09/09/2016 @  9:18:04.92
originalArgStr="$*"
scriptDescription="Report on clients and contacts for LUC invitations"
TrapSigs 'on'

#= Description +===================================================================================
# Generate a report of specific client data and primary contacts
# Expects to be passed the userid of the sales rep to search for
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-clientDataForLUC  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-reportName,6,option,reportName,,script,'The origional report name')
	argList+=(-emailAddrs,5,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	return 0
}
function Goodbye-clientDataForLUC  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-clientDataForLUC  { # or testMode-local
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
sendMail=false

outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFileRoot="$outDir/$(date '+%Y-%m-%d-%H%M%S')"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd

[[ $reportName != '' ]] && GetDefaultsData "$reportName"
[[ $client != '' ]] && salesRep=$client
[[ $batchMode != true ]] && clear

#===================================================================================================
# Main
#===================================================================================================
## Generate report # 1 - client data
	outFile="$outFileRoot-clientData.xls"
	Msg2 | tee -a $outFile
	Msg2 "Report: $myName" | tee -a $outFile
	Msg2 "Date: $(date)" | tee -a $outFile
	[[ $shortDescription != '' ]] && Msg2 "$shortDescription" | tee -a $outFile
	[[ $scriptDescription != '' ]] && Msg2 "$scriptDescription" | tee -a $outFile
	Msg2 | tee -a $outFile

	header="Client Key\tClient Code\tLong Name\tProducts\tInstitution Type\tSIS\tHosting"
	echo -e "$header" >> $outFile
	fields='idx,name,longName,ifnull(products,"") as products, ifnull(classification,"") as classification, ifnull(sis,"") as sis, ifnull(hosting,"") as hosting'
	sqlStmt="select $fields from clients where recordstatus='A' and products is not null order by name"
	RunSql 'mySql' $sqlStmt
	for result in "${resultSet[@]}"; do
		echo -e "$(tr '|' "\t" <<< "$result")" >> $outFile
	done
	Msg2 >> $outFile
	Msg2 "Client data can be found in: '$outFile'"
	[[ ${#clientSet[@]} -gt 0 ]] && sendMail=true

## Generate report # 1 - contacts data
	outFile="$outFileRoot-contactsData.xls"
	Msg2 >> $outFile
	Msg2 "Report: $myName" >> $outFile
	Msg2 "Date: $(date)" >> $outFile
	[[ $shortDescription != '' ]] && Msg2 "$shortDescription" >> $outFile
	[[ $scriptDescription != '' ]] && Msg2 "$scriptDescription" >> $outFile
	Msg2 >> $outFile

	header="Client Key\tClient Code\tLong Name\tContact Role\tFirst Name\tLast Name\tTitle\tWork phone\tCell phone\tFas Number\tEmail Address"
	echo -e "$header" >> $outFile
	fields='clients.clientkey,clients.clientcode,clients.name,contacts.contactrole,contacts.firstname,contacts.lastname,contacts.title,contacts.workphone,contacts.cell,contacts.fax,contacts.email'
	whereClause='clients.clientkey=contacts.clientkey and clients.is_active="Y" and clients.products is not null'
	orderBy="clients.clientcode,contactrole,contacts.lastname"
	sqlStmt="select $fields from clients,contacts where $whereClause order by $orderBy"
	RunSql 'sqlite' "$contactsSqliteFile" $sqlStmt
	for result in "${resultSet[@]}"; do
		echo -e "$(tr '|' "\t" <<< "$result")" >> $outFile
	done
	Msg2 >> $outFile
	Msg2 "Contacts data can be found in: '$outFile'"
	[[ ${#clientSet[@]} -gt 0 ]] && sendMail=true

## Send email
	# if [[ $emailAddrs != '' && $sendMail == true && batchMode == true ]]; then
	# 	Msg2 >> $outFile; Msg2 "Sending email(s) to: $emailAddrs">> $outFile; Msg2 >> $outFile
	# 	for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
	# 		mutt -a "$outFile" -s "$report report results: $(date +"%m-%d-%Y")" -- $emailAddr < $outFile
	# 	done
	# fi

#===================================================================================================
## Done
#===================================================================================================
[[ -f $tmpFile ]] && rm -f $tmpFile
[[ $batchMode == true && -f $outFile ]] && rm -f $outFileRoot*
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================


			# ## Get the contact information from the contacts db
			# 	fields='contactrole,firstname,lastname,title,workphone,cell,fax,email'
			# 	sqlStmt="select $fields from contacts where clientkey=\"$clientKey\" and contactrole like \"%primary%\" order by contactrole,lastname"
			# 	RunSql 'sqlite' "$contactsSqliteFile" $sqlStmt
			# 	for contactRec in "${resultSet[@]}"; do
			# 		outRec="$outRec|$(tr '|' ',' <<< $contactRec)"
			# 	done