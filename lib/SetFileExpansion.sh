## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.15" # -- dscudiero -- Fri 10/27/2017 @ 14:42:07.41
#===================================================================================================
# Set the noglob value
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SetFileExpansion {
	local mode=$1 lastVal

	if [[ $mode == 'on' ]]; then
		previousFileExpansionSettings+=('on')
	elif [[ $mode == 'off' ]]; then
		previousFileExpansionSettings+=('off')
	else
		if [[ ${#previousFileExpansionSettings[@]} -eq 0 ]]; then
			previousFileExpansionSettings+=("$(set -o | grep noglob | cut -d' ' -f3)")
		else
			lastVal=${previousFileExpansionSettings[-1]}
			unset 'previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]'
			[[ $lastVal == 'on' ]] && set +o noglob || set -o noglob
		fi
	fi
echo ${previousFileExpansionSettings[*]}
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
