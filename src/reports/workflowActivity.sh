#!/bin/bash
version=1.0.-1 # -- dscudiero -- Wed 05/16/2018 @ 16:21:27.17
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
# Get a report of all QA projects that are waiting
#==================================================================================================

echo "HERE HERE HERE HERE"
#==================================================================================================
# Declare local variables and constants
#==================================================================================================
outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').txt

GetDefaultsData
Init "getClient getEnv"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd $originalArgStr
[[ -n $reportName ]] && GetDefaultsData "$reportName" "$reportsTable"

#===================================================================================================
# Main
#===================================================================================================

## Report header
	[[ $batchMode != true ]] && clear
	Msg
	Msg "Report: $myName"
	Msg "Date: $(date)"
	[[ -n $shortDescription ]] && Msg "$shortDescription"
	Msg

	startDate=$(date --date '7 days ago' '+%s')

## Report workflow activity for a client
	whereClause="client=\"$client\" and catagory=\"workflow\""
	sqlStmt="user,env,jalot,text,date from $activityLogTable where $whereClause order by date DESC;"
	RunSql $sqlStmt
	Msg; Msg "Workflow related activities for '$client'"
	maxNameWidth=0
	unset names counts
	for ((i=0; i<${#resultSet[@]}; i++)); do 
		result="${resultSet[$i]}"
		user="${result%%|*}"; result="$result{#*|}"
		env="${result%%|*}"; result="$result{#*|}"
		jalot="${result%%|*}"; result="$result{#*|}"
		text="${result%%|*}"; result="$result{#*|}"
		date="${result%%|*}"; result="$result{#*|}"
		dump user env jalot text date
	done



# ## Send email
# 	if [[ -n $emailAddrs ]]; then
# 		Msg >> $outFile; Msg "Sending email(s) to: $emailAddrs">> $outFile; Msg >> $outFile
# 		for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
# 			mutt -a "$outFile" -s "$report report results: $(date +"%m-%d-%Y")" -- $emailAddr < $outFile
# 		done
# 	fi

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## 05-16-2018 @ 16:21:28 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
