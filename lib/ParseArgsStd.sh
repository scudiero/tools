## XO NOT AUTOVERSION
#===================================================================================================
# version="3.0.30" # -- dscudiero -- Tue 04/24/2018 @ 10:14:28.87
#===================================================================================================
## Standard argument parsing
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function ParseArgsStd {
	[[ -z $* ]] && return 0
	# [[ -n $* ]] && ParseArgsStd2 $* || ParseArgsStd2 fred -p -nop -prod aaaa,bbbb -src t -tgt p -sally harry -cimp -file xxxxx -cimc
	# dump -n -n client envs testMode srcEnv tgtEnv cimStr products file noPrompt noClear unknowArgs

	Import "RunSql StringFunctions Msg"
	local argDefCntr arg argType found tmpStr tmpEnv tmpArg argShortName argLongName scriptVar scriptCmd

	## Make sure we have the argdefs data loaded
		if [[ ${#argDefs} -eq 0 ]]; then
			[[ $verboseLevel -ge 3 ]] && echo -e "\t$FUNCNAME: Loading argDefs array";
			local fields="shortName,longName,type,scriptvariable,scriptcommand,helpgroup,helptext"
			sqlStmt="select $fields from argdefs where status=\"active\" order by seqorder ASC"
			RunSql $sqlStmt
			for ((argDefCntr=0; argDefCntr<${#resultSet[@]}; argDefCntr++)); do
				argDefs+=("${resultSet[$argDefCntr]}")
			done
		fi

	## If there is a local function to add script specific arguments then call it
		local rec myArgs allArgDefs; unset myArgs allArgDefs
		[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME

		[[ ${#myArgs[@] -gt 0} ]] && { for rec in "${myArgs[@]}"; do allArgDefs+=("$rec"); done; }
		for rec in "${argDefs[@]}"; do allArgDefs+=("$rec"); done
		#for ((i=0; i<${#allArgDefs[@]}; i++)); do echo "allArgDefs[$i] = >${allArgDefs[$i]}<"; done; Pause

	# argdef record looks like: "shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp"
	## Loop through all the argument tokens
		for ((argCntr=1; argCntr<=$#; argCntr++)); do
			arg="${!argCntr}"
			dump 3 -n arg
			# Loop through the allArgDefs array to see if we have a match
				found=false
				for ((argDefCntr=0; argDefCntr<${#allArgDefs[@]}; argDefCntr++)); do
					tmpStr="${allArgDefs[$argDefCntr]}"
					argShortName="${tmpStr%%|*}"; argShortName=${argShortName,,[a-z]}; tmpStr=${tmpStr#*|};
					argLongName="${tmpStr%%|*}"; argLongName=${argLongName,,[a-z]}; tmpStr=${tmpStr#*|};
					tmpArg="${arg,,[a-z]}"
					[[ $tmpArg =~ ^-${argShortName} || $tmpArg =~ ^--${argLongName}$ || $tmpArg =~ ^-${argLongName} ]] && { found=true; break; }
				done
				[[ $found == true ]] && dump 3 -t argShortName argLongName tmpArg tmpStr found || dump 3 -t found
			## Parse the argument
				if [[ $found == true ]]; then
					[[ $verboseLevel -ge 3 ]] && echo -e "\tFound match: '$argShortName/$argLongName' --- $tmpStr";
					argType="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
					scriptVar="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
					scriptCmd="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
					[[ $scriptCmd == 'NULL' ]] && unset scriptCmd
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
								[[ -n $scriptVar ]] && { eval "$scriptVar=${arg:2}"; }
								;;
						option)
								if [[ -n $scriptCmd && ${scriptCmd,,[a-z]} != 'null' ]]; then
									if [[ $scriptCmd == 'appendShortName' ]]; then
										[[ -z ${!scriptVar} ]] && eval "$scriptVar=\"$argShortName\"" || eval "$scriptVar=\"${!scriptVar},$argShortName\""
									elif [[ $scriptCmd == 'appendLongName' ]]; then
										((argCntr++))
										tmpStr="${!argCntr}"
										[[ -z ${!scriptVar} ]] && eval "$scriptVar=\"$tmpStr\"" || eval "$scriptVar=\"${!scriptVar},$tmpStr\""
									elif [[ $scriptCmd == 'expandEnv' ]]; then
										(( argCntr++));
										tmpStr="${!argCntr}"
										found=false
										for tmpEnv in ${courseleafDevEnvs//,/ } ${courseleafProdEnvs//,/ }; do
											[[ $tmpEnv =~ ^${tmpStr} ]] && { found=true; break; }
											#[[ $tmpStr =~ ^${tmpEnv} ]] && { echo "HERE HERE HERE HERE"; foune=true; break; }
										done
										[[ $found == true ]] && eval "$scriptVar=\"$tmpEnv\"";
									fi
								else
									[[ -n $scriptVar ]] && { (( argCntr++)); eval "$scriptVar=\"${!argCntr}\""; }
								fi
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
export -f ParseArgsStd

#===================================================================================================
# Check-in Log
#===================================================================================================
## 11-01-2017 @ 09.54.34 - ("3.0.2")   - dscudiero - m
## 11-01-2017 @ 15.14.34 - ("3.0.3")   - dscudiero - Add counter type to deal with -vx
## 11-01-2017 @ 15.16.36 - ("3.0.4")   - dscudiero - Fix counter type
## 11-02-2017 @ 10.27.46 - ("3.0.6")   - dscudiero - Seperate local argdefs from common
## 11-02-2017 @ 15.22.27 - ("3.0.14")  - dscudiero - Added expandEnv command type for options to expand the entered value to a full env name
## 12-20-2017 @ 08.31.40 - ("3.0.19")  - dscudiero - Fix a problem when the default value in the database for an option arg is 'NULL'
## 03-20-2018 @ 08:14:45 - 3.0.21 - dscudiero - Add '=' as a valid variable prefix symbol
## 03-22-2018 @ 13:42:32 - 3.0.22 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:31:10 - 3.0.28 - dscudiero - Updated for ParseArgsStd2/ParseArgsStd
## 04-24-2018 @ 11:21:24 - 3.0.30 - dscudiero - Addd code to ignore scriptCmd if db returns 'NULL'
