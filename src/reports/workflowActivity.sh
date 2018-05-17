#!/bin/bash
version=1.0.12 # -- dscudiero -- Thu 05/17/2018 @  8:48:25.36
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').txt

GetDefaultsData
Init "getClient"

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

## Report workflow activity for a client
	whereClause="client=\"$client\" and category=\"workflow\""
	sqlStmt="select user,env,jalot,text,date from $activityLogTable where $whereClause order by date DESC"
	RunSql $sqlStmt
	Msg; Msg "Workflow related activities for '$client'"
	Msg '\tUser     \tEnv\tJalot\tDate                \tActivity'
	for ((i=0; i<${#resultSet[@]}; i++)); do 
		result="${resultSet[$i]}"
		user="${result%%|*}"; result="${result#*|}"; user="$user          "
		env="${result%%|*}"; result="${result#*|}"
		jalot="${result%%|*}"; result="${result#*|}" ; [[ $jalot == 'NULL' ]] && unset jalot
		text="${result%%|*}"; result="${result#*|}"
		date="${result%%|*}"; result="${result#*|}"
		Msg "\t${user:0:9}\t$env\t$jalot\t${date:0:19}\t$text"
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
## 05-16-2018 @ 16:53:00 - 1.0.11 - dscudiero - Initial checking
## 05-17-2018 @ 08:49:09 - 1.0.12 - dscudiero - Fix spelling error
