## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.83" # -- dscudiero -- 01/18/2017 @ 15:21:25.17
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
		#[[ $(type -t $FUNCNAME-local ) == 'function' ]] && $FUNCNAME-local "$exitCode"

	## Cleanup temp files
		[[ -f $tmpFile ]] && rm -f $tmpFile

	## Exit Process
	case "$(Lower "$exitCode")" in
		quiet)
			[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Remove' $myLogRecordIdx
			kill -1 $$
			exitCode=0
			;;
		quickquit|x)
			[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Remove' $myLogRecordIdx
			Msg2 "\n*** Stopping at user's request ***\n"
			kill -1 $$
			exitCode=0
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
							Msg2
							PrintBanner "Processing Summary"
							Msg2
							for msg in "${summaryMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#summaryMsgs[@]}
						fi
						if [[ ${#warningMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
							Msg2
							PrintBanner "${#warningMsgs[@]} warning message(s) were issued during processing"
							Msg2
							for msg in "${warningMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#warningMsgs[@]}
						fi
						if [[ ${#errorMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
							Msg2
							PrintBanner "${#errorMsgs[@]} error message(s) were issued during processing"
							Msg2
							for msg in "${errorMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#errorMsgs[@]}
						fi
						[[ $numMsgs -gt 0 ]] && printf "\n$(PadChar)\n"
						Alert 'on'
						Msg2

					fi
					[[ $DOIT != '' ]] && Msg2 "$(ColorE "*** The 'DOIT' flag is turned off, changes not committed ***")"
					[[ $informationOnlyMode == true ]] && Msg2 "$(ColorE "*** Information only mode, no data updated ***")"
					if [[ $exitCode -eq 0 ]]; then
						Msg2 "$(ColorK "${myName}") $(ColorI " -- $additionalText completed successfully.")"
					else
						Msg2 "$(ColorK "${myName}") $(ColorE " -- $additionalText completed with errors, exit code = $exitCode")\a"
					fi
					[[ $logFile != '/dev/null' ]] && Msg2 "Additional details may be found in: \n^'$logFile'"
					Msg2 "$date (Elapsed time: $elapTime)"
					[[ $TERM == 'dumb' ]] && echo
					Msg2 "$(PadChar)"
				fi #not quiet noHeaders secondaryMessagesOnly
			[[ $alert == true ]] && Alert
	esac

	## Write end record to db log
		[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'Update' $myLogRecordIdx 'exitCode' "$exitCode"

[[ $userName == 'dscudiero' ]] && dump logInDb myLogRecordIdx

		[[ $myLogRecordIdx != '' && $noLogInDb != true ]] && ProcessLogger 'End' $myLogRecordIdx

	## If secondaryMessagesOnly is true then we are in a sub shell so just return, otherwise exit
	[[ $secondaryMessagesOnly == true ]] && secondaryMessagesOnly=false && return 0
	set +eE
	trap - ERR
	[[ $(IsNumeric $exitCode) != true ]] && exitCode=0
	exit $exitCode

} #Goodbye
export -f Goodbye

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:40 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan 11 07:50:53 CST 2017 - dscudiero - Switch to use ProcessLogger
## Thu Jan 19 07:13:36 CST 2017 - dscudiero - Add debug statement
