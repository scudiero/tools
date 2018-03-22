#!/bin/bash
version=1.0.79 # -- dscudiero -- Thu 03/22/2018 @ 12:55:58.14
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
# Get a report of all QA projects that are waiting
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function invalindCurrOrNextUrls-ParseArgsStd2  { # or parseArgs-local
	#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	myArgs+=('email|emailAddrs|option|emailAddrs||script|Email addresses to send reports to when running in batch mode')
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
sendMail=false
numFound=0

outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').txt

GetDefaultsData
okCodes="$(cut -d':' -f2- <<< $scriptData1)"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd2 $originalArgStr
[[ -n $reportName ]] && GetDefaultsData "$reportName" "$reportsTable"

#===================================================================================================
# Main
#===================================================================================================

## Generate report
	[[ $batchMode != true ]] && clear
	Msg | tee -a $outFile
	Msg "Report: $myName" | tee -a $outFile
	Msg "Date: $(date)" | tee -a $outFile
	[[ -n $shortDescription ]] && Msg "$shortDescription" | tee -a $outFile
	Msg | tee -a $outFile

	sendEmail=false
	#fields='clientcode,product,project,instance,env,requestor,tester,startDate'
	fields='clientcode,product,project,instance,env'
	orderByFields='clientcode,product,project,instance,env'

	## Get the maximum data length for each field
		for field in $(tr ',' ' ' <<< "$fields"); do
			sqlStmt="select max(length($field)) from $qaStatusTable"
			RunSql $sqlStmt
			eval "${field}Len=${resultSet[0]}"
			#eval "echo $field - \$${field}Len"
		done

	## Retrieve qaStatus data for blocked test instances and produce formatted output
		sqlStmt="select $fields from $qaStatusTable where numBlocked > 0 and endDate is NULL and recordstatus = \"A\" order by $orderByFields"
		RunSql $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			Msg  | tee -a $outFile
			Msg "Found ${#resultSet[@]} testing projects with at least one test case with 'blocked' status:" | tee -a $outFile
			for ((i=0; i<${#resultSet[@]}; i++)); do
				#echo -e "\n${resultSet[$i]}"
				unset outStr
				fieldCntr=1
				for field in $(tr ',' ' ' <<< "$fields"); do
					fieldVal=$(cut -d'|' -f$fieldCntr <<< ${resultSet[$i]})
					tmpStr="${fieldVal}               "
					eval "len=\$${field}Len"
					#dump -t field fieldVal -t tmpStr len
					outStr="${outStr} ${tmpStr:0:$len}"
					((fieldCntr+=1))
				done
				Msg "^$outStr"| tee -a $outFile
			done
			Msg | tee -a $outFile
			sendMail=true
		fi

	## Retrieve qaStatus data for waiting test instances and produce formatted output
		sqlStmt="select $fields from $qaStatusTable where numWaiting > 0 and endDate is NULL and recordstatus = \"A\" order by $orderByFields"
		RunSql $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			Msg  | tee -a $outFile
			Msg "Found ${#resultSet[@]} testing projects with at least one test case with 'waiting' status:" | tee -a $outFile
			for ((i=0; i<${#resultSet[@]}; i++)); do
				#echo -e "\n${resultSet[$i]}"
				unset outStr
				fieldCntr=1
				for field in $(tr ',' ' ' <<< "$fields"); do
					fieldVal=$(cut -d'|' -f$fieldCntr <<< ${resultSet[$i]})
					tmpStr="${fieldVal}               "
					eval "len=\$${field}Len"
					#dump -t field fieldVal -t tmpStr len
					outStr="${outStr} ${tmpStr:0:$len}"
					((fieldCntr+=1))
				done
				Msg "^$outStr"| tee -a $outFile
			done
			Msg | tee -a $outFile
			sendMail=true
		fi

## Send email
	if [[ -n $emailAddrs && $sendMail == true ]]; then
		Msg >> $outFile; Msg "Sending email(s) to: $emailAddrs">> $outFile; Msg >> $outFile
		for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
			mutt -a "$outFile" -s "$report report results: $(date +"%m-%d-%Y")" -- $emailAddr < $outFile
		done
	fi

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Thu Mar 16 16:56:46 CDT 2017 - dscudiero - General syncing of dev to prod
## Fri Mar 17 10:45:25 CDT 2017 - dscudiero - v
## 03-27-2017 @ 13.30.18 - (1.0.75)    - dscudiero - Only report on active records
## 05-17-2017 @ 13.41.10 - (1.0.77)    - dscudiero - Fix sql statements
## 03-22-2018 @ 13:03:09 - 1.0.79 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
