## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.64" # -- dscudiero -- 12/13/2016 @ 15:04:48.03
#===================================================================================================
# Prompt user for a value
# Usage: varName promptText [validationList] [defaultValue] [autoTimeoutTimer]
# varName in the caller will be set to the response
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Prompt {
	declare promptVar=$1
	declare promptText=$2
	declare validateList=$3
	declare defaultVal=$4
	declare timeOut=${5:-0}
	declare validateListString="$(echo $validateList | tr " " ",")"
	if [[ $defaultVal != '' ]]; then
		validateListString=",$validateListString,"
		validateListString=$(sed "s/,${defaultVal},/,\\${colorDefaultVal}${defaultVal}\\${colorDefault},/" <<< "$validateListString")
		validateListString="${validateListString:1:${#validateListString}-2}"
	fi

	if [[ $inVerifyContinue != true ]]; then
		[[ $validateListString != '' ]] && validateListString="$validateListString, or 'X' to quit" || validateListString="'X' to quit"
	fi

	[[ $promptText == '' ]] && promptText="Please specify a value for '$promptVar'"
	[[ $validateListString != '' ]] && promptText="$promptText ($validateListString)"
	dump -2 -r ; dump -2 -l promptVar response promptText defaultVal validateList validateListString inVerifyContinue

	local respFirstChar rc readTimeOutOpt
	local numTabs=0
	IFS=' ' read -ra validValues <<< $(echo $validateList | tr "," " ")
	[[ $timeOut -ne 0 && $timeOut != '' ]] && readTimeOutOpt="-t $timeOut" || unset readTimeOutOpt

	#===================================================================================================
	## Main
	## Retrieve value for the variable from the callers address space, verify if not null and verify is on
	response=\$$promptVar
	response=$(eval echo $response)

	#printf "%s = >%s<\n" promptVar "$promptVar" response "$response" validateList "$validateList" >> ~/stdout.txt
	local loop=true
	local hadValue=true

	#local verifyMsg;
	unset verifyMsg
	until [[ $loop != true ]]; do
		while [[ $response == '' ]]; do
			hadValue=false
			let numTabs=$(grep -o "^" <<< "$promptText" | wc -l)
			promptText="$(sed "s/\^/$tabStr/g" <<< $promptText)"
			if [[ $verify != false ]]; then
				echo -n -e "$promptText > "
				ProtectedCall "read $readTimeOutOpt response";
				if [[ $rc -ne 0 ]]; then
					echo
					Msg2 $NT1 "Read timed out, using default value: '$defaultVal'"
					eval $promptVar=\"$defaultVal\"
					return 0
				fi
			fi
			[[ $(Lower ${response}) == 'x' ]] && Goodbye 'x'
			if [[ $response == '' && $defaultVal != '' ]]; then
				eval $promptVar=\"$defaultVal\"
				[[ $defaultValueUseNotes == true ]] && Msg2 $NT1 "Using default value of '$defaultVal' for '$promptVar'"
				return 0
			fi
			[[ $response != '' && $validateList == '*any*' ]] && eval $promptVar=\"$response\" && return 0
			[[ $validateList == '*optional*' ]] && eval $promptVar=\"$response\" && return 0
			[[ $response == '' && $validateList == '*optional*' ]] && eval unset $promptVar && return 0
			[[ $response != '' && $noCheck == true ]] && eval $promptVar=\"$response\" && return 0
		done
		dump -2 -l response

		if [[ "$promptVar" == 'client' && $response == '?' ]]; then
			Msg2 "IT Gathering data..."
			SelectClient 'response'
			[[ $secondaryMessagesOnly != true && $defaultValueUseNotes == true ]] && Msg2 && Msg2 $NT1 "Using selected value of '$selectResp' for 'client'"
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
			if [[ $verifyMsg != '' && $verifyMsg != true ]]; then
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
				[[ $hadValue == true && $secondaryMessagesOnly != true && $defaultValueUseNotes == true ]] && Msg2 $NT1 "Using specified value of '$response' for '$promptVar'"
				loop=false
			fi
		fi #[[  "$promptVar" == 'client' && $response == '?' ]]
	done
	[[ $hadValue != true && $logFile != '' ]] && Msg2 "\n^$FUNCNAME: Using specified value of '$response' for '$promptVar'" >> $logFile
	return 0
} #Prompt
export -f Prompt

#===================================================================================================
# Check-in Log
#===================================================================================================
