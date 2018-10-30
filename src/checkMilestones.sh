#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.0.4" # -- dscudiero -- Tue 10/30/2018 @ 15:38:16
#=======================================================================================================================
#= Description #========================================================================================================
#
#
#=======================================================================================================================
TrapSigs 'on'
myIncludes="RunSql"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""

Main() {
	#=======================================================================================================================
	# Declare local variables and constants
	#=======================================================================================================================
	tmpFile=$(mkTmpFile)

	GetDefaultsData -f $myName
	ParseArgsStd $originalArgStr

	deltaDays=5
	[[ -n $scriptData1 ]] && deltaDays="$scriptData1"
	declare -A milestones

	## Get a list of milestones
	Msg 1 "Querying the milestones database for milestones due in $deltaDays or less..."
	sqlStmt="select clients.name,clients.longName,clients.catCsm,cimCsm,clssCSM,project,label,date,rank,datediff(date,now()) as days2due"
	sqlStmt="$sqlStmt from $clientInfoTable,$milestonesInfoTable"
	sqlStmt="$sqlStmt where completeStatus <> \"true\" and client <> \"\""
	sqlStmt="$sqlStmt and snapshotArchived = \"N\""
	sqlStmt="$sqlStmt and datediff(date,now()) <= $deltaDays"
	sqlStmt="$sqlStmt and clients.name = milestones.client"
	sqlStmt="$sqlStmt order by clients.name,milestones.rank"
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		Msg 1 1 "Found ${#resultSet[@]} records"
		## Loop through milestones parsing into a hash table for each unique notify individual
		for ((xx=0; xx<${#resultSet[@]}; xx++)); do
			result="${resultSet[$xx]}"
			dump 2 result
			clientCode="${result%%|*}"; result="${result#*|}"
			clientName="${result%%|*}"; result="${result#*|}"
			catCSM="${result%%|*}"; result="${result#*|}"
			cimCSM="${result%%|*}"; result="${result#*|}"
			clssCSM="${result%%|*}"; result="${result#*|}"
			project="${result%%|*}"; result="${result#*|}"
			milestone="${result%%|*}"; result="${result#*|}"
			date="${result%%|*}"; result="${result#*|}"
			rank="${result%%|*}"; result="${result#*|}"
			daysToDue="${result%%|*}"; result="${result#*|}"
			dump 2 -t clientCode clientName catCSM cimCSM clssCSM project milestone date rank daysToDue
			tmpStr="$clientName|$clientCode|$project|$milestone|$date|$daysToDue"
			if [[ $(Contains "$project" 'cat') == true ]]; then
				[[ ${milestones["$catCSM"]+abc} ]] && milestones["$catCSM"]="${milestones[$catCSM]};$tmpStr" || milestones["$catCSM"]="$tmpStr"
			elif [[ $(Contains "$project" 'cim') == true ]]; then 
				[[ ${milestones["$cimCSM"]+abc} ]] && milestones["$cimCSM"]="${milestones[$cimCSM]};$tmpStr" || milestones["$cimCSM"]="$tmpStr"
			elif [[ $(Contains "$project" 'clss') == true ]]; then 
				[[ ${milestones["$clssCSM"]+abc} ]] && milestones["$clssCSM"]="${milestones[$clssCSM]};$tmpStr" || milestones["$clssCSM"]="$tmpStr"
			fi
		done

		## Send out emails
		Msg 1 "Sending emails..."
		for key in "${!milestones[@]}"; do
			Msg 1 1 $key
			emailAddr="${key##*/}"
			Msg 2 2 "${milestones[$key]}"
			hashValue="${milestones[$key]}"
			Msg "\n${key%%/*}," > $tmpFile
			Msg "\nThe following Courseleaf project milestones have are over due or are coming due in the next $deltaDays days:" >> $tmpFile
			cntr=1
			while [ true ]; do
				tmpStr="${hashValue%%;*}"; tmpStr2="$tmpStr"; hashValue="${hashValue#*;}"
				name="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				code="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				project="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				milestone="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				date="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				daysToDue="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				Msg "^$cntr) $name ($code) -- $project, '$milestone' is due in $daysToDue days ($date)" >> $tmpFile
				(( cntr++ ))
				[[ $hashValue == $tmpStr2 ]] && break
			done
			Msg "\n*** Please do not respond to this email, it was sent by an automated process\n" >> $tmpFile
			## $DOIT mutt -a "$tmpFile" -s "Courseleaf project Milestones report - $(date +"%m-%d-%Y")" -- $emailAddr < $tmpFile
		done;
	fi

return 0


} ## Main

	#=======================================================================================================================
	# Standard call back functions
	#=======================================================================================================================
	function testsh-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}

	function testsh-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function testsh-Help  {
		helpSet='client,env' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0

		[[ -z $* ]] && return 0
		echo -e "This script is used to check for late/pending Courseleaf project milestones"
		echo -e "\nThe actions performed are:"
		bullet=1; echo -e "\t$bullet) Action 1"
		(( bullet++ )); echo -e "\t$bullet) Action 2"
		echo -e "\nTarget site data files potentially modified:"
		echo -e "\tfile 1"
		echo -e "\tfile 2"
# or
# 		if [[ -n "$someArrayVariable" ]]; then
# 			for file in $(tr ',' ' ' <<< $someArrayVariable); do echo -e "\t\t- $file"; done
# 		fi
		return 0
	}

	function testsh-testMode  { # or testMode-local
		return 0
	}



#============================================================================================================================================
Main "$@"
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
