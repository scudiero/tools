## XO NOT AUTOVERSION
#===================================================================================================
version="2.1.27" # -- dscudiero -- Wed 13/06/2018 @ 13:33:53
#===================================================================================================
# Common script exit
# args:
# 	exitCode, if exitCode = 'X' the quit without messages
# 	additionalText, if first token of additional text is 'alert' then call Alert
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Goodbye {
	myIncludes="SetFileExpansion Colors ProcessLogger PadChar PrintBanner Alert PushPop StringFunctions"
	Import "$standardIncludes $myIncludes"

	SetFileExpansion 'off'
	local exitCode=$1; shift; exitCode="${exitCode,,[a-z]}"

	local additionalText=$*
	dump -3 exitCode additionalText

	local tokens
	local alert=false
	local token=$(cut -d' ' -f1 <<< $additionalText)
	local token="${token,,[a-z]}"
	[[ $token == 'alert' ]] && alert=true && shift && additionalText=$*
	[[ -z $exitCode ]] && exitCode=0

	## Call script specific goodbye script if defined
		[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName "$exitCode"
		[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME "$exitCode"

	## Cleanup temp files
		[[ -n $tmpRoot ]] && SetFileExpansion 'on' && rm -rf $tmpRoot/${myName}* >& /dev/null && SetFileExpansion

	## Exit Process
	case $exitCode in
		quiet)
			[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Remove' $myLogRecordIdx
			[[ $$ -ne $BASHPID && $PAUSEATEXIT != true ]] && kill -1 $BASHPID  ## If the BASHPID != the current processid then we are in a subshell, send a HangUP signal to the subshell
			;;
		quickquit|x)
			[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Remove' $myLogRecordIdx
			Msg "\n*** $myName: Stopping at user's request ***"
			## If the BASHPID != the current processid then we are in a subshell, send a HangUP signal to the subshell
			[[ $$ -ne $BASHPID && $PAUSEATEXIT != true ]] && { Msg "Waiting for co-process $BASHPID to end"; kill -1 $BASHPID; }
			;;
		return|r)
			secondaryMessagesOnly=true
			;;
		*)
			## If there are any forked process, then wait on them
			if [[ ${#forkedProcesses[@]} -gt 0  && $waitOnForkedProcess == true ]]; then
				Msg; Msg "*** Waiting for ${#forkedProcesses[@]} forked processes to complete ***"
				for pid in ${forkedProcesses[@]}; do
					wait $pid;
				done;
				Msg '*** All forked process have completed ***'
			fi

			## calculate epapsed time
			if [[ epochStime != "" ]]; then
				epochEtime=$(date +%s)
				endTime=$(date '+%Y-%m-%d %H:%M:%S')
				elapSeconds=$(( epochEtime - epochStime ))
				eHr=$(( elapSeconds / 3600 ))
				elapSeconds=$(( elapSeconds - eHr * 3600 ))
				eMin=$(( elapSeconds / 60 ))
				elapSeconds=$(( elapSeconds - eMin * 60 ))
				eSec=$elapSeconds
				elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $eSec)
			fi

			## print goodbye message
			date=$(date)
			#dump quiet noHeaders secondaryMessagesOnly exitCode
			if [[ $quiet != true && $noHeaders != true && $secondaryMessagesOnly != true ]]; then
				if [[ $exitCode -ne -1 ]]; then
					## Standard messages
					local numMsgs=0
					Alert 'off'
					if [[ ${#summaryMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
						Msg
						PrintBanner "Processing Summary"
						Msg
						for msg in "${summaryMsgs[@]}"; do Msg "^$msg"; done
						let numMsgs=$numMsgs+${#summaryMsgs[@]}
					fi
					if [[ ${#warningMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
						Msg
						PrintBanner "${#warningMsgs[@]} warning message(s) were issued during processing"
						Msg
						for msg in "${warningMsgs[@]}"; do Msg "^$msg"; done
						let numMsgs=$numMsgs+${#warningMsgs[@]}
					fi
					if [[ ${#errorMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
						Msg
						PrintBanner "${#errorMsgs[@]} error message(s) were issued during processing"
						Msg
						for msg in "${errorMsgs[@]}"; do Msg "^$msg"; done
						let numMsgs=$numMsgs+${#errorMsgs[@]}
					fi
					[[ $numMsgs -gt 0 ]] && printf "\n$(PadChar)\n"
					Alert 'on'
					Msg

				fi
				[[ $DOIT != '' ]] && Msg "$(ColorE "*** The 'DOIT' flag is turned off, changes not committed ***")"
				[[ $informationOnlyMode == true ]] && Msg "$(ColorE "*** Information only mode, no data updated ***")"
				if [[ $exitCode -eq 0 ]]; then
					Msg "$(ColorK "${myName}") $(ColorI " -- $additionalText completed successfully.")"
				else
					Msg "$(ColorK "${myName}") $(ColorE " -- $additionalText completed with errors, exit code = $exitCode\n")\a"
				fi
				[[ -n $logFile && $logFile != '/dev/null' && $noBanners != true ]] && Msg "Additional details may be found in:\n^'$logFile'"
				[[ $noBanners != true ]] && Msg "$date (Elapsed time: $elapTime)"
				[[ $TERM == 'dumb' && $noBanners != true ]] && echo
				[[ $noBanners != true ]] &&  Msg "$(PadChar)"
			fi #not quiet noHeaders secondaryMessagesOnly
			[[ $alert == true ]] && Alert
	esac

	## Write end record to db log
	[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Update' $myLogRecordIdx 'exitCode' "$exitCode"
	[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'End' $myLogRecordIdx
	## If running for another user, then send an email to that user
	if [[ -n $forUser && $exitCode != 'quiet' && $logFile != '/dev/null' ]]; then
		tmpFile=$(mkTmpFile)
		Msg > $tmpFile
		Msg "'$myName' was run in your behalf by $userName, the log is attached" >> $tmpFile
		Msg >> $tmpFile
		Msg "\n*** Running on behalf of user: ${forUser}, an email was sent to: ${forUser}@leepfrog.com\n"
		Msg "$(PadChar)" >> $tmpFile
		Msg >> $tmpFile
		cat "$logFile" >> $tmpFile
		Msg >> $tmpFile
		$DOIT mutt -a "$logFile" -s "$myName '$client' site created - $(date +"%m-%d-%Y")" -- ${forUser}@leepfrog.com < $tmpFile
		rm -f $tmpFile
	fi

	if [[ $PAUSEATEXIT == true && $exitCode != 'x' && $exitCode != 'quiet' ]]; then
		Msg "$colorKey"
		Msg '*******************************************************************************'
		Msg '*** Remote script excution has complete, please press enter to close window ***'
		Msg '*******************************************************************************'
		Msg "$colorDefault"
		Alert 3
		read
	fi
	[[ $(IsNumeric $exitCode) != true ]] && exitCode=0
	if [[ $secondaryMessagesOnly == true || $batchMode == true  || $exitCode == 'quiet' ]]; then
		secondaryMessagesOnly=false
		return 0
	else
		trap - EXIT SIGHUP
		#set +eE
		exit $exitCode
	fi
} #Goodbye
export -f Goodbye

function Quit {
	exitCode=$1
	Goodbye 'quickQuit'
} #Quit
function quit { Quit $* ; }
function QUIT { [[ -f $tmpFile ]] && rm -f "$tmpFile"; trap - ERR EXIT; set +xveE; rm -rf $tmpRoot > /dev/null 2>&1; exit; }

export -f Quit
export -f quit
export -f QUIT


#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:40 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan 11 07:50:53 CST 2017 - dscudiero - Switch to use ProcessLogger
## Thu Jan 19 07:13:36 CST 2017 - dscudiero - Add debug statement
## Thu Jan 19 07:26:50 CST 2017 - dscudiero - Remove debug statements
## Mon Feb  6 12:58:43 CST 2017 - dscudiero - switch bar Msg2 to echo
## Wed Feb  8 08:58:32 CST 2017 - dscudiero - Remove trailing blanks in messaging
## 04-14-2017 @ 12.03.47 - ("2.0.97")  - dscudiero - General syncing of dev to prod
## 04-14-2017 @ 12.17.42 - ("2.0.98")  - dscudiero - skip
## 04-14-2017 @ 14.25.31 - ("2.0.102") - dscudiero - Remove the call to the local function
## 05-08-2017 @ 09.12.48 - ("2.0.103") - dscudiero - Add script name to stopping message
## 05-10-2017 @ 09.42.02 - ("2.0.123") - dscudiero - Update exit code
## 05-10-2017 @ 09.55.58 - ("2.0.124") - dscudiero - Remove debug statement
## 05-10-2017 @ 12.49.12 - ("2.0.130") - dscudiero - Kill subshells before exiting
## 05-10-2017 @ 12.53.07 - ("2.0.131") - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 07.35.57 - ("2.0.132") - dscudiero - Remove all tmpfiles under the scripts name under tmproot
## 08-01-2017 @ 08.07.58 - ("2.0.136") - dscudiero - Add emailing to the foruser
## 08-01-2017 @ 08.16.00 - ("2.0.137") - dscudiero - General syncing of dev to prod
## 09-01-2017 @ 09.27.18 - ("2.0.138") - dscudiero - Add call myname-FUNCNAME function if found
## 09-25-2017 @ 07.50.38 - ("2.0.140") - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 07.57.50 - ("2.0.141") - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 09.01.41 - ("2.0.143") - dscudiero - Switch to Msg
## 10-02-2017 @ 16.24.58 - ("2.0.144") - dscudiero - Add PadChar to the includes list
## 10-16-2017 @ 12.36.07 - ("2.1.0")   - dscudiero - Add StringFunctions to includes
## 10-16-2017 @ 14.01.40 - ("2.1.1")   - dscudiero - If in batchmode then return vs exit
## 10-19-2017 @ 09.38.28 - ("2.1.3")   - dscudiero - Added -noBanner option to limit outout
## 10-19-2017 @ 16.15.42 - ("2.1.6")   - dscudiero - Fix problem where we were not printing banners
## 01-26-2018 @ 08.33.46 - 2.1.9 - dscudiero - Move Quit into Goodbye
## 01-26-2018 @ 08.38.56 - 2.1.10 - dscudiero - Also delete the tmpFile if it exits for QUIT
## 01-26-2018 @ 08.39.37 - 2.1.11 - dscudiero - Cosmetic/minor change/Sync
## 03-23-2018 @ 16:52:12 - 2.1.12 - dscudiero - Msg3 -> Msg
## 04-20-2018 @ 07:22:36 - 2.1.13 - dscudiero - Move the alert for pauseonexit
## 05-10-2018 @ 08:30:40 - 2.1.14 - dscudiero - Do not put up banner if PAUSONEXIT and user requested to terminate the script
## 05-10-2018 @ 08:32:19 - 2.1.15 - dscudiero - Cosmetic/minor change/Sync
## 05-10-2018 @ 09:16:32 - 2.1.20 - dscudiero - Do not show the promptonexiet banner of user is stopping the script
## 06-05-2018 @ 14:08:30 - 2.1.20 - dscudiero - Do not print logFile message if logFile is not set
## 06-08-2018 @ 15:10:45 - 2.1.21 - dscudiero - Add ! quiet to some items
## 06-11-2018 @ 09:24:49 - 2.1.26 - dscudiero - Add quiet to use return to exit
## 06-13-2018 @ 13:43:28 - 2.1.27 - dscudiero - Add check to make sure logfile is not /dev/null if running forUser
## 06-18-2018 @ 10:46:38 - 2.1.27 - dscudiero - Add message about waiting for parent process to end
