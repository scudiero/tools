## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:33:18.77
#=================================================================================================
## Dump an array, pass in the name of the array as follows
# DumpArray <msgLevel> keysArray[@]
# e.g. DumpArray keysArray[@]
# e.g. DumpArray 1 keysArray[@]
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function DumpArray {

	## If we have 2 parms passed the parse off the msgLevel
		if [[ ${#*} -eq 2 ]]; then
			local dumpLevel=$1; shift
			[[ $dumpLevel -gt $verboseLevel ]] && return 0
		fi

	declare -a argArray=("${!1}")
	echo "Array: $1"
	local total=${#argArray[*]}
	local i
	for (( i=1; i<=$(( $total -1 )); i++ )); do
		echo -e "\t[$i] = >${argArray[$i]}<"
	done
	return 0
} # DumpArray
export -f DumpArray

#===================================================================================================
# Check-in Log
#===================================================================================================

