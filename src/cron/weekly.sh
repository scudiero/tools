#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version="2.1.49" # -- dscudiero -- Fri 07/20/2018 @ 09:05:09
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="StringFunctions"
Import "$standardIncludes $myIncludes"
originalArgStr=$*

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd $originalArgStr
scriptArgs="$* -noBanners"

#========================================================================================================================
# Main
#========================================================================================================================
case "$hostName" in
	mojave)
		## Run Reports
			reports=("publishing -email \"froggersupport\"")
			reports+=("qaWaiting -email \"${qaTeam},${qaManager},dscudiero\"")
			#reports+=("toolsUsage -email \"${toolsManager},dscudiero\"")

			for ((i=0; i<${#reports[@]}; i++)); do
				report="${reports[$i]}"; reportName="${report%% *}"; reportArgs="${report##* }"; [[ $reportName == $reportArgs ]] && unset reportArgs
				Msg "\n$(date +"%m/%d@%H:%M") - Running $reportName $reportArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'; FindExecutable scriptsAndReports -sh -run reports $report -quiet $reportArgs $scriptArgs | Indent; TrapSigs 'on'
				Semaphore 'waiton' "$reportName" 'true'
				Msg "...$reportName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done

		## Run programs/functions
			pgms=(checkForPrivateDevSites weeklyRollup)
			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done

		## Check to see if we have received workflow specifications for any scheduled meetings
			tmpFile=$(mkTmpFile)
			ifs="$IFS"; IFS=$'\r'; while read line; do
				[[ ${line:0:1} == '#' ]] && continue
				client="${line%% *}"; line="${line#* }"
				csm="${line%% *}"; line="${line#* }"
				date="${line%% *}"; line="${line#* }"
				dump 1 -n client csm date line
				if [[ ! -d "$HOME/clientData/${client,,[a,z]}" ]]; then
					echo "" > $tmpFile
					echo "*** Warning ***" >> "$tmpFile"
					echo "A meeting, '$line', has been scheduled with $client on ${date}." >> "$tmpFile"
					echo "No workflow specifications have been received for this client." >> "$tmpFile"
					echo "Specifications must be received at least 5 business days before the client meeting." >> "$tmpFile"
					echo "Should specifications not be provided, said meeting will be canceled on the Monday of the week that the meeting was scheduled" >> "$tmpFile"
					mutt -s "Workflow meeting scheduled with $client without specs" -- ${csm}@leepfrog.com < $tmpFile;
					mutt -s "Workflow meeting scheduled with $client without specs" -- dscudiero@leepfrog.com < $tmpFile;
				fi
			done < "$HOME/clientData/meetings.txt"

			;;
	build7)
		## Run programs/functions
			pgms=(checkForPrivateDevSites)
			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done
			;;
esac

#========================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
## Thu Jan  5 14:50:18 CST 2017 - dscudiero - Switch to use RunSql2
## Tue Jan 17 07:42:31 CST 2017 - dscudiero - comment out some reports
## Fri Feb 10 14:58:55 CST 2017 - dscudiero - add 2 day summary reports back
## Thu Mar  9 07:52:54 CST 2017 - dscudiero - send the 2 day summary report to froggersupport
## Fri Mar 17 11:23:42 CDT 2017 - dscudiero - Added qaWaiting report
## 04-05-2017 @ 07.06.09 - (2.1.23)    - dscudiero - Add checkForPrivateDevSites
## 10-11-2017 @ 10.37.52 - (2.1.25)    - dscudiero - Switch to use FindExecutable -run
## 10-16-2017 @ 13.14.42 - (2.1.26)    - dscudiero - Tweak call to weekelyRollup
## 10-23-2017 @ 10.44.28 - (2.1.29)    - dscudiero - Refactor all calls
## 10-23-2017 @ 11.41.15 - (2.1.33)    - dscudiero - Fix problem incrementing indentLevel
## 10-23-2017 @ 11.41.52 - (2.1.34)    - dscudiero - Cosmetic/minor change
## 10-23-2017 @ 11.42.15 - (2.1.35)    - dscudiero - Cosmetic/minor change
## 10-23-2017 @ 11.58.31 - (2.1.36)    - dscudiero - Added -noBanners flag to the called scripts
## 10-30-2017 @ 07.44.10 - (2.1.37)    - dscudiero - Refactored to use common launcing code
## 11-06-2017 @ 10.38.31 - (2.1.38)    - dscudiero - Fix syntax error, missiong;; closure in mojave case block
## 03-22-2018 @ 12:47:18 - 2.1.40 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:34:24 - 2.1.41 - dscudiero - D
## 03-23-2018 @ 16:18:48 - 2.1.42 - dscudiero - D
## 04-02-2018 @ 07:15:55 - 2.1.43 - dscudiero - Move timezone report to weekly
## 04-16-2018 @ 07:40:33 - 2.1.44 - dscudiero - Fix call to client2daysummary report, pass in role
## 04-23-2018 @ 09:36:32 - 2.1.45 - dscudiero - Remove the 2day summary report
## 04-30-2018 @ 07:12:55 - 2.1.46 - dscudiero - Add toolsManager to toolsUsage report
## 05-07-2018 @ 10:32:07 - 2.1.47 - dscudiero - Fix syntax error, missing ) line 23
## 05-14-2018 @ 08:31:34 - 2.1.48 - dscudiero - Dont send out timeZone and toolsUsage reports
## 07-20-2018 @ 09:05:48 - 2.1.49 - dscudiero - Add code to check that we have recieved workflow specs for any scheduled meetings
