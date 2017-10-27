## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.29" # -- dscudiero -- Fri 10/27/2017 @ 16:54:01.58
#===================================================================================================
# Set the noglob value
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SetFileExpansion {
	Import "StringFunctions"
	local mode=$1

	if [[ $mode == 'on' ]]; then
		set +o noglob
		previousFileExpansionSettings+=('on')
	elif [[ $mode == 'off' ]]; then
		set -o noglob
		previousFileExpansionSettings+=('off')
	else
		if [[ ${#previousFileExpansionSettings[@]} -eq 0 ]]; then
			local current=$(set -o | grep noglob)
			[[ $(Trim "${current##* }") == 'on' ]] && previousFileExpansionSettings+=('off') || previousFileExpansionSettings+=('on')
		else
			[[ ${previousFileExpansionSettings[@]:(-1)} == 'on' ]] && set +o noglob || set -o noglob
			unset 'previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]'
		fi
	fi
	#echo ${previousFileExpansionSettings[*]}
	return 0
} #SetFileExpansion
export -f SetFileExpansion

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:25 CST 2017 - dscudiero - General syncing of dev to prod
## 05-18-2017 @ 09.31.34 - ("2.0.7")   - dscudiero - Switch to use set -o for clarification
## 09-28-2017 @ 16.03.22 - ("2.0.14")  - dscudiero - Performance tweaks
## 10-27-2017 @ 14.42.40 - ("2.0.15")  - dscudiero - Refactor to make simpler
## 10-27-2017 @ 14.51.19 - ("2.0.19")  - dscudiero - Cosmetic/minor change
## 10-27-2017 @ 16.54.24 - ("2.0.29")  - dscudiero - Add StringFunctions to import list
