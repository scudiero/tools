## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.5" # -- dscudiero -- 11/07/2016 @ 14:47:50.68
#===================================================================================================
# Set the noglob value
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function SetFileExpansion {
	local mode=$1
	local prev

	if [[ $mode == '' ]]; then
		if [[ ${#previousFileExpansionSettings[@]} -eq 0 ]]; then
			previousFileExpansionSettings+=($(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2))
			return 0
		fi

		## Toggle value
		prev=${previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]}
		unset previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]
		[[ $prev == 'on' ]] && set -f || set +f
		return 0
	fi

	previousFileExpansionSettings+=($(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2))
	[[ $(Lower $mode) == 'on' ]] && set +f || set -f

	return 0
} #SetFileExpansion
export -f SetFileExpansion

#===================================================================================================
# Check-in Log
#===================================================================================================

