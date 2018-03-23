#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.13 # -- dscudiero -- Thu 03/22/2018 @ 12:44:07.86
#=======================================================================================================================
# Run once a week from cron
#=======================================================================================================================
TrapSigs 'on'
Import "$standardIncludes $myIncludes"

originalArgStr="$*"

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd $originalArgStr
scriptArgs="$*"

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)
			## Roll up the weekly log archives
				[[ $verbose == true ]] && printf "\n$(PadChar '-')\n" && printf "*** Log file roll up ***\n"
				Msg "\n*** Logs rollup -- Starting ***"
				lastMonthNum=$(date --date="$(date +%Y-%m-15) -1 month" +'%m')
				lastMonthAbbrev=$(date --date="$(date +%Y-%m-15) -1 month" +'%b')
				cd $TOOLSPATH/Logs
				[[ -d ./cronJobs ]] && rm -rf ./cronJobs
				tar -cvzf "${lastMonthAbbrev}-$(date '+%Y').tar.gz" $lastMonthNum-* --remove-files
				Msg "\n^$myName logs rollup -- Completed ***"
			;;
	build5)
			;;
	build7)
			;;
esac

#=======================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
## Thu Jan  5 14:50:06 CST 2017 - dscudiero - Switch to use RunSql2
## 10-11-2017 @ 10.37.45 - (2.1.9)     - dscudiero - Switch to use FindExecutable -run
## 11-22-2017 @ 06.28.33 - (2.1.10)    - dscudiero - switch to use parsargsstd2
## 12-18-2017 @ 07.50.50 - (2.1.12)    - dscudiero - Tweak messaging
## 03-22-2018 @ 12:47:08 - 2.1.13 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:34:09 - 2.1.13 - dscudiero - D
