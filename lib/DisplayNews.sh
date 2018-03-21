## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.40" # -- dscudiero -- Wed 03/21/2018 @  8:17:35.85
#===================================================================================================
# Display News
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function DisplayNews {
	return 0
	local lastViewedDate lastViewedEdate displayedHeader itemNum msgText
	newsDisplayed=false
	[[ $noNews == true ]] && return 0
	Import 'RunSql2'

	## Loop through news types
		for newsType in tools $(tr -d '-' <<< $myName); do
			unset lastViewedDate; lastViewedEdate=0; displayedHeader=false; itemNum=0
			eval "unset ${newsType}LastRunDate"
			eval "${newsType}LastRunEDate=0"
			## Get users last accessed time date
				sqlStmt="select date,edate from $newsInfoTable where userName=\"$userName\" and object=\"$newsType\""
				RunSql2 $sqlStmt
				#[[ ${#resultSet[@]} -gt 0 ]] && lastViewedDate=$(echo "${resultSet[0]}" | cut -d'|' -f1) && lastViewedEDate=$(echo "${resultSet[0]}" | cut -d'|' -f2)
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					result="${resultSet[0]}"
					lastViewedDate=${result%%|*}; result=${result#*|};
					lastViewedEdate=${result%%*|}; result=${result#*|};
					eval ${newsType}LastRunDate=\"$lastViewedDate\"
					eval ${newsType}LastRunEdate=$lastViewedEdate
				fi
			## Read news items from the database
				sqlStmt="select item,date from $newsTable where edate >= \"$lastViewedEdate\" and object=\"$newsType\""
				RunSql2 $sqlStmt
				itemNum=0
				for result in "${resultSet[@]}"; do
					if [[ $displayedHeader == false ]]; then
						msgText="$(ColorK "'$newsType'") news items"
						[[ -n $lastViewedDate ]] && msgText="$msgText since the last time you ran this script/report ($(cut -d ' ' -f1 <<< $lastViewedDate))"
						Info "$msgText:\a"
						displayedHeader=true
					fi
					item=${result%%|*}; result=${result#*|};
					date=${result%%*|}; result=${result#*|};
					let itemNum=$itemNum+1
					Msg3 "^$itemNum) $item (${date%% *})"
					newsDisplayed=true
				done
			## Set the last read date on the database
				if [[ -z $lastViewedDate ]]; then
					sqlStmt="insert into $newsInfoTable values(NULL,\"$newsType\",\"$userName\",NOW(),\"$(date +%s)\")"
				else
					sqlStmt="update $newsInfoTable set date=NOW(),edate=\"$(date +%s)\" where userName=\"$userName\" and object=\"$newsType\""
				fi
				RunSql2 $sqlStmt
		done
			[[ $newsDisplayed == true ]] && Msg3
	return 0
} #DisplayNews
export -f DisplayNews

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:53:15 CST 2017 - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 16.09.23 - ("2.0.7")   - dscudiero - Add RunSql2 to includes
## 10-02-2017 @ 15.31.52 - ("2.0.9")   - dscudiero - General syncing of dev to prod
## 03-21-2018 @ 08:17:53 - 2.0.40 - dscudiero - Turn off news temporarially
