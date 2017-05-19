## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.40" # -- dscudiero -- Fri 05/19/2017 @  8:54:00.97
#===================================================================================================
# Quick dump a list of variables
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#==================================================================================================
dumpFirstWrite=true
function Dump {
	declare lowervName
	local singleLine=false quit=false pause=false logit=false tabs='' dumpLogFile=$HOME/stdout.txt vName vVal prefix

	PushSettings "$FUNCNAME"
	set +xv # Turn off trace

	## Process our own special directives
		if [[ $1 == 'ifMe' ]]; then [[ $userName != 'dscudiero' ]] && return 0 ; shift
		elif [[ $1 == 'singleLine' || $1 == 'oneLine' ]]; then singleLine=true ; shift
		fi

	writeIt() {
		local writeItVar="$1"
		local writeItVal="$2"
		local sep writeItOutStr
		[[ $singleLine == true && -n $writeItVar ]] && sep=', ' || sep='\n'
		local prefix=''
		[[ $caller != 'source' ]] && prefix="$(ColorV "$myName.$caller")."
		local varStr="$(ColorN "$writeItVar")"

		[[ -n $writeItVar ]] && writeItOutStr="${prefix}${varStr} = >${writeItVal}<${sep}" || writeItOutStr="$sep"
		#[[ ${writeItOutStr: (-2)} == ",\n" ]] && writeItOutStr="${writeItOutStr:0:${#writeItOutStr}-2}\n"

		if [[ $logit == false ]]; then
			echo -en "${tabs}${writeItOutStr}";
		elif [[ -w $dumpLogFile ]]; then
			[[ $dumpFirstWrite == true ]] && echo $(date) >> $dumpLogFile && dumpFirstWrite=false
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
				elif [[ $lowervName == '-o' ]]; then
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
				if [[ $vName == 'pwd' ]]; then vVal="$(pwd)"
				else vVal=${!vName}
				fi
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
# TODO tick marks
#===================================================================================================
function ToDo { 
	echo -e "\n*** TODO ($myName) ***"
	[[ -n $* ]] && echo -e "\t$*"
	echo
} #ToDo
function TODO { ToDo $* ; } ; function todo { ToDo $* ; } ; function Todo { ToDo $* ; }
export -f ToDo ; export -f todo ; export -f Todo ; export -f TODO ;

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
function dumpArray { DumpArray $* ; }
export -f dumpArray

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
## 04-28-2017 @ 16.42.05 - ("2.0.12")  - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 07.56.51 - ("2.0.24")  - dscudiero - Add ToDo function
## 05-19-2017 @ 08.04.42 - ("2.0.29")  - dscudiero - Added 'isMe' token
## 05-19-2017 @ 08.51.15 - ("2.0.39")  - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 08.55.08 - ("2.0.40")  - dscudiero - Added script name to TODO output
