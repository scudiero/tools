#!/bin/bash
version=1.0.5 # -- dscudiero -- 07/28/2016 @  8:16:10.71
originalArgStr="$*"
scriptDescription="Report on specific client data for marketning team member"
TrapSigs 'on'

#= Description +===================================================================================
# Generate a report of specific client data and primary contacts
# Expects to be passed the userid of the sales rep to search for
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-clientDataForSales  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-reportName,6,option,reportName,,script,'The origional report name')
	argList+=(-emailAddrs,5,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	return 0
}
function Goodbye-clientDataForSales  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-clientDataForSales  { # or testMode-local
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
outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').xls

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd

[[ $reportName != '' ]] && GetDefaultsData "$reportName"
[[ $client != '' ]] && salesRep=$client

Prompt salesRep "Please specify the userid of the Marketing Rep to report on" '*any*';
salesRep=$(Lower $salesRep)

#===================================================================================================
# Main
#===================================================================================================
## Generate report
	[[ $batchMode != true ]] && clear
	Msg2 | tee -a $outFile
	Msg2 "Report: $myName" | tee -a $outFile
	Msg2 "Date: $(date)" | tee -a $outFile
	[[ $shortDescription != '' ]] && Msg2 "$shortDescription" | tee -a $outFile
	[[ $scriptDescription != '' ]] && Msg2 "$scriptDescription" | tee -a $outFile
	Msg2 "Report for salesRep: '$salesRep'" | tee -a $outFile
	Msg2 | tee -a $outFile

	header="Code\tName\tProducts\tProducts in Support\tSIS\tHosting\tPrimary Contact(s)\tFirst Name\tLast Name\tTitle\tWork Phone\tCell Phone\tFax Number\tEmail Address"
	echo -e "$header" >> $outFile
	## Get the list of clients
		fields='idx,name,longName,ifnull(products,"") as products,ifnull(productsInSupport,"") as productsInSupport ,ifnull(sis,"") as sis,ifnull(hosting,"") as hosting'
		sqlStmt="select $fields from $clientInfoTable where salesRep like \"%$salesRep%\" and recordStatus='A' order by name"
		RunSql 'mySql' $sqlStmt
		for rec in "${resultSet[@]}"; do clientSet+=("$rec"); done
		for clientRec in "${clientSet[@]}"; do
			clientKey=$(cut -d"|" -f1 <<< $clientRec)
			outRec=$(cut -d'|' -f2- <<< $clientRec |  sed s"/NULL//g" )
			## Get the contact information from the contacts db
				fields='contactrole,firstname,lastname,title,workphone,cell,fax,email'
				sqlStmt="select $fields from contacts where clientkey=\"$clientKey\" and contactrole like \"%primary%\" order by contactrole,lastname"
				RunSql 'sqlite' "$contactsSqliteFile" $sqlStmt
				for contactRec in "${resultSet[@]}"; do
					outRec="$outRec|$(tr '|' ',' <<< $contactRec)"
				done
			## output report record
			echo -e "$(tr '|' "\t" <<< "$outRec")" >> $outFile
		done

		Msg2  | tee -a $outFile
		Msg2 "Found ${#clientSet[@]} clients found for '$salesRep'"
		Msg2  | tee -a $outFile
		Msg2 "Output can be found in: '$outFile'"
		Msg2
		[[ ${#clientSet[@]} -gt 0 ]] && sendMail=true

## Send email
	if [[ $emailAddrs != '' && $sendMail == true && batchMode == true ]]; then
		Msg2 >> $outFile; Msg2 "Sending email(s) to: $emailAddrs">> $outFile; Msg2 >> $outFile
		for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
			mutt -a "$outFile" -s "$report report results: $(date +"%m-%d-%Y")" -- $emailAddr < $outFile
		done
	fi

#===================================================================================================
## Done
#===================================================================================================
[[ -f $tmpFile ]] && rm -f $tmpFile
[[ $batchMode == true && -f $outFile ]] && rm -f $outFile
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
