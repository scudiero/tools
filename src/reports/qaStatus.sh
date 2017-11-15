#!\tbin\tbash
version=1.0.77 # -- dscudiero -- Wed 05\t17\t2017 @ 13:35:39.07
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +========================================================================================================
# QA Status report
#=======================================================================================================================
#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
function parseArgs-qaStatus  { # or parseArgs-local
	#argList+=(-ignoreXmlFiles,7,switch,ignoreXmlFiles,,script,'Ignore extra xml files')
	argList+=(-long,4,switch,long,,script,'Generate the long report')
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

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
sendMail=false
numFound=0
mode='short'

GetDefaultsData

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
ParseArgsStd2
[[ -n $reportName ]] && GetDefaultsData "$reportName" "$reportsTable"
[[ $long == true ]] && mode='long'
dump -1 mode

#========================================================================================================================
# Main
#========================================================================================================================

## Get the week that priority was assigned
	sqlStmt="select distinct implPriorityWeek from $qaStatusTable where implPriorityWeek is not null"
	RunSql2 $sqlStmt
	[[ ${#resultSet[@]} -gt 0 ]] && implPriorityWeek="${resultSet[0]}" || unset implPriorityWeek

## Get the report data
	if [[ $mode == 'short' ]]; then
		header='Client|Product|Project|Instance|Tester|Requester|Developer|Start Date|Days Active|Resources Remaining (hrs)'
		header="${header}|Week starting: ${implPriorityWeek}|Assigned hours|Waiting(csm,dev) Failed(csm,dev) -- Note"
		## Get the status records
		sqlStmt="select clientcode,product,project,ifnull(instance,''),ifnull(tester,''),ifnull(requester,'') as Requester,ifnull(developer,''),"
		sqlStmt="${sqlStmt}ifnull(date_format(startDate,'%Y-%m-%d'),''),"
		sqlStmt="${sqlStmt}ifnull(datediff(curdate(),startDate),''),ifnull(round((resourcesEstimate-resourcesUsed),2),''),"
		sqlStmt="${sqlStmt}ifnull(implPriority,''),ifnull(implHours,''),"
		sqlStmt="${sqlStmt}ifnull(CONCAT('W(',ifnull(numWaitingCsm,0),',',ifnull(numWaitingDev,0),'), ','F(',ifnull(numFailedCsm,0),',',ifnull(numFailedDev,0) ,') -- ',notes),"
		sqlStmt="${sqlStmt}CONCAT('W(',ifnull(numWaitingCsm,0),',',ifnull(numWaitingDev,0),'), ','F(', ifnull(numFailedCsm,0),',',ifnull(numFailedDev,0) ,')'))"
		sqlStmt="${sqlStmt}from $qaStatusTable where recordstatus='A' order by clientcode"
	else
		header='Client|Product|Project|Instance|Tester|Requester|Developer|Start Date|Days Active|Resources Remaining (hrs)'
		header="${header}|% Attempted|%Attempted Passed|% Attempted Failed"
		header="${header}|Week starting: ${implPriorityWeek}|Assigned hours|Waiting(csm,dev) Failed(csm,dev) -- Note"

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
dump -1 sqlStmt
RunSql2 $sqlStmt
[[ ${#resultSet[@]} -eq 0 ]] && Terminate "No data returned from the query to the $qaStatusTable table"

## Output the report data
	resultSet=("${header}" "${resultSet[@]}")
	for ((i=0; i<${#resultSet[@]}; i++)); do
		echo "${resultSet[$i]}"
	done
	#PrintColumnarData 'resultSet' '|' | tee "$outFile"

#========================================================================================================================
## Done
#========================================================================================================================
Goodbye 0 #'alert'

#========================================================================================================================
## Check-in log
#========================================================================================================================
## Thu Mar 16 16:56:46 CDT 2017 - dscudiero - General syncing of dev to prod
## Fri Mar 17 10:45:25 CDT 2017 - dscudiero - v
## 03-27-2017 @ 13.30.18 - (1.0.75)    - dscudiero - Only report on active records
## 05-17-2017 @ 13.41.10 - (1.0.77)    - dscudiero - Fix sql statements
## 05-19-2017 @ 13.48.34 - (1.0.77)    - dscudiero - Add message where the report data is saved
## 05-19-2017 @ 13.50.46 - (1.0.77)    - dscudiero - General syncing of dev to prod
## 05-22-2017 @ 07.28.20 - (1.0.77)    - dscudiero - Fix problem with script not sending emails
## 05-25-2017 @ 09.36.55 - (1.0.77)    - dscudiero - call PrintColumnarData function for output
## 05-25-2017 @ 16.25.34 - (1.0.77)    - dscudiero - Refactoredto just send data back
## 08-25-2017 @ 07.42.04 - (1.0.77)    - dscudiero - Added debug statement
## 11-15-2017 @ 09.47.45 - (1.0.77)    - dscudiero - misc cleanup of stale arguments
