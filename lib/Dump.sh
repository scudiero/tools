## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.11" # -- dscudiero -- Mon 04/17/2017 @ 12:16:50.54
#===================================================================================================
# Quick dump a list of variables
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#==================================================================================================
dumpFirstWrite=true
function Dump {
	declare lowervName
	local singleLine=false
	local quit=false
	local pause=false
	local logit=false
	local tabs=''
	local dumpLogFile=$HOME/stdout.txt
	local vName vVal prefix

	PushSettings "$FUNCNAME"
	set +xv # Turn off trace

	writeIt() {
		local writeItVar="$1"
		local writeItVal="$2"
		local writeItOutStr
		local sep='\n'
		[[ $singleLine -eq 1 ]] && sep=', '
		local prefix=''
		[[ $caller != 'source' ]] && prefix="$(ColorV "$myName.$caller")."
		local varStr="$(ColorN "$writeItVar")"

		if [[ $logit == false ]]; then
			[[ $writeItVar != '' ]] && writeItOutStr="${prefix}${varStr} = >${writeItVal}<${sep}" || writeItOutStr="$sep"
			echo -en "${tabs}${writeItOutStr}";
		elif [[ -w $dumpLogFile ]]; then
			[[ $dumpFirstWrite == true ]] && echo $(date) >> $dumpLogFile
			dumpFirstWrite=dumpLogFile
			[[ $writeItVar != '' ]] && writeItOutStr="${prefix}${writeItVar} = >${writeItVal}<${sep}" || writeItOutStr="$sep"
			echo -en "$tabs$writeItOutStr" >> $dumpLogFile
		fi
		return 0
	} #writeIt

	## Loop through arguments
		local debugVarArray=($*)
		for debugVar in ${debugVarArray[@]};do
			vName=$debugVar; lowervName=$(Lower $vName)
			if [[ ${vName:0:1} == '-' ]]; then
				if [[ $lowervName == '-r' ]]; then
					echo > $dumpLogFile
				elif [[ $lowervName == '-s' ]]; then
					singleLine=true
				elif [[ $lowervName == '-l' ]]; then
					logit=true
				elif [[ $lowervName == '-t' ]]; then
					tabs="\t"$tabs
				elif [[ $lowervName == '-q' ]]; then
					quit=true
				elif [[ $lowervName == '-p' ]]; then
					pause=true
				elif [[ $lowervName == '-n' ]]; then
					writeIt;
				elif [[ $lowervName == '-m' ]]; then
					writeIt 'msg'
				else
					local re='^[0-9]+$'
					if [[ ${vName:1} =~ $re ]]; then
						local msgLevel=${vName:1}
						[[ $msgLevel -gt $verboseLevel ]] && return 0
					fi
				fi
			else
				vVal=${!vName}
				caller=${FUNCNAME[1]}
				[[ $(Lower $caller) == 'dump' ]] && caller=${FUNCNAME[2]}
				writeIt $vName "$vVal"
			fi
		done

	## Write it out and or quit
		if [[ $singleLine == true ]]; then vName=''; writeIt; fi
		[[ $quit == true ]] && Quit
		[[ $pause == true ]] && Msg2 && Pause '*** Dump paused script execution, press enter to continue ***'


	PopSettings "$FUNCNAME"
	return 0

} #Dump

function dump { Dump $* ; }
export -f Dump
export -f dump

#===================================================================================================
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
function dumparray { DumpArray $* ; }
export -f dumparray

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
function dumpmap { DumpMap $* ; }
export -f dumpmap
function DumpHash { DumpMap $* ; }
export -f DumpHash
function dumphash { DumpMap $* ; }
export -f dumphash

#===================================================================================================
# Checkin Log
#===================================================================================================
## Wed Jan  4 12:25:20 CST 2017 - dscudiero - turn off tracing
## Wed Jan  4 13:53:17 CST 2017 - dscudiero - General syncing of dev to prod
## 04-17-2017 @ 07.41.52 - ("2.0.9")   - dscudiero - move in other dump functions
## 04-17-2017 @ 07.48.09 - ("2.0.10")  - dscudiero - Fix problem defining alternate function names
## 04-17-2017 @ 12.16.56 - ("2.0.11")  - dscudiero - General syncing of dev to prod
