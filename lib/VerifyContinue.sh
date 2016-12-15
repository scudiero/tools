## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.10" # -- dscudiero -- 11/07/2016 @ 14:59:40.57
#===================================================================================================
## Make sure the user really wants to do this
## If the first argument is 'loop' then loop back to self if user responds with 'n'
#===================================================================================================
# Copyright 2106 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function VerifyContinue {
	[[ $secondaryMessagesOnly == true ]] && return 0
	local mode="$1"
	local verifyPrompt="$2"
	if [[ $verifyPrompt == '' ]]; then verifyPrompt="$mode"; mode='loop'; fi
	local arg tempStr

	Msg2; Msg2 "$verifyPrompt"
	if [[ ${#verifyArgs[@]} -gt 0 ]]; then
		[[ $allItems == true ]] && verifyArgs+=("Auto process all items:$allItems")
		[[ $force == true ]] && verifyArgs+=("Force execution:$force")

		local maxArgWidth
		for arg in "${verifyArgs[@]}"; do tempStr=$(echo $arg | cut -d':' -f1); [[ ${#tempStr} -gt $maxArgWidth ]] && maxArgWidth=${#tempStr}; done
		dots=$(PadChar '.' $maxArgWidth)
		for arg in "${verifyArgs[@]}"; do
			tempStr="$(echo $arg | cut -d':' -f1)"
			tempStr="${tempStr}${dots}"
			tempStr=${tempStr:0:$maxArgWidth+3}
			Msg2 '-,-,+1' "$(ColorK ${tempStr})$(echo $arg | cut -d':' -f2-)"
		done
		[[ $testMode == true ]] && Msg2 '-,-,1' "$(ColorE "*** Running in Test Mode ***")"
		[[ $informationOnlyMode == true ]] && Msg2 '-,-,1' "$(ColorE "*** Information only mode ***")"
	fi

	if [[ $verify == true && $quiet != true ]]; then
		unset ans
		inVerifyContinue=true
		Prompt ans "\n'Yes' to continue, 'No' to exit" 'Yes No'; ans=$(Lower ${ans:0:1})
		inVerifyContinue=false
		if [[ $ans == "i" ]]; then
			informationOnlyMode=true
		elif [[ $ans != 'y' ]]; then
			Goodbye 'x'
		fi
	else
		Msg2 "^$(ColorI "Info -- ")'NoPrompt' flag was set, continuing..."
	fi
	Msg2
	return 0
} #VerifyContinue
export -f VerifyContinue

#===================================================================================================
# Check-in Log
#===================================================================================================
