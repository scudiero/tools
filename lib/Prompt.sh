## XO NOT AUTOVERSION
#===================================================================================================
# version="2.1.24" # -- dscudiero -- Wed 10/11/2017 @ 11:27:50.76
#===================================================================================================
# Prompt user for a value
# Usage: varName promptText [validationList] [defaultValue] [autoTimeoutTimer]
# varName in the caller will be set to the response
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Prompt {
	includes='Msg3 Dump VerifyPromptVal SelectClient'
	Import "$includes"

	declare promptVar=$1; shift || true
	declare promptText=$1; shift || true
	declare validateList=$1; shift || true
	declare defaultVal=$1; shift || true
	[[ $defaultVal == '-' || $defaultVal == 'n/a' || $defaultVal == 'N/A' ]] && unset defaultVal
	declare timeOut=${1:-0}; shift || true
	declare timerPrompt=${1:-"Timed prompt, please press enter to provide a response, otherwise processing will continue in"}; shift || true
	[[ ${promptText:0:1} == '^' ]] && timerPrompt="^$timerPrompt"
	declare timerInterruptPrompt=${1:-"$promptText"}; shift || true
	dump -2 -r ; dump -2 -l promptVar promptText defaultVal validateList validateListString timeOut timerPrompt timerInterruptPrompt

	if [[ $batchMode == true ]] || [[ $TERM != 'xterm' && $TERM != 'screen' ]]; then
		if [[ -z $defaultVal ]]; then
			[[ $batchMode == true ]] && Terminate "$FUNCNAME: batchMode flag is set and no defaultVal specified, cannot continue\n\t\tVar: '$promptVar', Prompt: '$promptText'"
			[[ $TERM != 'xterm' && $TERM != 'screen' ]] && \
				Terminate "$FUNCNAME: TERM ($TERM) is not 'xterm' or 'screen' and no defaultVal specified, cannot continue\n\t\tVar: '$promptVar', Prompt: '$promptText'"
		else
			eval $promptVar=\"$defaultVal\"
			Note 0 1 "'batchMode is set, using selected value of '$defaultVal' for 'client'"
			return 0
		fi
	fi

	declare validateListString="$(echo $validateList | tr " " ",")"
	if [[ -n $defaultVal ]]; then
		validateListString=",$validateListString,"
		validateListString=$(sed "s/,${defaultVal},/,\\${colorDefaultVal}${defaultVal}\\${colorDefault},/" <<< "$validateListString")
		validateListString="${validateListString:1:${#validateListString}-2}"
	fi

	if [[ $inVerifyContinue != true ]]; then
		[[ -n $validateListString ]] && validateListString="$validateListString, or 'X' to quit" || validateListString="'X' to quit"
	fi

	[[ -z $promptText ]] && promptText="Please specify a value for '$promptVar'"
	[[ -n $validateListString ]] && promptText="$promptText ($validateListString)"
	dump -2 -r ; dump -2 -l promptVar promptText defaultVal validateList validateListString timeOut timerPrompt timerInterruptPrompt inVerifyContinue

	local respFirstChar rc readTimeOutOpt
	local numTabs=0
	IFS=' ' read -ra validValues <<< $(echo $validateList | tr "," " ")
	[[ $timeOut -ne 0 && -n $timeOut ]] && readTimeOutOpt="-t $timeOut" || unset readTimeOutOpt

	#===================================================================================================
	## Main
	## Retrieve value for the variable from the callers address space, verify if not null and verify is on
	response=\$$promptVar
	response=$(eval echo $response)

	#printf "%s = >%s<\n" promptVar "$promptVar" response "$response" validateList "$validateList" >> ~/stdout.txt
	local loop=true hadValue=true timedRead=true promptTextTabs
	[[ -z $timeOut || $timeOut -eq 0 ]] && timeOut=${maxReadTimeout:-3600} && timedRead=false

	#local verifyMsg;
	unset verifyMsg
	until [[ $loop != true ]]; do
		while [[ -z $response ]]; do
			hadValue=false
			numTabs=$(grep -o '\^' <<< "$promptText" | wc -l)
			[[ $numTabs -ne 0 ]] && promptTextTabs="^${promptText%^*}"
			if [[ $verify != false ]]; then
				[[ -n $promptText ]] && promptText="$(sed "s/\^/$tabStr/g" <<< $promptText)"
				[[ -n $timerPrompt ]] && timerPrompt="$(sed "s/\^/$tabStr/g" <<< $timerPrompt)"
				[[ -n $timerInterruptPrompt ]] && timerInterruptPrompt="$(sed "s/\^/$tabStr/g" <<< $timerInterruptPrompt)"
					dump -2 -t promptText timedRead timerPrompt timerInterruptPrompt
					if [[ $timedRead == false ]]; then
					 	echo -en "$promptText > "
						read response; rc=$?
					else
						[[ -n $promptText ]] && echo -e "$promptText"
						for ((tCntr=0; tCntr<$timeOut; tCntr++)); do
							[[ -n $defaultVal ]] && echo -en "$timerPrompt $(ColorK "$((timeOut - tCntr))") seconds using the default value: $(ColorK "'$defaultVal'")\r" || \
													echo -en "$timerPrompt $(ColorK "$((timeOut - tCntr))") seconds\r"
							read -t 1 response; rc=$?
							if [[ $rc -eq 0 ]]; then
								if [[ -z $response ]]; then
									echo -en "$timerInterruptPrompt > "
									read response
								else
									[[ $response = 'x' ]] && unset response && break
								fi
								break
							fi
							[[ $rc -gt 0 && $tCntr -ge $maxReadTimeout ]] && echo && Terminate "Read operation timed out after the maximum time of $maxReadTimeout seconds" && exit
						done ; echo
						if [[ -z $response ]]; then
							[[ -n $defaultVal ]] && Note 0 1 "Read timed out, using default value '$defaultVal' for '$promptVar'"
							eval $promptVar=\"$defaultVal\"
							return 0
						fi
					fi
			else
				[[ -n "$defaultVal" ]] && response="$defaultVal" || Terminate "No Prompt is active and no default value specified for '$promptVar'"
			fi #[[ $verify != false ]]
			[[ $(Lower ${response}) == 'x' ]] && Goodbye 'x'
			if [[ -z $response && -n $defaultVal ]]; then
				eval $promptVar=\"$defaultVal\"
				[[ $defaultValueUseNotes == true && -n $defaultVal ]] && Note 0 1 "Using default value of '$defaultVal' for '$promptVar'"
				return 0
			fi
			[[ -n $response && $validateList == '*any*' ]] && eval $promptVar=\"$response\" && return 0
			[[ $validateList == '*optional*' ]] && eval $promptVar=\"$response\" && return 0
			[[ -z $response && $validateList == '*optional*' ]] && eval unset $promptVar && return 0
			[[ -n $response && $noCheck == true ]] && eval $promptVar=\"$response\" && return 0
		done
		dump -2 -l response

		if [[ "$promptVar" == 'client' && $response == '?' ]]; then
			Info 0 1 "Gathering data..."
			SelectClient 'response'
			[[ $secondaryMessagesOnly != true && $defaultValueUseNotes == true ]] && Msg3 && Note 0 1 "Using selected value of '$selectResp' for 'client'"
			eval $promptVar=\"$response\"
			loop=false

		elif [[  "$promptVar" == 'client' && $response == 'internal' ]]; then
			eval $promptVar=\"$response\"
			loop=false

		elif [[ "$validateList" == '' && "$promptVar" != 'client' && "${promptVar:0:7}" != 'product' ]]; then
			eval $promptVar=\"$response\"
			loop=false
		else
			unset verifyMsg
			VerifyPromptVal
			if [[ -n $verifyMsg && $verifyMsg != true ]]; then
				[[ $hadValue == true ]] && echo "Specified value for '$promptVar' is '$response'"
				if [[ $numTabs -gt 0 ]]; then
					local cntr
					for ((cntr=1; cntr<$numTabs; cntr++)); do
						verifyMsg="${tabStr}${verifyMsg}"
					done
				fi
				echo -e "$verifyMsg"
				unset response
				[[ $verify != true ]] && Terminate "No Prompt is active and errors reported during value checking" #&& loop=false && break
			else
				## Map abbreviated response to full response token from the validation list
				if [[ "$promptVar" != 'client' ]]; then
					local answer=$(Lower $response)
					local length=${#answer}
					for i in "${validValues[@]}"; do
						local checkStr=$(Lower ${i:0:$length})
						[[ $answer == "$checkStr" ]] && response=$i && break
					done
				fi
				eval $promptVar=\"$response\"
				[[ $hadValue == true && $secondaryMessagesOnly != true && $defaultValueUseNotes == true ]] && Note 0 1 "Using specified value of '$response' for '$promptVar'"
				loop=false
			fi
		fi #[[  "$promptVar" == 'client' && $response == '?' ]]
	done
	[[ $hadValue != true && -n $logFile ]] && echo -e "\n^$FUNCNAME: Using specified value of '$response' for '$promptVar'" >> $logFile
	return 0
} #Prompt
export -f Prompt

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:10 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Mar 16 10:57:45 CDT 2017 - dscudiero - Add messaging if there is a timeout value specified
## Thu Mar 16 10:59:16 CDT 2017 - dscudiero - General syncing of dev to prod
## Thu Mar 16 12:14:31 CDT 2017 - dscudiero - Fixed a problem with timeouts not timeing out, added tabbing to the timeout text
## 05-17-2017 @ 10.50.03 - ("2.1.0")   - dscudiero - Update the timed prompt support to do a count down timer
## 05-22-2017 @ 10.55.01 - ("2.1.5")   - dscudiero - added x out of timed read, fixed bug when verify is off
## 05-31-2017 @ 07.31.49 - ("2.1.6")   - dscudiero - Terminate if TERM != 'xterm'
## 05-31-2017 @ 07.49.50 - ("2.1.11")  - dscudiero - if term is not xterm or in batchMode and we have a default then use the default value
## 06-01-2017 @ 09.16.57 - ("2.1.12")  - dscudiero - Also check for TERM=screen
## 06-07-2017 @ 09.34.32 - ("2.1.16")  - dscudiero - Fix problem not getting primary prompt text in timed mode
## 08-24-2017 @ 16.32.08 - ("2.1.17")  - dscudiero - Change prompt text when a timed read times out
## 09-25-2017 @ 08.42.47 - ("2.1.19")  - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 09.01.55 - ("2.1.21")  - dscudiero - Switch to Msg3
## 09-28-2017 @ 08.22.09 - ("2.1.22")  - dscudiero - Remove the debug stuss
## 10-04-2017 @ 16.26.10 - ("2.1.23")  - dscudiero - Switch to use Msg3
## 10-11-2017 @ 11.28.21 - ("2.1.24")  - dscudiero - Fix bug logging default value selection to the log file
