#!/bin/bash
#XO NOT AUTOVERSION
version=1.0.13 # -- dscudiero -- Wed 11/08/2017 @ 11:26:53.50
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

## Get the workbook file and worksheet
if [[ $workBook == "" ]]; then
	Msg3
	unset ans; Prompt ans 'Do you have an attende list spreadsheet' 'Yes No' 'Yes'; ans=$(Lower "${ans:0:1}")
	if [[ $ans == 'y' ]]; then
		Prompt workBook 'Please specify the full path/name of the workbook file' '*file*'
		## Get the list of sheets in the workbook
		GetExcel2 -wb "$workBook" -ws 'GetSheets'
		IFS='|' read -ra sheets <<< "${resultSet[0]}"
		dump -1 sheets
		if ${#sheets[@]} -gt 1 ]]; then
			Msg3 "The workbook has multiple worksheets:"
			unset sheetStr
			for sheet in ${sheets[@]}; do
				Msg3 "^$sheet"
				sheetStr="$sheetStr $sheet"
			done
			Prompt workSheet "Which worksheet do you wish to use" "$sheetStr"
		else
			workSheet="${sheets[0]}"
		fi
	fi
fi

#===================================================================================================
# Main
#===================================================================================================
## If we have a workbook then read in the attendee list
if [[ $workBook != '' ]]; then
	## Reading data from a workbook
		Msg3 "Reading workbook..."
		GetExcel2 -wb "$workBook" -ws "$workSheet"
		unset keyArray
		for ((i=0; i<${#resultSet[@]}; i++)); do
			result="${resultSet[$i]}"
			firstName=$(cut -d'|' -f1 <<< $result)
			lastName=$(cut -d'|' -f2 <<< $result)
			longName=$(cut -d'|' -f5 <<< $result)
			email=$(cut -d'|' -f6 <<< $result)
			[[ $(Lower "$longName") == 'company' ]] && continue
			key="$longName|$firstName|$lastName|$email"
			attendeeList["$key"]=true
			keyArray+=("$key")
			dump -2 -n result -t longName firstName lastName email
		done
		Msg3 "^Read ${#attendeeList[@]} records"
		## Sort the key array
		IFSave="$IFS"; IFS=$'\n' sortedArray=($(sort <<<"${keyArray[*]}")); IFS="$IFSave"
		unset keyArray; for rec in "${sortedArray[@]}"; do keyArray+=("$rec"); done

	## Generate first report - fols that attened
		Msg3 "Generating Attendee / role map data..."
		Msg3 > $outFile
		Msg3 "Report: Attendee / role map data" >> $outFile
		Msg3 "Date: $(date)" >> $outFile
		[[ $shortDescription != '' ]] && Msg3 "$shortDescription" >> $outFile
		[[ $scriptDescription != '' ]] && Msg3 "$scriptDescription" >> $outFile
		Msg3 >> $outFile
		echo -e "$header" >> $outFile
		unset notFound
		foundCntr=0
		cntr=0

		## Loop through the attendeeList map items
		#for mapCtr in "${!attendeeList[@]}"; do
		for ((mapCntr=1; mapCntr<${#keyArray[@]}; mapCntr++)); do
			mapElement=${keyArray[$mapCntr]}
			longName=$(cut -d'|' -f1 <<< $mapElement)
			firstName=$(cut -d'|' -f2 <<< $mapElement)
			lastName=$(cut -d'|' -f3 <<< $mapElement)
			email=$(cut -d'|' -f4 <<< $mapElement)
			dump -1 -n mapElement -t longName firstName lastName email
			## Look up the role
				## Check against instution name
				whereClause="clients.clientkey=contacts.clientkey and Lower(clients.name)=\"$(Lower "$longName")\""
				whereClause="$whereClause and Lower(contacts.firstname)=\"$(Lower "$firstName")\" and Lower(contacts.lastname)=\"$(Lower "$lastName")\""
				sqlStmt="select $fields from clients,contacts where $whereClause"
				dump -2 -t sqlStmt
				RunSql2 "$contactsSqliteFile" $sqlStmt
				if [[ ${#resultSet[@]} -eq 0 ]]; then
					## Check for email match
					whereClause="clients.clientkey=contacts.clientkey and Lower(contacts.email)=\"$(Lower "$email")\""
					whereClause="$whereClause and Lower(contacts.firstname)=\"$(Lower "$firstName")\" and Lower(contacts.lastname)=\"$(Lower "$lastName")\""
					sqlStmt="select $fields from clients,contacts where $whereClause"
					dump -2 -t sqlStmt
					RunSql2 "$contactsSqliteFile" $sqlStmt
				fi
				## Process any results
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					for result in "${resultSet[@]}"; do
						dump -1 -t result
						echo -e "$(tr '|' "\t" <<< "$result")" >> $outFile
					done
					let foundCntr=$foundCntr+1
				else
					notFound+=("$longName\t$firstName\t$lastName\t$email")
					#Msg3 $E "Could not file role data for '$lastName,$firstName' at '$longName', skipping"
				fi

			[[ $cntr -ne 0 && $(($cntr % 100)) -eq 0 ]] && Msg3 "^Processed $cntr out of ${#attendeeList[@]}..."
			let cntr=$cntr+1
		done ## attendeList
		Msg3 "^Found $foundCntr matched records in the contactsDb"
		if [[ ${#notFound[@]} -gt 0 ]]; then
			Msg3 >> $outFile;Msg3 >> $outFile;
			Msg3 "^${#notFound[@]} attendee records did not have any matchs in the contactsDb (checking both institution name or email address):" >> $outFile
			Msg3 "\tInstitution\tFirst Name\tLast Name\tEmail Address" >> $outFile
			for ((cntr2=1; cntr2<${#notFound[@]}; cntr2++)); do
				echo -e "\t${notFound[$cntr2]}" >> $outFile
			done
		fi
		Msg3
fi ##[[ $workBook != '' ]];

## Generate second report - folks in the contacts db that did not attend
	Msg3 "Generating Non-Attendee / role map data..."
	Msg3 >> $outFile; Msg3 >> $outFile; Msg3 >> $outFile
	Msg3 "Report: Non-Attendee / role map data" >> $outFile
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

	Msg3 >> $outFile
	Msg3
	Msg3 "Report output can be found in: '$outFile'"
	#[[ ${#clientSet[@]} -gt 0 ]] && sendMail=true

## Generate third report - folks in the contacts db for sites contacts with leepday='Y'
	Msg3 "Generating Client/Contacts data for client contacts marked with leepday='Y'..."
	Msg3 >> $outFile; Msg3 >> $outFile; Msg3 >> $outFile
	Msg3 "Report: Client/Contacts data for client contacts marked with leepday='Y'" >> $outFile
	Msg3 "Date: $(date)" >> $outFile
	Msg3 >> $outFile
	echo -e "$header" >> $outFile

	cntr=0
	whereClause='contacts.leepday="Y" and clients.clientkey=contacts.clientkey and clients.products is not null'
	orderBy="clients.clientcode,contactrole,contacts.lastname"
	sqlStmt="select $fields from clients,contacts where $whereClause order by $orderBy"
	RunSql2 "$contactsSqliteFile" $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		numRecs=${#resultSet[@]}
		Msg3 "^Found $numRecs contacts records..."
		for result in "${resultSet[@]}"; do
			echo -e "$(tr '|' "\t" <<< "$result")" >> $outFile
			[[ $cntr -ne 0 && $(($cntr % 100)) -eq 0 ]] && Msg3 "^Processed $cntr out of $numRecs..."
			let cntr=$cntr+1
		done
	else
		Msg3 $W "Did not find any contacts records meeting criteria" | tee -a $outFile
	fi

	Msg3 >> $outFile
	Msg3
	Msg3 "Report output can be found in: '$outFile'"
	#[[ ${#clientSet[@]} -gt 0 ]] && sendMail=true

## Send email
	# if [[ $emailAddrs != '' && $sendMail == true && batchMode == true ]]; then
	# 	Msg3 >> $outFile; Msg3 "Sending email(s) to: $emailAddrs">> $outFile; Msg3 >> $outFile
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



## Mon Feb 13 16:09:23 CST 2017 - dscudiero - make sure we have our own tmpFile
## 11-06-2017 @ 16.43.26 - (1.0.12)    - dscudiero - Switch to new excel reader
## 11-08-2017 @ 12.22.21 - (1.0.13)    - dscudiero - Only return clients who have 'opted-in' (leepday=Y)
## 11-15-2017 @ 12.20.38 - (1.0.13)    - dscudiero - Removed all the old stuff and just report on contact records witg leepday=Y
