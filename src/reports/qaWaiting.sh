#!/bin/bash
version=1.0.74 # -- dscudiero -- 03/17/2017 @  8:01:27.77
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
# Get a report of all the NEXT or CURR urls that are invalide for all clients in support
# (Invald = curl to url returns nothing)
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-invalindCurrOrNextUrls  { # or parseArgs-local
	#argList+=(-ignoreXmlFiles,7,switch,ignoreXmlFiles,,script,'Ignore extra xml files')
	argList+=(-emailAddrs,5,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	return 0
}
function Goodbye-invalindCurrOrNextUrls  { # or Goodbye-local
	return 0
}
function testMode-invalindCurrOrNextUrls  { # or testMode-local
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
ParseArgsStd
[[ -n $reportName ]] && GetDefaultsData "$reportName" "$reportsTable"

#===================================================================================================
# Main
#===================================================================================================

## Generate report
	[[ $batchMode != true ]] && clear
	Msg2 | tee -a $outFile
	Msg2 "Report: $myName" | tee -a $outFile
	Msg2 "Date: $(date)" | tee -a $outFile
	[[ -n $shortDescription ]] && Msg2 "$shortDescription" | tee -a $outFile
	Msg2 | tee -a $outFile

	sendEmail=false
	#fields='clientcode,product,project,instance,env,requestor,tester,startDate'
	fields='clientcode,product,project,instance,env'
	orderByFields='clientcode,product,project,instance,env'

	## Get the maximum data length for each field
		for field in $(tr ',' ' ' <<< "$fields"); do
			sqlStmt="select max(length($field)) from $qaStatusTable"
			RunSql2 $sqlStmt
			eval "${field}Len=${resultSet[0]}"
			#eval "echo $field - \$${field}Len"
		done

	## Retrieve qaStatus data for blocked test instances and produce formatted output
		sqlStmt="select $fields from $qaStatusTable where numBlocked > 0 and endDate is NULL order by $orderByFields"
		RunSql2 $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			Msg2  | tee -a $outFile
			Msg2 "Found ${#resultSet[@]} testing projects with at least one test case with 'blocked' status:" | tee -a $outFile
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
				Msg2 "^$outStr"| tee -a $outFile
			done
			Msg2 | tee -a $outFile
			sendMail=true
		fi

	## Retrieve qaStatus data for waiting test instances and produce formatted output
		sqlStmt="select $fields from $qaStatusTable where numWaiting > 0 and endDate is NULL order by $orderByFields"
		RunSql2 $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			Msg2  | tee -a $outFile
			Msg2 "Found ${#resultSet[@]} testing projects with at least one test case with 'waiting' status:" | tee -a $outFile
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
				Msg2 "^$outStr"| tee -a $outFile
			done
			Msg2 | tee -a $outFile
			sendMail=true
		fi

## Send email
	if [[ -n $emailAddrs && $sendMail == true ]]; then
		Msg2 >> $outFile; Msg2 "Sending email(s) to: $emailAddrs">> $outFile; Msg2 >> $outFile
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
