## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.6" # -- dscudiero -- 01/04/2017 @ 12:24:57.44
#===================================================================================================
# Quick dump a list of variables
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

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
# Checkin Log
#===================================================================================================

## Wed Jan  4 12:25:20 CST 2017 - dscudiero - turn off tracing
