## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:28:57.63
#===================================================================================================
# Display News
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function DisplayNews {
	local lastViewedDate lastViewedEdate displayedHeader itemNum msgText
	newsDisplayed=false
	[[ $noNews == true ]] && return 0

	## Loop through news types
		for newsType in tools $(tr -d '-' <<< $myName); do
			unset lastViewedDate; lastViewedEdate=0; displayedHeader=false; itemNum=0
			eval "unset ${newsType}LastRunDate"
			eval "${newsType}LastRunEDate=0"
			## Get users last accessed time date
				sqlStmt="select date,edate from $newsInfoTable where userName=\"$userName\" and object=\"$newsType\""
				RunSql 'mysql' "$sqlStmt"
				#[[ ${#resultSet[@]} -gt 0 ]] && lastViewedDate=$(echo "${resultSet[0]}" | cut -d'|' -f1) && lastViewedEDate=$(echo "${resultSet[0]}" | cut -d'|' -f2)
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					lastViewedDate=$(cut -d'|' -f1 <<< "${resultSet[0]}")
					lastViewedEdate=$(cut -d'|' -f2 <<< "${resultSet[0]}")
					eval ${newsType}LastRunDate=\"$lastViewedDate\"
					eval ${newsType}LastRunEdate=$lastViewedEdate
				fi
				#dump ${newsType}LastRunDate ${newsType}LastRunEDate

			## Read news items from the database
				#dump newsType lastViewedEdate

				sqlStmt="select item,date from $newsTable where edate >= \"$lastViewedEdate\" and object=\"$newsType\""
				RunSql 'mysql' "$sqlStmt"
				for result in "${resultSet[@]}"; do
					if [[ $displayedHeader == false ]]; then
						msgText="\n$(ColorK "'$newsType'") news items"
						[[ $lastViewedDate != '' ]] && msgText="$msgText since the last time you ran this script/report ($(cut -d ' ' -f1 <<< $lastViewedDate))"
						Msg2 $I "$msgText:\a"
						displayedHeader=true
					fi
					item=$(cut -d'|' -f1 <<< $result)
					date=$(cut -d'|' -f2 <<< $result)
					ProtectedCall "((itemNum++))"
					Msg2 "\t   $itemNum) $item"
					newsDisplayed=true
				done
			## Set the last read date on the database
				if [[ $lastViewedDate == '' ]]; then
					sqlStmt="insert into $newsInfoTable values(NULL,\"$newsType\",\"$userName\",NOW(),\"$(date +%s)\")"
				else
					sqlStmt="update $newsInfoTable set date=NOW(),edate=\"$(date +%s)\" where userName=\"$userName\" and object=\"$newsType\""
				fi
				RunSql 'mysql' "$sqlStmt"
		done
			[[ $newsDisplayed == true ]] && Msg2
	return 0
} #DisplayNews
export -f DisplayNews

#===================================================================================================
# Checkin Log
#===================================================================================================

