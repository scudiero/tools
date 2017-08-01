## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.136" # -- dscudiero -- Tue 08/01/2017 @  8:06:52.96
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
	SetFileExpansion 'off'
	Msg2 $V3 "*** Starting: $FUNCNAME ***"

	local exitCode=$1; shift
	local additionalText=$*
	dump -3 exitCode additionalText

	local tokens
	local alert=false
	local token=$(Lower $(cut -d' ' -f1 <<< $additionalText))
	[[ $token == 'alert' ]] && alert=true && shift && additionalText=$*
	[[ "$exitCode" = "" ]] && exitCode=0

	## Call script specific goodbye script if defined
		[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName "$exitCode"

	## Cleanup temp files
		[[ -n $tmpRoot ]] && SetFileExpansion 'on' && rm -rf $tmpRoot/${myName}* >& /dev/null && SetFileExpansion

	## Exit Process
	case "$(Lower "$exitCode")" in
		quiet)
			[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Remove' $myLogRecordIdx
			[[ $$ -ne $BASHPID ]] && kill -1 $BASHPID  ## If the BASHPID != the current processid then we are in a subshell, send a HangUP signel to the subshell
			;;
		quickquit|x)
			[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Remove' $myLogRecordIdx
			Msg2 "\n*** $myName: Stopping at user's request ***"
			[[ $$ -ne $BASHPID ]] && kill -1 $BASHPID  ## If the BASHPID != the current processid then we are in a subshell, send a HangUP signel to the subshell
			;;
		return|r)
			secondaryMessagesOnly=true
			;;
		*)
			## If there are any forked process, then wait on them
				if [[ ${#forkedProcesses[@]} -gt 0  && $waitOnForkedProcess == true ]]; then
					Msg2; Msg2 "*** Waiting for ${#forkedProcesses[@]} forked processes to complete ***"
					for pid in ${forkedProcesses[@]}; do
						wait $pid;
					done;
					Msg2 '*** All forked process have completed ***'
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
							echo
							PrintBanner "Processing Summary"
							echo
							for msg in "${summaryMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#summaryMsgs[@]}
						fi
						if [[ ${#warningMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
							echo
							PrintBanner "${#warningMsgs[@]} warning message(s) were issued during processing"
							echo
							for msg in "${warningMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#warningMsgs[@]}
						fi
						if [[ ${#errorMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
							echo
							PrintBanner "${#errorMsgs[@]} error message(s) were issued during processing"
							echo
							for msg in "${errorMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#errorMsgs[@]}
						fi
						[[ $numMsgs -gt 0 ]] && printf "\n$(PadChar)\n"
						Alert 'on'
						echo

					fi
					[[ $DOIT != '' ]] && Msg2 "$(ColorE "*** The 'DOIT' flag is turned off, changes not committed ***")"
					[[ $informationOnlyMode == true ]] && Msg2 "$(ColorE "*** Information only mode, no data updated ***")"
					if [[ $exitCode -eq 0 ]]; then
						Msg2 "$(ColorK "${myName}") $(ColorI " -- $additionalText completed successfully.")"
					else
						Msg2 "$(ColorK "${myName}") $(ColorE " -- $additionalText completed with errors, exit code = $exitCode")\a"
					fi
					[[ $logFile != '/dev/null' ]] && Msg2 "Additional details may be found in:\n^'$logFile'"
					Msg2 "$date (Elapsed time: $elapTime)"
					[[ $TERM == 'dumb' ]] && echo
					Msg2 "$(PadChar)"
				fi #not quiet noHeaders secondaryMessagesOnly
			[[ $alert == true ]] && Alert
	esac

	## Write end record to db log
	[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Update' $myLogRecordIdx 'exitCode' "$exitCode"
	[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'End' $myLogRecordIdx

	## If running for another user, then send an email to that user
	if [[ -n $forUser ]]; then
		Msg2 > $tmpFile
		Msg2 "'$myName' was run in your behalf by $userName, the log is attached" >> $tmpFile
		Msg2 >> $tmpFile
		Msg2 "\nRunning on behalf of user: ${forUser}, email sent to: ${forUser}@leepfrog.com\n"
		Msg2 "$(PadChar)" >> $tmpFile
		Msg2 >> $tmpFile
		cat "$logFile" >> $tmpFile
		Msg2 >> $tmpFile
		$DOIT mutt -a "$logFile" -s "$myName '$client' site created - $(date +"%m-%d-%Y")" -- ${forUser}@leepfrog.com < $tmpFile
	fi

	[[ $(IsNumeric $exitCode) != true ]] && exitCode=0
	if [[ $secondaryMessagesOnly == true ]]; then
		secondaryMessagesOnly=false
		return 0
	else
		trap - EXIT SIGHUP
		#set +eE
		exit $exitCode
	fi
} #Goodbye
export -f Goodbye

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
