#!/bin/bash
version=1.0.89 # -- dscudiero -- Thu 05/10/2018 @ 14:12:07.20
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
# Get a report of all QA projects that are waiting
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function invalindCurrOrNextUrls-ParseArgsStd  { # or parseArgs-local
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
outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').txt

GetDefaultsData

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

## Report script usage totals by script
	whereClause="startEtime >= $startDate and username <> 'dscudiero'"
	sqlStmt="select name,count(*) from processlog where $whereClause group by name order by name;"
	RunSql $sqlStmt
	Msg; Msg "Total script usage for the last 7 days ($(date --date '7 days ago') through $(date))"
	maxNameWidth=0
	unset names counts
	for ((i=0; i<${#resultSet[@]}; i++)); do 
		result="${resultSet[$i]}"
		name="${result%%|*}"
		names+=("$name")
		counts+=("${result##*|}")
		[[ ${#name} -gt $maxNameWidth ]] && maxNameWidth=${#name}
	done
	for ((i=0; i<${#names[@]}; i++)); do
		string="${names[$i]}                         "
		Msg "^${string:0:$maxNameWidth} ${counts[$i]}"
	done

## Report script usage totals by user
	whereClause="startEtime >= $startDate and username <> 'dscudiero'"
	sqlStmt="select name,username,count(*) from processlog where  $whereClause group by username,name order by username;"
	RunSql $sqlStmt
	Msg; Msg "Script usage by user for the last 7 days ($(date --date '7 days ago') through $(date))"
	maxNameWidth=0; maxUsernameWidth=0;
	unset names usernames counts
	for ((i=0; i<${#resultSet[@]}; i++)); do 
		result="${resultSet[$i]}"
		name="${result%%|*}"; result="${result#*|}";
		[[ ${#name} -gt $maxNameWidth ]] && maxNameWidth=${#name}
		names+=("$name")
		username="${result%%|*}";
		usernames+=("$username")
		[[ ${#username} -gt $maxUsernameWidth ]] && maxUsernameWidth=${#username}
		counts+=("${result##*|}")
	done
	unset usernameOld
	for ((i=0; i<${#names[@]}; i++)); do
		string1="${names[$i]}                            "
		string2="${usernames[$i]}                         "
		[[ $i -gt 1 && ${usernames[$i]} != ${usernames[$i-1]} ]] && Msg
		Msg "^${string2:0:$maxUsernameWidth} ${string1:0:$maxNameWidth} ${counts[$i]}"
	done

## Send email
	if [[ -n $emailAddrs ]]; then
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
