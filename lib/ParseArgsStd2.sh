## XO NOT AUTOVERSION
#===================================================================================================
# version="3.0.3" # -- dscudiero -- Wed 11/01/2017 @ 15:12:46.38
#===================================================================================================
## Standard argument parsing
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function ParseArgsStd2 {
	[[ -z $* ]] && return 0
	# [[ -n $* ]] && ParseArgsStd2 $* || ParseArgsStd2 fred -p -nop -prod aaaa,bbbb -src t -tgt p -sally harry -cimp -file xxxxx -cimc
	# dump -n -n client envs testMode srcEnv tgtEnv cimStr products file noPrompt noClear unknowArgs

	Import "RunSql2 StringFunctions Msg3"
	local argDefCntr arg argType found tmpStr tmpArg argShortName argLongName scriptVar scriptCmd

	## Make sure we have the argdefs data loaded
		if [[ ${#argDefs} -eq 0 ]]; then
			[[ $verboseLevel -ge 3 ]] && echo -e "\t$FUNCNAME: Loading argDefs array";
			local fields="shortName,longName,type,scriptvariable,scriptcommand,helpgroup,helptext"
			sqlStmt="select $fields from argdefs where status=\"active\" order by seqorder ASC"
			RunSql2 $sqlStmt
			for ((argDefCntr=0; argDefCntr<${#resultSet[@]}; argDefCntr++)); do
				argDefs+=("${resultSet[$argDefCntr]}")
			done
		fi

	## If there is a local function to add script specific arguments then call it
		local rec myArgs; unset myArgs
		[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME
		for rec in "${argDefs[@]}"; do myArgs+=("$rec"); done
		# for ((i=0; i<${#myArgs[@]}; i++)); do
		# 	echo "myArgs[$i] = >${myArgs[$i]}<"
		# done

	# argdef record looks like: "shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp"
	## Loop through all the argument tokens
		for ((argCntr=1; argCntr<=$#; argCntr++)); do
			arg="${!argCntr}"
			dump 3 -n arg
			# Loop through the argDefs array to see if we have a match
				found=false
				for ((argDefCntr=0; argDefCntr<${#myArgs[@]}; argDefCntr++)); do
					tmpStr="${myArgs[$argDefCntr]}"
					argShortName="${tmpStr%%|*}"; argShortName=${argShortName,,[a-z]}; tmpStr=${tmpStr#*|};
					argLongName="${tmpStr%%|*}"; argLongName=${argLongName,,[a-z]}; tmpStr=${tmpStr#*|};
					tmpArg="${arg,,[a-z]}"
					[[ $tmpArg =~ ^-${argShortName} || $tmpArg =~ ^--${argLongName}$ ]] && { found=true; break; }
				done
				[[ $found == true ]] && dump 3 -t argShortName argLongName tmpArg tmpStr found || dump 3 -t found

			## Parse the argument
				if [[ $found == true ]]; then
					[[ $verboseLevel -ge 3 ]] && echo -e "\tFound match: '$argShortName/$argLongName' --- $tmpStr";
					argType="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
					scriptVar="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
					scriptCmd="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
					dump 3 -t2 arg argType scriptVar scriptCmd
					case $argType in
						switch|flag) 
								[[ -n $scriptVar && -z $scriptCmd ]] && eval "$scriptVar=true"
								if [[ -n $scriptCmd ]]; then
									if [[ $scriptCmd == 'appendShortName' ]]; then
										[[ -z ${!scriptVar} ]] && eval "$scriptVar=\"$argShortName\"" || eval "$scriptVar=\"${!scriptVar},$argShortName\""
									elif [[ $scriptCmd == 'appendLongName' ]]; then
										[[ -z ${!scriptVar} ]] && eval "$scriptVar=\"$argLongName\"" || eval "$scriptVar=\"${!scriptVar},$argLongName\""
									else
										eval "$scriptCmd"
									fi
								fi
								;;
						counter) 
								[[ -n $scriptVar ]] && { eval "$scriptVar=${arg:1}"; }
								;;
						option) 
								[[ -n $scriptVar ]] && { (( argCntr++)); eval "$scriptVar=\"${!argCntr}\""; }
								;;
					esac
				else
					[[ -z $client && ${arg:0:1} != '-' ]] && { client="$arg"; continue; }
				    unknowArgs="$unknowArgs,$arg"
				fi
				# argType="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				# argVar="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				# argCmd="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				# argHelpGrp="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				# arghelpText="${tmpStr%%|*}"
		done

	[[ -n $unknowArgs ]] && unknowArgs="${unknowArgs:1}"

	## Misc special processing
		[[ $fork == true ]] && forkStr='&' || unset forkStr
		if [[ -n $forUser ]]; then
			[[ -d /home/$forUser ]] && userName=$forUser || Error "Userid specified as -forUser ($forUser) is not valid, ignoring directive"
		fi

	## If testMode then run local customizations
		[[ $testMode == true && $(Contains "$administrators" "$userName") != true ]] && \
				Terminate "$myName: You do not have sufficient permissions to run this script in 'testMode'"
		[[ $testMode == true && -n "$(type -t $myName-testMode)"  && "$(type -t $myName-testMode)" = function ]] && $myName-testMode

	return 0
} ## ParseArgsStd2
export -f ParseArgsStd2

#===================================================================================================
# Check-in Log
#===================================================================================================
## 11-01-2017 @ 09.54.34 - ("3.0.2")   - dscudiero - m
## 11-01-2017 @ 15.14.34 - ("3.0.3")   - dscudiero - Add counter type to deal with -vx
