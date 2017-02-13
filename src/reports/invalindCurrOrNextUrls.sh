#!/bin/bash
version=1.0.47 # -- dscudiero -- 02/13/2017 @ 16:08:45.13
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
[[ $reportName != '' ]] && GetDefaultsData "$reportName" "$reportsTable"

#===================================================================================================
# Main
#===================================================================================================

## Generate report
	[[ $batchMode != true ]] && clear
	Msg2 | tee -a $outFile
	Msg2 "Report: $myName" | tee -a $outFile
	Msg2 "Date: $(date)" | tee -a $outFile
	[[ $shortDescription != '' ]] && Msg2 "$shortDescription" | tee -a $outFile
	Msg2 | tee -a $outFile

	sendEmail=false
	sqlStmt="select name,nextUrl,currUrl from $clientInfoTable where nextURL is not null or currUrl is not null and productsInSupport is not null order by name"
	RunSql2 $sqlStmt
	Msg2 "CurlRc\tClient\tEnv\tURL" | tee -a $outFile
	for result in ${resultSet[@]}; do
		client=$(cut -d'|' -f1 <<< $result)
		nextUrl=$(cut -d'|' -f2 <<< $result)
		currUrl=$(cut -d'|' -f3 <<< $result)
		for env in 'next' 'curr' ; do
			eval url="\$${env}Url"
			if [[ $url != '' && $url != 'NULL' ]]; then
				unset rc; ProtectedCall "curl -s $url > /dev/null"
				[[ $(Contains ",$okCodes," ",$rc,") == true ]] && continue
				Msg2 "$rc\t$client\t$env\t$url" | tee -a $outFile && sendMail=true && ((numFound += 1))
			fi
		done
	done

	Msg2  | tee -a $outFile
	Msg2 "Found $numFound clients with invalid urls" | tee -a $outFile
	Msg2 $NT1 "An URL is considered invalid if the curl request return code is not in '{$okCodes}'." | tee -a $outFile
	Msg2  | tee -a $outFile

## Send email
	if [[ $emailAddrs != '' && $sendMail == true ]]; then
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
## Mon Feb 13 16:09:33 CST 2017 - dscudiero - make sure we have our own tmpFile
