## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.49" # -- dscudiero -- Thu 09/07/2017 @  7:44:17.52
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
	local argToken foundArg parseStr argName minLen argType scriptVar exCmd argGroup helpText scriptVarVal badArgList token1 token2
	[[ -z "$*" ]] && return 0
	local tmpStr

	Msg2 $V3 "\tInitial ArgStr = >$*<"
	## Loop through all of the tokens on the passed in argument list
	until [[ -z "$*" ]]; do
		origArgToken="$1"; shift || true
		# ## If the token does not start with a '-' then set client variable if not already set
		# if [[ ${origArgToken:0:1} != '-' && -z $client ]]; then
		# 	Client=$origArgToken; client=$(Lower $origArgToken)
		# 	Msg2 $V3 "\t\t*** found client value = '$client'"
		# 	continue
		# fi
		Msg2 $V3 "\n\tProcessing input token: '$origArgToken'..."
		## Loop through all defined arguments (argList)
		foundArg=false
		for argDef in "${argList[@]}"; do
			origArgName=$(cut -d ',' -f 1 <<< $argDef)
			## Check to see if this argument is defined in the users .tools file
			minLen=$(echo $argDef | cut  -d ',' -f 2)
			[[ ${#origArgToken} -lt $minLen ]] && continue
			## Does the argument match the argument definition name
			token1="$(Lower "${origArgToken:0:$minLen+1}")"
			token2="$(Lower "${origArgName:0:$minLen+1}")"

			if [[ "$token1" == "$token2" ]]; then
				argType=$(cut  -d ',' -f 3 <<< $argDef) ; argType=$(Lower "$argType")
				scriptVar=$(cut  -d ',' -f 4 <<< $argDef)
				exCmd=$(cut  -d ',' -f 5 <<< $argDef)
				argGroup=$(cut  -d ',' -f 6 <<< $argDef) ; argGroup=$(Lower "$argGroup")
				helpText=$(cut  -d ',' -f 7- <<< $argDef)
				foundArg=true
				## Parse data based on argument type
				if [[ $argType == 'switch' ]]; then
					[[ -n $scriptVar ]] && eval $scriptVar=true
					if [[ -n $exCmd ]]; then eval $exCmd; fi
					break
				elif [[ $argType == 'switch#' ]]; then
					re='^[0-9]+$'
					if   [[ ${origArgToken:2} =~ $re ]]; then
						eval $exCmd=${origArgToken:2}
					fi
					if [[ -n $scriptVar ]]; then eval $scriptVar=true; fi
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
						[[ -n $scriptVar ]] && eval $scriptVar=\""$scriptVarVal"\"
						shift || true
						break
					## Not a quotes string
					else
						scriptVarVal="$1"
						[[ -n $scriptVar ]] && eval $scriptVar=\""$scriptVarVal"\"
						shift || true
						break
					fi
				elif [[ $argType == 'help' ]]; then
					Help "${argList[@]}"
					Goodbye 0
				fi
			fi ## token matched arg  def
		done ## arg definition array

		if [[ $foundArg == true ]]; then
			Msg2 $V3 "^^*** found match for $argType: '$origArgName' specified as '$origArgToken', scriptVarName = $scriptVar, value = >${!scriptVar}<"
			[[ $argType == 'option' ]] && tmpStr=${!scriptVar} && myArgStr="${myArgStr:${#tmpStr}+1}" ## Remove argument value
		else
			## If the token does not start with a '-' then set client variable if not already set
			if [[ ${origArgToken:0:1} != '-' && -z $client ]]; then
				Client=$origArgToken; client=$(Lower $origArgToken)
				Msg2 $V3 "\t\t*** found client value = '$client'"
				continue
			else
				[[ $parseQuiet != true ]] && Msg2 $W "Argument token '$origArgToken' is not defined, it will be ignored"
				badArgList="$badArgList, $origArgToken"
				myArgStr="${myArgStr:${#origArgToken}+1}" ## Remove argument token
			fi
		fi
		Msg2 $V3 "^^After parse \$* = >$*<"
	done ## tokens in the input string

	unset parsedArgStr
	if [[ -n $badArgList ]]; then
		Msg2 $V3 "\tSurviving Arguments = >$*<"
		badArgList="${badArgList:1}"
		parsedArgStr="$badArgList"
	fi

	## Special processing for specific args
	if [[ $verbose == true && $verboseLevel -eq 0 ]]; then verboseLevel=1; fi
	if [[ ${#cims[@]} -gt 0 && -z $cimStr ]]; then
		cimStr=$(printf '%s, ' "${cims[@]}")
		cimStr=${cimStr:0:${#cimStr}-2}
	fi

	#===================================================================================================
	## If testMode then run local customizations
		[[ $testMode == true && $(Contains "$administrators" "$userName") != true ]] && Msg2 $T "You do not have sufficient permissions to run this script in 'testMode'"
		[[ $testMode == true && -n "$(type -t testMode-$myName)" && "$(type -t testMode-$myName)" = function ]] && testMode-$myName
		[[ $testMode == true && -n "$(type -t $myName-testMode)"  && "$(type -t $myName-testMode)" = function ]] && $myName-testMode

	if [[ $verboseLevel -ge 3 ]]; then
		local prevScriptVar
		for argDef in "${argList[@]}"; do
			scriptVar=$(cut  -d ',' -f 4 <<< $argDef )
			[[ $scriptVar != $prevScriptVar ]] && dump -t $scriptVar && prevScriptVar=$scriptVar
		done
		Pause "*** $FUNCNAME completed ***\nPlease press enter to continue (x to quit, d for debug)"
	fi

	return 0
} #ParseArgs
export -f ParseArgs

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:02 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan 19 10:04:51 CST 2017 - dscudiero - misc cleanup
## Thu Jan 19 10:25:22 CST 2017 - dscudiero - Fix problem parsing client
## 04-10-2017 @ 09.36.28 - ("2.0.45")  - dscudiero - Tweak messaging
## 04-10-2017 @ 09.39.06 - ("2.0.46")  - dscudiero - remove debug statements
## 04-12-2017 @ 08.11.01 - ("2.0.47")  - dscudiero - changed
## 09-01-2017 @ 09.27.57 - ("2.0.48")  - dscudiero - Add call to myname-FUNCNAME if found
## 09-07-2017 @ 07.56.06 - ("2.0.49")  - dscudiero - Move the parsing of the client name to the end if no other arg matches have been found
