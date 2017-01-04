## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.14" # -- dscudiero -- 01/04/2017 @ 13:43:38.43
#===================================================================================================
# Parse an argumenst string driven by an control array that is passed in
# argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
# extraToken/exCmd = a command to execute for switch & option
# 					 a variable to set the value of # for switch#
# e.g.+
# 	argList+=(-verbose,switch,verbose)
# 	argList+=(-cat,switch,cat)
# 	argList+=(-debug,switch#,debug,"env="dev";dev=true")
# 	argList+=(-file,option,file,'env="dev"')
# ParseArgsStd "${argList[@]}
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ParseArgs {
#	verboseLevel=3
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local argToken foundArg parseStr argName minLen argType scriptVar exCmd argGroup helpText scriptVarVal badArgList
	[[ "$*" == '' ]] && return 0
	local tmpStr

	Msg2 $V3 "\tInitial ArgStr = >$*<"
	## Loop through all of the tokens on the passed in argument list
	until [[ "$*" == '' ]]; do
		origArgToken="$1"; shift || true
		## If the token does not start with a '-' then set client variable if not already set
		if [[ ${origArgToken:0:1} != '-' && $client == '' ]]; then
			Client=$origArgToken; client=$(Lower $origArgToken)
			Msg2 $V3 "\t\t*** found client value = '$client'"
			continue
		fi
		Msg2 $V3 "\n\tProcessing input token: '$origArgToken'..."
		## Loop through all defined arguments (argList)
		foundArg=false
		for argDef in "${argList[@]}"; do
			origArgName=$(echo $argDef | cut  -d ',' -f 1)
			## Check to see if this argument is defined in the users .tools file
			minLen=$(echo $argDef | cut  -d ',' -f 2)
			## Does the argument match the argument def
			if [[ $(Lower "${origArgToken:0:$minLen+1}") == $(Lower ${origArgName:0:$minLen+1}) ]]; then
				argType=$(Lower $(echo $argDef | cut  -d ',' -f 3))
				scriptVar=$(echo $argDef | cut  -d ',' -f 4)
				exCmd=$(echo $argDef | cut  -d ',' -f 5)
				argGroup=$(Lower $(echo $argDef | cut  -d ',' -f 6))
				helpText=$(echo $argDef | cut  -d ',' -f 7-)
				foundArg=true
				## Parse data based on argument type
				if [[ $argType == 'switch' ]]; then
					[[ $scriptVar != '' ]] && eval $scriptVar=true
					if [[ $exCmd != '' ]]; then eval $exCmd; fi
					break
				elif [[ $argType == 'switch#' ]]; then
					re='^[0-9]+$'
					if   [[ ${origArgToken:2} =~ $re ]]; then
						eval $exCmd=${origArgToken:2}
					fi
					if [[ $scriptVar != '' ]]; then eval $scriptVar=true; fi
					break
				elif [[ $argType == 'option' ]]; then
					[[ ${1:0:1} == '-' ]] && Msg2 $W "Option flag '$origArgToken' specified with no value" && continue
					## Check for a quotes string, if found then pull whole string
					if [[ ${1:0:1} == "'" || ${1:0:1} == '"' ]]; then
						## Pull off the string to the trailing quote
						quoteChar=${1:0:1}
						unset tmpStr
						until [[ ${1:${#1}-1:1} == $quoteChar || ${#*} -eq 0 ]]; do
							tmpStr="$tmpStr $1"
							shift || true
						done
						tmpStr="$tmpStr $1"
						scriptVarVal=${tmpStr:2:${#tmpStr}-3} ## Need to start at 2 since there is a leading blank char
						[[ $scriptVar != '' ]] && eval $scriptVar=\""$scriptVarVal"\"
						shift || true
						break
					## Not a quotes string
					else
						scriptVarVal="$1"
						[[ $scriptVar != '' ]] && eval $scriptVar=\""$scriptVarVal"\"
						shift || true
						break
					fi
				elif [[ $argType == 'help' ]]; then
					Help "${argList[@]}"
					Msg2 $V3 "*** $FUNCNAME -- Completed ***"
					Goodbye 0
				fi
			fi ## token matched arg  def
		done ## arg definition array

		if [[ $foundArg == true ]]; then
			Msg2 $V3 "^^*** found match for $argType: '$origArgName' specified as '$origArgToken', scriptVarName = $scriptVar, value = >${!scriptVar}<"
			[[ $argType == 'option' ]] && tmpStr=${!scriptVar} && myArgStr="${myArgStr:${#tmpStr}+1}" ## Remove argument value
		else
			[[ $parseQuiet != true ]] && Msg2 $W "Argument token '$origArgToken' is not defined, it will be ignored"
			badArgList="$badArgList, $origArgToken"
			myArgStr="${myArgStr:${#origArgToken}+1}" ## Remove argument token
		fi
		Msg2 $V3 "\t\tAfter parse \$* = >$*<"
	done ## tokens in the input string

	Msg2 $V3 "\tSurviving Arguments = >$*<"
	if [[ $badArgList != '' ]]; then
		badArgList="${badArgList:1}"
	fi
	parsedArgStr="$badArgList"

	## Special processing for specific args
	if [[ $verbose == true && $verboseLevel -eq 0 ]]; then verboseLevel=1; fi
	if [[ ${#cims[@]} -gt 0 && $cimStr == '' ]]; then
		cimStr=$(printf '%s, ' "${cims[@]}")
		cimStr=${cimStr:0:${#cimStr}-2}
	fi

	#===================================================================================================
	## If testMode then run local customizations
		[[ $testMode == true && $(Contains "$administrators" "$userName") != true ]] && Msg2 $T "You do not have sufficient permissions to run this script in 'testMode'"
		[[ $testMode == true && -n "$(type -t testMode-$myName)"  && "$(type -t testMode-$myName)" = function ]] && testMode-$myName
		[[ $testMode == true && -n "$(type -t testMode-local)"  && "$(type -t testMode-local)" = function ]] && testMode-local

	[[ $verboseLevel -ge 3 ]] && Pause
	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #ParseArgs
export -f ParseArgs

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:02 CST 2017 - dscudiero - General syncing of dev to prod
