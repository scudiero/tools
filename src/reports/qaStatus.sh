#!\tbin\tbash
version=1.0.77 # -- dscudiero -- Wed 05\t17\t2017 @ 13:35:39.07
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
# Get a report of all QA projects that are waiting
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-qaStatus  { # or parseArgs-local
	#argList+=(-ignoreXmlFiles,7,switch,ignoreXmlFiles,,script,'Ignore extra xml files')
	argList+=(-short,5,switch,short,,script,'Generate the short report')
	argList+=(-long,4,switch,long,,script,'Generate the long report')
	argList+=(-cat,3,switch,cat,,script,'Generate report for CAT test results')
	argList+=(-cim,3,switch,cim,,script,'Generate report for CIM test results')
	argList+=(-emailAddrs,5,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	return 0
}
function Goodbye-qaStatus  { # or Goodbye-local
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	return 0
}
function testMode-qaStatus  { # or testMode-local
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
mode='short'

outDir="$HOME/Reports/$myName"
[[ ! -d $outDir ]] && mkdir -p $outDir
outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').txt

GetDefaultsData
okCodes="$(cut -d':' -f2- <<< $scriptData1)"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd
[[ -n $reportName ]] && GetDefaultsData "$reportName" "$reportsTable"
[[ $short == false && $short == false ]] && mode='short'
[[ $long == true ]] && mode='long'
[[ $cat == false && $cim == false ]] && cat=true && cim=true
dump -1 mode cat cim

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

## Generate report
	[[ $batchMode != true ]] && clear
	echo | tee $outFile
	echo "$myName ($mode) report run by $userName on $(date +"%m-%d-%Y") at $(date +"%H.%M.%S")" > $outFile
	[[ -n $shortDescription ]] && echo -e "($shortDescription)\n" >> $outFile
	echo | tee -a $outFile

	## Get the week that priority was assigned
	sqlStmt="select distinct implPriorityWeek from $qaStatusTable where implPriorityWeek is not null"
	RunSql2 $sqlStmt
	[[ ${#resultSet[@]} -gt 0 ]] && implPriorityWeek="${resultSet[0]}" || unset implPriorityWeek

	if [[ $mode == 'short' ]]; then
		header="Client\tProduct\tProject\tInstance\tTester\tRequester\tDeveloper\tStart Date\tDays Active\tResources Remaining (hrs)"
		header="${header}\tWeek starting: ${implPriorityWeek}\tAssigned hours\tWaiting(csm,dev) Failed(csm,dev) -- Note"
		## Get the status records
		sqlStmt="select clientcode,product,project,ifnull(instance,''),ifnull(tester,''),ifnull(requester,'') as Requester,ifnull(developer,''),"
		sqlStmt="${sqlStmt}ifnull(date_format(startDate,'%Y-%m-%d'),''),"
		sqlStmt="${sqlStmt}ifnull(datediff(curdate(),startDate),''),ifnull(round((resourcesEstimate-resourcesUsed),2),''),"
		sqlStmt="${sqlStmt}ifnull(implPriority,''),ifnull(implHours,''),"
		sqlStmt="${sqlStmt}ifnull(CONCAT('W(',ifnull(numWaitingCsm,0),',',ifnull(numWaitingDev,0),'), ','F(',ifnull(numFailedCsm,0),',',ifnull(numFailedDev,0) ,') -- ',notes),"
		sqlStmt="${sqlStmt}CONCAT('W(',ifnull(numWaitingCsm,0),',',ifnull(numWaitingDev,0),'), ','F(', ifnull(numFailedCsm,0),',',ifnull(numFailedDev,0) ,')'))"
		sqlStmt="${sqlStmt}from $qaStatusTable where recordstatus='A' order by clientcode"
	else
		header="Client\tProduct\tProject\tInstance\tTester\tRequester\tDeveloper\tStart Date\tDays Active\tResources Remaining (hrs)"
		header="${header}\t% Attempted\t%Attempted Passed\t% Attempted Failed"
		header="${header}\tWeek starting: ${implPriorityWeek}\tAssigned hours\tWaiting(csm,dev) Failed(csm,dev) -- Note"

		sqlStmt="select clientcode,product,project,ifnull(instance,''),ifnull(tester,''),ifnull(requester,'') as Requester,ifnull(developer,''),"
		sqlStmt="${sqlStmt}ifnull(date_format(startDate,'%Y-%m-%d'),''),"
		sqlStmt="${sqlStmt}ifnull(datediff(curdate(),startDate),''),ifnull(round((resourcesEstimate-resourcesUsed),2),''),"
		sqlStmt="${sqlStmt}ifnull(round((numAttempted/numTests)*100,0),''),ifnull(round((numPassed/numAttempted)*100,0),''),ifnull(round((numFailed/numAttempted)*100,0),''),"
		sqlStmt="${sqlStmt}ifnull(implPriority,''),ifnull(implHours,''),"
		sqlStmt="${sqlStmt}ifnull(CONCAT('W(',ifnull(numWaitingCsm,0),',',ifnull(numWaitingDev,0),'), ','F(',ifnull(numFailedCsm,0),',',ifnull(numFailedDev,0) ,') -- ',notes),"
		sqlStmt="${sqlStmt}CONCAT('W(',ifnull(numWaitingCsm,0),',',ifnull(numWaitingDev,0),'), ','F(', ifnull(numFailedCsm,0),',',ifnull(numFailedDev,0) ,')'))"
		sqlStmt="${sqlStmt}from $qaStatusTable where recordstatus='A' order by clientcode"
	fi

	## Get the status records
	RunSql2 $sqlStmt
	[[ ${#resultSet[@]} -eq 0 ]] && Terminate "No data returned from the query to the $qaStatusTable table"

	## Output the report data
		echo | tee -a $outFile
		echo -e "$header" | tee -a $outFile
		for ((i=0; i<${#resultSet[@]}; i++)); do
			echo -e "$(tr '|' "\t" <<< "${resultSet[$i]}")" | tee -a $outFile
		done
		echo | tee -a $outFile

	echo; echo
	Note "Report output also save in '$outFile'"


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
## 03-27-2017 @ 13.30.18 - (1.0.75)    - dscudiero - Only report on active records
## 05-17-2017 @ 13.41.10 - (1.0.77)    - dscudiero - Fix sql statements
## 05-19-2017 @ 13.48.34 - (1.0.77)    - dscudiero - Add message where the report data is saved
