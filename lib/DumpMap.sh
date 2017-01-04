## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.7" # -- dscudiero -- 01/04/2017 @ 13:41:08.46
#==================================================================================================
# Dump an hash table
# DumpMap <msgLevel> HashArrayDef
# e.g. DumpMap "$(declare -p variableMap)"
# e.g. DumpMap 1 "$(declare -p variableMap)"
#==================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function DumpMap {
	local dumpMapCtr dumpMapKeyStr dumpMapMaxKeyWidth

	## If we have 2 parms passed the parse off the msgLevel
		if [[ ${#*} -eq 2 ]]; then
			local dumpLevel=$1; shift
			[[ $dumpLevel -gt $verboseLevel ]] && return 0
		fi

	## Get the name of the map we are printing, make a copy of the array
		local dumpMapName=$(cut -d'=' -f1 <<< $*);
		dumpMapName=$(cut -d' ' -f3 <<< $dumpMapName)
		eval "declare -A dumpMap="${1#*=}

	## Get the max width of the keys
		for dumpMapCtr in "${!dumpMap[@]}"; do [[ ${#dumpMapCtr} -gt $dumpMapMaxKeyWidth ]] && dumpMapMaxKeyWidth=${#dumpMapCtr}; done;

	## Print the map
		echo; echo "Map '$dumpMapName':"
		for dumpMapCtr in "${!dumpMap[@]}"; do
			dumpMapKeyStr="${dumpMapCtr}$(PadChar ' ')";
			echo -e "\tkey: ${dumpMapKeyStr:0:$dumpMapMaxKeyWidth}  value: '${dumpMap[$dumpMapCtr]}'";
		done;
		echo

	return 0
} #DumpMap
export -f DumpMap

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:20 CST 2017 - dscudiero - General syncing of dev to prod
