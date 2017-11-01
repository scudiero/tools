## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.63" # -- dscudiero -- Wed 11/01/2017 @ 12:14:39.02
#===================================================================================================
# Quick dump a list of variables
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#==================================================================================================
dumpFirstWrite=true
function Dump {
	local mytoken tabCnt re='^-{0,1}[0-9]$' logOnly=false out='/dev/tty' pause=false
	local caller=${FUNCNAME[1]}
	[[ $caller == 'dump' || $caller == 'Dump' ]] && caller=${FUNCNAME[2]}

	for mytoken in $*; do
		if [[ $mytoken =~ $re ]]; then
			[[ ${mytoken:0:1} == '-' ]] && mytoken="${mytoken:1}"
			[[ $mytoken -gt $verboseLevel ]] && return 0
			shift
			continue
		fi
		[[ ${mytoken:0:2} == '-t' ]] && { tabCnt=${mytoken:2}; tabCnt=${tabCnt:-1}; continue; }
		[[ $mytoken == '-n' ]] && { echo -e -n "\n"; continue; }
		[[ $mytoken == '-l' ]] && { logOnly=true; shift; continue; }
		[[ $mytoken == '-p' ]] && { pause=true; continue; }
		[[ $mytoken == '-q' ]] && { Goodbye X; }
		[[ $mytoken == '-ifme' ]] && { [[ $userName != dscudiero ]] && return 0; }

		if [[ -n $tabCnt ]]; then
			for ((i=0; i<$tabCnt; i++)); do
				[[ -z $tabStr ]] && echo -e -n "\t" || echo -e -n "$tabStr"
			done
		fi
		if [[ $logOnly == true && -n $logFile ]]; then
			[[ $dumpFirstWrite == true ]] && { echo -e "\n\n$(head -c 100 < /dev/zero | tr '\0' '=')" >> $logFile; echo "$(date)" >> $logFile;  dumpFirstWrite=false; }
			echo -e "${caller}.$mytoken = >${!mytoken}<" >> "$logFile"
		else
			echo -e "${colorVerbose}${caller}${colorDefault}.$mytoken = >${!mytoken}<"
		fi
	done

	[[ $pause == true ]] && { Pause "*** Pause.$FUNCNAME.${caller} ***"; }
	return 0
} ## Dump
function dump { Dump $* ; }
export -f Dump dump


# dumpFirstWrite=true
# function DumpS {
# 	declare lowervName
# 	local singleLine=false quit=false pause=false logit=false tabs='' dumpLogFile=$HOME/stdout.txt vName vVal prefix mytoken

# 	PushSettings "$FUNCNAME"
# 	set +xv # Turn off trace

# 	## Process our own special directives
# 		if [[ $(Lower $1) == 'if' || $(Lower $1) == 'is' ]]; then
# 			shift ; mytoken1="$1" ; shift
# 			[[ $userName != $mytoken1 ]] && return 0
# 			shift
# 		elif [[ $(Lower $1) == 'ifme' || $(Lower $1) == 'isme' ]]; then
# 			[[ $userName != 'dscudiero' ]] && return 0
# 			shift
# 		elif [[ $(Lower $1) == 'singleline' || $(Lower $1) == 'oneline' ]]; then
# 			singleLine=true
# 			shift
# 		fi

# 	writeIt() {
# 		local writeItVar="$1"
# 		local writeItVal="$2"
# 		local sep writeItOutStr
# 		[[ $singleLine == true && -n $writeItVar ]] && sep=', ' || sep='\n'
# 		local prefix=''
# 		[[ $caller != 'source' ]] && prefix="$(ColorV "$myName.$caller")."
# 		local varStr="$(ColorN "$writeItVar")"

# 		[[ -n $writeItVar ]] && writeItOutStr="${prefix}${varStr} = >${writeItVal}<${sep}" || writeItOutStr="$sep"
# 		#[[ ${writeItOutStr: (-2)} == ",\n" ]] && writeItOutStr="${writeItOutStr:0:${#writeItOutStr}-2}\n"

# 		if [[ $logit == false ]]; then
# 			echo -en "${tabs}${writeItOutStr}";
# 		elif [[ -w $dumpLogFile ]]; then
# 			[[ $dumpFirstWrite == true ]] && echo $(date) >> $dumpLogFile && dumpFirstWrite=false
# 			echo -en "$tabs$writeItOutStr" >> $dumpLogFile
# 		fi
# 		return 0
# 	} #writeIt

