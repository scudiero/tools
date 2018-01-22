## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.25" # -- dscudiero -- Mon 01/22/2018 @ 10:13:06.89
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

	Msg3; Msg3 "$verifyPrompt"
	if [[ ${#verifyArgs[@]} -gt 0 ]]; then
		[[ $allItems == true ]] && verifyArgs+=("Auto process all items:$allItems")
		[[ $force == true ]] && verifyArgs+=("Force execution:$force")

		local maxArgWidth
		for arg in "${verifyArgs[@]}"; do tempStr=$(echo $arg | cut -d':' -f1); [[ ${#tempStr} -gt $maxArgWidth ]] && maxArgWidth=${#tempStr}; done
		dots=$(PadChar '.' $maxArgWidth)
		for arg in "${verifyArgs[@]}"; do
			tempStr="$(echo $arg | cut -d':' -f1)"
			local token1="$(echo $arg | cut -d':' -f1)" ; token1=${token1,,[a-z]}
			[[ $token1 == 'warning' ]] && color='ColorW' || color='ColorK'
			tempStr="${tempStr}${dots}"
			tempStr=${tempStr:0:$maxArgWidth+3}
			Msg3 "^$(eval "$color \"${tempStr}\"")$(echo $arg | cut -d':' -f2-)"
		done
		[[ $testMode == true ]] && Msg3 "^$(ColorE "*** Running in Test Mode ***")"
		[[ $informationOnlyMode == true ]] && Msg3 "^$(ColorE "*** Information only mode, no data will be modified ***")"
	fi

	if [[ $verify == true && $quiet != true && $go != true ]]; then
		unset ans
		inVerifyContinue=true
		[[ $informationOnlyMode == true ]] && verifyContinueDefault='Yes'
		Prompt ans "\n'Yes' to continue, 'No' to exit" 'Yes No' "$verifyContinueDefault"; ans="${ans:0:1}"; ans=${ans,,[a-z]}
		inVerifyContinue=false
		if [[ $ans == "i" ]]; then
			informationOnlyMode=true
		elif [[ $ans != 'y' ]]; then
			Goodbye 'x'
		fi
	else
		Msg3 "^$(ColorI "Info -- ")'NoPrompt' flag was set, continuing..."
	fi
	Msg3
	return 0
} #VerifyContinue
export -f VerifyContinue

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:38 CST 2017 - dscudiero - General syncing of dev to prod
## 04-13-2017 @ 10.35.46 - ("2.0.12")  - dscudiero - Add ability to specify a default value
## 04-25-2017 @ 08.38.30 - ("2.0.13")  - dscudiero - Skip prompt if go=true
## 08-30-2017 @ 15.15.40 - ("2.0.16")  - dscudiero - use ColorW for warning messages
## 09-25-2017 @ 12.26.42 - ("2.0.19")  - dscudiero - Switch to use Msg3
## 09-25-2017 @ 16.13.26 - ("2.0.21")  - dscudiero - use Msg3
## 09-26-2017 @ 15.36.58 - ("2.0.22")  - dscudiero - Fix problem displaying the information lines
## 10-04-2017 @ 16.56.48 - ("2.0.23")  - dscudiero - If informationOnly mode then set default answer to yes
