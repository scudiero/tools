## DO NOT AUTOVERSION
#===================================================================================================
# version=2.1.-1 # -- dscudiero -- Fri 09/08/2017 @  9:28:25.55
#===================================================================================================
# Display script help -- passed an array of argument definitinons, see ParseArg function
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Help {
	mode="${1-normal}"

	includes='Msg3 Dump StringFunctions Colors'
	Import "$includes"

	[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName 'setVarsOnly'
	[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME 'setVarsOnly'

	local myHelpSet="common,script,$(tr ' ' ',' <<< $helpSet)"
	local tempStr="$(ColorK "Usage:") $myName"

	includes='Msg3 Colors StringFunctions'
	Import "$includes"

	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	echo; echo
	Msg3 "$myName version: $version"
	[[ $updatesClData == 'Yes' ]] && Warning "This script updates client side data"
	echo

	sqlStmt="select restrictToUsers,restrictToGroups from $scriptsTable where name=\"$myName\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		result="${resultSet[0]}"
		restrictToUsers=${result%%|*}
		restrictToGroups=${result##*|}
		[[ $restrictToUsers != 'NULL' ]] && Info "This script is restricted to users: $restrictToUsers"
		[[ $restrictToGroups != 'NULL' ]] && Info "This script is restricted to groups: $restrictToGroups"
		[[ $restrictToUsers == 'NULL' && $restrictToGroups == 'NULL' ]] && Info "This script is not restricted"
		echo
	fi


	[[ $(Contains ",$myHelpSet," ",client,") == true ]] && hasClient=true && tempStr="$tempStr [client]"
	tempStr="$tempStr [OPTIONS]"
	Msg3 "$tempStr"
	echo
	## Print out header info
		[[ $scriptDescription != '' ]] && Msg3 "$(ColorK "$scriptDescription.")"
		[[ $shortDescription != '' ]] && Msg3 "$(ColorK "$shortDescription.")"
		[[ $longDescription != '' ]] && echo && Msg3 "$longDescription" && echo
		if [[ -n $scriptHelpDesc ]]; then
			for text in "${scriptHelpDesc[@]}"; do
				Msg3 "$text"
			done
			echo
		else
			[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName
			[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME
		fi
		[[ $author != '' ]] && Msg3 "$(ColorK "Author:") $author"
		[[ $supported != '' ]] && Msg3 "$(ColorK "Supported:") $supported"

	## Loop through them and find the max widths for the name and min name
		local maxWidthMin=0
		local maxWidthName=0
		for parseStr in "${argList[@]}"; do
			local argName=$(Lower $(echo $parseStr | cut  -d ',' -f 1))
			[[ ${#argName} -gt $maxWidthName ]] && maxWidthName=${#argName}
			local minLen=$(echo $parseStr | cut  -d ',' -f 2)
			[[ $minLen -gt $maxWidthMin ]] && maxWidthMin=$minLen
		done
		(( maxWidthMin += 1 ))

	echo
	if [[ $hasClient == true ]]; then
		Msg3 "$(ColorK "[client]:")"
		Msg3 "^This is the client code (abbreviation) for the client that you wish to work with."
	fi

	## print them out
		#dump myHelpSet validArgs
		local scriptOptionsArray scriptSwitchesArray commonOptionsArray commonSwitchesArray
		unset scriptOptionsArray scriptSwitchesArray commonOptionsArray commonSwitchesArray
		local argGroup argName minLen argType tempStr1 tempStr2 helpText msgString
		## seperate out options from flags
		for parseStr in "${argList[@]}"; do
			argGroup=$(Lower $(echo $parseStr | cut  -d ',' -f 6))
			#dump parseStr -t argGroup
			[[ $argGroup != '' && $(Contains ",$myHelpSet," ",$argGroup,") == false ]] && continue
			argName=$(echo $parseStr | cut  -d ',' -f 1)
			#dump -t argName
			if [[ $validArgs != '' ]]; then
				[[ $(Contains ",$(Lower "$validArgs")," ",$(Lower "$argName"),") != true ]] && continue
			fi
			minLen=$(echo $parseStr | cut  -d ',' -f 2)
			argType=$(Lower $(echo $parseStr | cut  -d ',' -f 3))
			helpText=$(echo $parseStr | cut  -d ',' -f 7-)
			tempStr1=$(ColorK ${argName:0:$minLen+1})
			junk=$(( padLen = $maxWidthName - ${#argName} ))
			tempStr2="${argName:$minLen+1}$(PadChar ' ' $padLen)"
			argName="${tempStr1}${tempStr2}"
			msgString="^^$argName - $helpText"
			# dump parseStr -t argGroup
			[[ -z $msgString ]] && continue
			#dump msgString argGroup argType
			if [[ $argGroup == 'common' ]]; then
				[[ ${argType:0:6} == 'option' ]] && commonOptionsArray+=("$msgString") || commonSwitchesArray+=("$msgString")
			else
				[[ ${argType:0:6} == 'option' ]] && scriptOptionsArray+=("$msgString") || scriptSwitchesArray+=("$msgString")
			fi
		done

	echo
	Msg3 "$(ColorK "[OPTIONS]")"
	if [[ ${#scriptOptionsArray[@]} -gt 0 || ${#scriptSwitchesArray[@]} -gt 0  ]]; then
		Msg3 "^$(ColorU "$(ColorK "Script specific options:")")"
		## Script specific options
		if [[ ${#scriptOptionsArray[@]} -gt 0 ]]; then
			Msg3 "^^$(ColorK "Arguments with values (i.e. a flag with value e.g. -flag value):")"
			for msgString in "${scriptOptionsArray[@]}"; do
				Msg3 "^$msgString"
			done
			echo
		fi
		## Script specific switches
		if [[ ${#scriptSwitchesArray[@]} -gt 0 ]]; then
			Msg3 "^^$(ColorK "Arguments without values (i.e. a flag e.g. -flag):")"
			for msgString in "${scriptSwitchesArray[@]}"; do
				Msg3 "^$msgString"
			done
			echo
		fi
	fi

	Msg3 "^$(ColorU "$(ColorK "Tools common options:")") $(ColorW "(Note: While all options can be specified they may not have a meaning for the current script)")"
	## Common specific options
	if [[ ${#commonOptionsArray[@]} -gt 0 ]]; then
		Msg3 "^^$(ColorK "Arguments with values (i.e. a flag with value e.g. -flag value):")"
		for msgString in "${commonOptionsArray[@]}"; do
			Msg3 "^$msgString"
		done
		echo
	fi
	## Common specific switches
	if [[ ${#commonSwitchesArray[@]} -gt 0 ]]; then
		Msg3 "^^$(ColorK "Arguments without values (i.e. a flag e.g. -flag):")"
		for msgString in "${commonSwitchesArray[@]}"; do
			Msg3 "^$msgString"
		done
		echo
	fi

	## print out script specific help notes
	if [[ ${#helpNotes[@]} -gt 0 ]]; then
		Msg3 "$(ColorK "Script specific notes:")"
		for ((cntr = 0 ; cntr < ${#helpNotes[@]} ; cntr++)); do
			let idx=$cntr+1
	 		Msg3 "^$idx) ${helpNotes[$cntr]}"
		done
		echo
	fi

	## General help notes for all scripts
	echo
	Msg3 "$(ColorK "General Notes:")"
	local notesClient notesAlways notes
	unset notesClient notesAlways notes
	notesClient+=("A value of '.' may be specified for client to parse the client value from the current working directory.")
	notesClient+=("A value of '?' may be specified for client to display a selection list of all clients.")

	notesAlways+=("All flags/switches/options $(ColorB "must") be delimited from other flags by at lease one blank character.")
	notesAlways+=("The minimum abbreviations for argument flags are indicated in the $(ColorK highlight) color above.")
	notesAlways+=("If an argument is an option with a value, and the value contains blanks/spaces, the argument value needs\n^   to be enclosed in single quotes which need to be escaped on the command line, e.g. -file \'This is a File Name\'.")
	notesAlways+=("To get additional help information on what is used by this script you can use the -hh option.")

	notes=("${notesAlways[@]}")
	[[ $hasClient == true ]] && notes=("${notesClient[@]}" "${notes[@]}")

	idx=1
	for line in "${notes[@]}"; do
		Msg3  "^$idx) $line"
		((idx+=1))
	done
	echo

	[[ $mode != '-extended' ]] && return 0

	## Extended help, print out dependencies
	if [[ -n $SCRIPTINCLUDES ]]; then
		## Scripts
		local token
		Msg3 "$(ColorK "Tools library modules used (via tools/lib):")"
		for token in $(tr ',' ' ' <<< $SCRIPTINCLUDES); do
			Msg3 "^$token"
		done #| sort
		echo
		## Java
		if [[ $(Contains "$SCRIPTINCLUDES" "RunSql2") == true && -n $javaResources ]]; then
			local token
			Msg3 "$(ColorK "Java resources used (via $TOOLSPATH/src/java/tools.jar):")"
			for token in $(tr ',' ' ' <<< $javaResources); do
				Msg3 "^$token"
			done | sort
			echo
		fi
		## Python
		if [[ $(Contains "$SCRIPTINCLUDES" "GetExcel") == true && -n $pythonResources ]]; then
			local token
			Msg3 "$(ColorK "Python resources used:")"
			for token in $(tr ',' ' ' <<< $pythonResources); do
				Msg3 "^$token"
			done | sort
			echo
		fi
	fi

	return 0
} # Help
export -f Help

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:41 CST 2017 - dscudiero - General syncing of dev to prod
## 08-30-2017 @ 13.53.59 - (2.0.2)     - dscudiero - treat scriptHelpDescription as an array
## 08-30-2017 @ 14.07.33 - (2.0.6)     - dscudiero - Tweak output format
## 09-01-2017 @ 09.27.30 - (2.0.8)     - dscudiero - Add call myname-FUNCNAME function if found
## 09-01-2017 @ 09.38.26 - (2.0.9)     - dscudiero - Fix spelling error
## 09-25-2017 @ 08.14.09 - (2.1.-1)    - dscudiero - Use Msg3