# 	## Loop through arguments
# 		local debugVarArray=($*)
# 		for debugVar in ${debugVarArray[@]};do
# 			vName=$debugVar; lowervName=$(Lower $vName)
# 			if [[ ${vName:0:1} == '-' ]]; then
# 				if [[ $lowervName == '-r' ]]; then
# 					echo > $dumpLogFile
# 				elif [[ $lowervName == '-s' ]]; then
# 					singleLine=true
# 				elif [[ $lowervName == '-o' ]]; then
# 					singleLine=true
# 				elif [[ $lowervName == '-l' ]]; then
# 					logit=true
# 				elif [[ $lowervName == '-t' ]]; then
# 					tabs="\t"$tabs
# 				elif [[ $lowervName == '-q' ]]; then
# 					quit=true
# 				elif [[ $lowervName == '-p' ]]; then
# 					pause=true
# 				elif [[ $lowervName == '-n' ]]; then
# 					writeIt;
# 				elif [[ $lowervName == '-m' ]]; then
# 					writeIt 'msg'
# 				else
# 					local re='^[0-9]+$'
# 					if [[ ${vName:1} =~ $re ]]; then
# 						local msgLevel=${vName:1}
# 						[[ $msgLevel -gt $verboseLevel ]] && return 0
# 					fi
# 				fi
# 			else
# 				if [[ $vName == 'pwd' ]]; then vVal="$(pwd)"
# 				else vVal=${!vName}
# 				fi
# 				caller=${FUNCNAME[1]}
# 				[[ $(Lower $caller) == 'dump' ]] && caller=${FUNCNAME[2]}
# 				writeIt $vName "$vVal"
# 			fi
# 		done

# 	## Write it out and or quit
# 		local callerData="$(caller)"
# 		local lineNo="$(basename $(cut -d' ' -f2 <<< $callerData))/$(cut -d' ' -f1 <<< $callerData)"
# 		if [[ $singleLine == true ]]; then vName=''; writeIt; fi
# 		[[ $quit == true ]] && Quit
# 		[[ $pause == true ]] && Msg3 && Pause '*** Dump paused script execution at $lineNo, press enter to continue ***'


# 	PopSettings "$FUNCNAME"
# 	return 0

# } #DumpS

#===================================================================================================
# TODO tick marks
#===================================================================================================
function ToDo {
	echo -e "\n*** TODO ($myName) ***"
	[[ -n $* ]] && echo -e "\t$*"
	echo
} #ToDo
function TODO { ToDo $* ; }
export -f TODO ;

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
function dumparray { DumpArray $* ; }
function dumpArray { DumpArray $* ; }
export -f DumpArray dumparray dumpArray

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
function dumpmap { DumpMap $* ; }
function dumphash { DumpMap $* ; }
export -f DumpMap dumpmap dumphash

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
## 05-19-2017 @ 08.04.42 - ("2.0.29")  - dscudiero - Added 'isMe' mytoken
## 05-19-2017 @ 08.51.15 - ("2.0.39")  - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 08.55.08 - ("2.0.40")  - dscudiero - Added script name to TODO output
## 05-19-2017 @ 14.15.28 - ("2.0.41")  - dscudiero - Added 'if <userid>' support
## 05-24-2017 @ 08.17.22 - ("2.0.42")  - dscudiero - Tweak ifMe logic
## 05-24-2017 @ 08.22.16 - ("2.0.45")  - dscudiero - Added isMe
## 06-09-2017 @ 08.16.14 - ("2.0.46")  - dscudiero - lower case the first mytoken before checking for special mytokens
## 06-23-2017 @ 09.26.13 - ("2.0.47")  - dscudiero - Add caller information if calling pause
## 09-27-2017 @ 07.51.19 - ("2.0.49")  - dscudiero - added dumq
## 09-27-2017 @ 10.08.47 - ("2.0.51")  - dscudiero - General syncing of dev to prod
## 09-27-2017 @ 10.50.51 - ("2.0.53")  - dscudiero - fix error exporting dumps
## 09-27-2017 @ 12.22.47 - ("2.0.54")  - dscudiero - Fix problem parsing -2 msg level designators
## 10-02-2017 @ 17.07.04 - ("2.0.55")  - dscudiero - add dump alias
## 10-03-2017 @ 10.07.07 - ("2.0.57")  - dscudiero - Add -p option to pause execution
## 10-03-2017 @ 10.19.47 - ("2.0.58")  - dscudiero - If -p specifed the pause after all output generated
## 10-23-2017 @ 08.49.28 - ("2.0.59")  - dscudiero - Add ifme flag
## 11-01-2017 @ 12.15.21 - ("2.0.63")  - dscudiero - Add -q action
