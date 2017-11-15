#!/bin/bash
#XO NOT AUTOVERSION
version=1.0.17 # -- dscudiero -- Wed 11/15/2017 @ 11:25:28.23
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
#
#
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-clientDataForLUC  { # or parseArgs-local
	argList+=(-reportName,6,option,reportName,,script,'The origional report name')
	argList+=(-emailAddrs,5,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	argList+=(-workBook,5,option,workBook,,script,'The fully qualified spreadsheet file name')
	argList+=(-workSheet,5,option,workSheet,,script,'The worksheet name')
	return 0
}
function Goodbye-clientDataForLUC  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-clientDataForLUC  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Msg "T You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

declare -A attendeeList
outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFileRoot="$outDir/$(date '+%Y-%m-%d-%H%M%S')"
outFile="$outFileRoot-attendeeLeepfrogRolesData.xls"

## Database fields & output header
header="Client Key\tClient Code\tLong Name\tHome URL\tCourseleaf Role\tFirst Name\tLast Name\tTitle\tWork phone\tCell phone\tFax Number\tEmail Address"
fields='clients.clientkey,clients.clientcode,clients.name,homeurl,contacts.contactrole,contacts.firstname,contacts.lastname'
fields="$fields,contacts.title,contacts.workphone,contacts.cell,contacts.fax,contacts.email"

tmpFile=$(MkTmpFile)

# workBook="$HOME/LUC2016AttendeeList.xlsx"
# workSheet='5780b9f8dd5f41feb5370735a559bbd'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd
[[ $reportName != '' ]] && GetDefaultsData "$reportName" "$reportsTable"
Hello


#===================================================================================================
# Main
#===================================================================================================

## Contact information that haved 'opted in' 
	Msg3 "Generating LUC Contact report..."
	Msg3 >> $outFile;
	Msg3 "Report: Client contacts that have 'opted-in'" >> $outFile
	Msg3 "        (Contacts records where leepday='Y')" >> $outFile
	dataDate=$(stat -c %y "$contactsSqliteFile"); dataDate=${dataDate%%.*}
	Msg3 "        (Source data file last modified: $dataDate)" >> $outFile
	Msg3 "Date: $(date)" >> $outFile
	Msg3 >> $outFile
	echo -e "$header" >> $outFile

	cntr=0
	whereClause='clients.clientkey=contacts.clientkey and Lower(clients.is_active)="y" and clients.products is not null and Lower(contacts.leepday)="y"'
	orderBy="clients.clientcode,contactrole,contacts.lastname"
	sqlStmt="select $fields from clients,contacts where $whereClause order by $orderBy"
	RunSql2 "$contactsSqliteFile" $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		numRecs=${#resultSet[@]}
		Msg3 "^Found $numRecs contacts records..."
		for result in "${resultSet[@]}"; do
			if [[ $workBook != '' ]]; then
				longName=$(cut -d'|' -f3 <<< $result)
				firstName=$(cut -d'|' -f5 <<< $result)
				lastName=$(cut -d'|' -f6 <<< $result)
				key="$longName.$firstName.$lastName"
				[[ ${attendeeList["$key"]+abc} ]] && continue
			fi
			echo -e "$(tr '|' "\t" <<< "$result")" >> $outFile
			[[ $cntr -ne 0 && $(($cntr % 100)) -eq 0 ]] && Msg3 "^Processed $cntr out of $numRecs..."
			let cntr=$cntr+1
		done
	else
		Msg3 $W "Did not find any contacts records meeting criteria" | tee -a $outFile
	fi

#===================================================================================================
## Done
#===================================================================================================
[[ -f $tmpFile ]] && rm -f $tmpFile
[[ $batchMode == true && -f $outFile ]] && rm -f $outFileRoot*
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================



## Mon Feb 13 16:09:23 CST 2017 - dscudiero - make sure we have our own tmpFile
## 11-06-2017 @ 16.43.26 - (1.0.12)    - dscudiero - Switch to new excel reader
## 11-08-2017 @ 12.22.21 - (1.0.13)    - dscudiero - Only return clients who have 'opted-in' (leepday=Y)
## 11-15-2017 @ 11.25.47 - (1.0.17)    - dscudiero - Updated to only report opted in contact records
