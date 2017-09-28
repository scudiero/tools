## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.14" # -- dscudiero -- Thu 09/28/2017 @ 15:19:50.74
#===================================================================================================
# Set the noglob value
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SetFileExpansion {
	local mode=$1

	if [[ -z $mode ]]; then
		if [[ ${#previousFileExpansionSettings[@]} -eq 0 ]]; then
			[[ -z ${-//[^f]/} ]] && previousFileExpansionSettings+=('on') || previousFileExpansionSettings+=('off')
		else
			local prev=${previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]}
			unset previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]
			[[ $prev == 'on' ]] && set -o noglob || set +o noglob
		fi
	else
		[[ -z ${-//[^f]/} ]] && previousFileExpansionSettings+=('on') || previousFileExpansionSettings+=('off')
		[[ $mode == 'on' || $mode == 'ON' || $mode == 'On' ]] && set +o noglob || set -o noglob
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
