## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.39" # -- dscudiero -- Wed 08/15/2018 @ 11:58:37
#===================================================================================================
## Make sure the user really wants to do this
## If the first argument is 'loop' then loop back to self if user responds with 'n'
#===================================================================================================
# Copyright 2106 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function VerifyContinue {
	[[ $secondaryMessagesOnly == true ]] && return 0
	Import 'ArrayRef'

	local mode="$1"
	local verifyPrompt="$2"
	if [[ $verifyPrompt == '' ]]; then verifyPrompt="$mode"; mode='loop'; fi
	local arg tempStr

	Msg; Msg "$verifyPrompt"
	if [[ ${#verifyArgs[@]} -gt 0 ]]; then
		#[[ $allItems == true ]] && verifyArgs+=("Auto process all items:$allItems")
		[[ $force == true ]] && verifyArgs+=("Force execution:$force")

		local maxArgWidth arg argStr argVal argL argValL tmpStr iii	
		for argStr in "${verifyArgs[@]}"; do tmpStr=${argStr%%:*}; [[ ${#tmpStr} -gt $maxArgWidth ]] && maxArgWidth=${#tmpStr}; done
		dots=$(PadChar '.' $maxArgWidth); (( maxArgWidth = $maxArgWidth + 3 )); blanks=$(PadChar ' ' $maxArgWidth)

		for argStr in "${verifyArgs[@]}"; do
			arg="${argStr%%:*}"; argL="${arg,,[a-z]}"; argVal="${argStr##*:}"; argValL="${argVal,,[a-z]}";
			[[ ${arg:0:1} == '!' ]] && tmpStr="${arg:1}" || tmpStr="${arg}${dots}";
			[[ ${tmpStr:0:1} == '^' ]] && { tmpStr=${tmpStr:0:$maxArgWidth-${#tabStr}+1}; } || { tmpStr=${tmpStr:0:$maxArgWidth}; }
			if [[ ${argL:${#argL}-3:${#argL}} == '(s)' ]]; then
				Msg "^$(ColorK "${tmpStr}")" 
				for iii in $(IndirKeys $argVal); do
				    Msg "^${blanks}$(IndirVal $argVal $iii)"
				done
			else
				[[ ${argL:0:7} == 'warning' ]] && Msg "^$(ColorW "${tmpStr}")${argVal}" || Msg "^$(ColorK "${tmpStr}")${argVal}" 
			fi
		done
		[[ $testMode == true || $informationOnlyMode == true || -n "$DOIT" ]] && echo
		[[ $testMode == true ]] && Warning 0 1 "*** Running in Test Mode ***"
		[[ $informationOnlyMode == true ]] && Warning 0 1 "*** Information only mode, no data will be modified ***"
		[[ -n "$DOIT" ]] && Warning 0 1 "The 'DOIT' flag is turned off, changes not committed"
	fi

	if [[ $verify == true && $quiet != true && $go != true ]]; then
		unset ans
		inVerifyContinue=true
		[[ $informationOnlyMode == true ]] && verifyContinueDefault='Yes'
		Prompt ans "\n'Yes' to continue, 'No' to exit" 'Yes No / InformationMode Verbose' "$verifyContinueDefault"; ans="${ans:0:1}"; ans=${ans,,[a-z]}
		inVerifyContinue=false
		if [[ $ans == "i" ]]; then
			informationOnlyMode=true
			Info 0 1 "Setting Information only mode, no data will be saved"
		elif [[ $ans == 'v' ]]; then
			verboseLevel=1
			Info 0 1 "Setting Verbose level to 1"
		elif [[ $ans != 'y' ]]; then
			Goodbye 'x'
		fi
	else
		Msg "^$(ColorI "Info -- ")'NoPrompt' flag was set, continuing..."
	fi
	Msg
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
## 09-25-2017 @ 12.26.42 - ("2.0.19")  - dscudiero - Switch to use Msg
## 09-25-2017 @ 16.13.26 - ("2.0.21")  - dscudiero - use Msg
## 09-26-2017 @ 15.36.58 - ("2.0.22")  - dscudiero - Fix problem displaying the information lines
## 10-04-2017 @ 16.56.48 - ("2.0.23")  - dscudiero - If informationOnly mode then set default answer to yes
## 03-13-2018 @ 08:29:40 - 2.0.25 - dscudiero - Remove 'merge' load option, not really necessary
## 03-13-2018 @ 11:14:30 - 2.0.26 - dscudiero - Fix if conditional checking response to prompt
## 03-23-2018 @ 16:52:29 - 2.0.27 - dscudiero - Msg3 -> Msg
## 05-08-2018 @ 13:27:21 - 2.0.28 - dscudiero - Remove the 'Auto process all items message
## 05-22-2018 @ 08:39:47 - 2.0.32 - dscudiero - Add displaying array values vertically
## 06-19-2018 @ 11:19:41 - 2.0.32 - dscudiero - Add formatting for title lines and align elements with leading tabs
## 08-15-2018 @ 11:59:17 - 2.0.39 - dscudiero - Add additional messaging if data will not be committed
