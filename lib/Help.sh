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

	includes='Msg Dump StringFunctions Colors'
	Import "$includes"

	[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName 'setVarsOnly'
	[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME 'setVarsOnly'

	local myHelpSet="common,script,$(tr ' ' ',' <<< $helpSet)"
	local tempStr="$(ColorK "Usage:") $myName"

	includes='Msg Colors StringFunctions'
	Import "$includes"

	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	echo; echo
	Msg "$myName version: $version"
	[[ $updatesClData == 'Yes' ]] && Warning "This script updates client side data"
	echo

	# sqlStmt="select restrictToUsers,restrictToGroups from $scriptsTable where name=\"$myName\""
	# RunSql $sqlStmt
	# if [[ -n ${resultSet[0]} ]]; then
	# 	result="${resultSet[0]}"
	# 	restrictToUsers=${result%%|*}
	# 	restrictToGroups=${result##*|}
	# 	[[ $restrictToUsers != 'NULL' ]] && Info "This script is restricted to users: $restrictToUsers"
	# 	[[ $restrictToGroups != 'NULL' ]] && Info "This script is restricted to groups: $restrictToGroups"
	# 	[[ $restrictToUsers == 'NULL' && $restrictToGroups == 'NULL' ]] && Info "This script is not restricted"
	# 	echo
	# fi


	[[ $(Contains ",$myHelpSet," ",client,") == true ]] && hasClient=true && tempStr="$tempStr [client]"
	tempStr="$tempStr [OPTIONS]"
	Msg "$tempStr"
	echo
	## Print out header info
		[[ $scriptDescription != '' ]] && Msg "$(ColorK "$scriptDescription.")"
		[[ $shortDescription != '' ]] && Msg "$(ColorK "$shortDescription.")"
		[[ $longDescription != '' ]] && echo && Msg "$longDescription" && echo
		if [[ -n $scriptHelpDesc ]]; then
			for text in "${scriptHelpDesc[@]}"; do
				Msg "$text"
			done
			echo
		else
			[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName
			[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME
		fi
		[[ $author != '' ]] && Msg "$(ColorK "Author:") $author"
		[[ $supported != '' ]] && Msg "$(ColorK "Supported:") $supported"

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
		Msg "$(ColorK "[client]:")"
		Msg "^This is the client code (abbreviation) for the client that you wish to work with."
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
	Msg "$(ColorK "[OPTIONS]")"
	if [[ ${#scriptOptionsArray[@]} -gt 0 || ${#scriptSwitchesArray[@]} -gt 0  ]]; then
		Msg "^$(ColorU "$(ColorK "Script specific options:")")"
		## Script specific options
		if [[ ${#scriptOptionsArray[@]} -gt 0 ]]; then
			Msg "^^$(ColorK "Arguments with values (i.e. a flag with value e.g. -flag value):")"
			for msgString in "${scriptOptionsArray[@]}"; do
				Msg "^$msgString"
			done
			echo
		fi
		## Script specific switches
		if [[ ${#scriptSwitchesArray[@]} -gt 0 ]]; then
			Msg "^^$(ColorK "Arguments without values (i.e. a flag e.g. -flag):")"
			for msgString in "${scriptSwitchesArray[@]}"; do
				Msg "^$msgString"
			done
			echo
		fi
	fi

	Msg "^$(ColorU "$(ColorK "Tools common options:")") $(ColorW "(Note: While all options can be specified they may not have a meaning for the current script)")"
	## Common specific options
	if [[ ${#commonOptionsArray[@]} -gt 0 ]]; then
		Msg "^^$(ColorK "Arguments with values (i.e. a flag with value e.g. -flag value):")"
		for msgString in "${commonOptionsArray[@]}"; do
			Msg "^$msgString"
		done
		echo
	fi
	## Common specific switches
	if [[ ${#commonSwitchesArray[@]} -gt 0 ]]; then
		Msg "^^$(ColorK "Arguments without values (i.e. a flag e.g. -flag):")"
		for msgString in "${commonSwitchesArray[@]}"; do
			Msg "^$msgString"
		done
		echo
	fi

	## print out script specific help notes
	if [[ ${#helpNotes[@]} -gt 0 ]]; then
		Msg "$(ColorK "Script specific notes:")"
		for ((cntr = 0 ; cntr < ${#helpNotes[@]} ; cntr++)); do
			let idx=$cntr+1
	 		Msg "^$idx) ${helpNotes[$cntr]}"
		done
		echo
	fi

	## General help notes for all scripts
	echo
	Msg "$(ColorK "General Notes:")"
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
		Msg  "^$idx) $line"
		((idx+=1))
	done
	echo

	[[ $mode != '-extended' ]] && return 0

	## Extended help, print out dependencies
	if [[ -n $SCRIPTINCLUDES ]]; then
		## Scripts
		local token
		Msg "$(ColorK "Tools library modules used (via tools/lib):")"
		for token in $(tr ',' ' ' <<< $SCRIPTINCLUDES); do
			Msg "^$token"
		done #| sort
		echo
		## Java
		if [[ $(Contains "$SCRIPTINCLUDES" "RunSql") == true && -n $javaResources ]]; then
			javaPgm=${runMySqlJavaPgmName:-runMySql}
	 		jar="$TOOLSPATH/tools/jars/$javaPgm.jar"
			Msg "$(ColorK "Java resources used ($jar):")"
	 		jar -tf "$jar" | Indent
			echo
		fi
		## Python
		if [[ $(Contains "$SCRIPTINCLUDES" "GetExcel") == true && -n $pythonResources ]]; then
			local token
			Msg "$(ColorK "Python resources used:")"
			for token in $(tr ',' ' ' <<< $pythonResources); do
				Msg "^$token"
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
## 09-25-2017 @ 08.14.09 - (2.1.-1)    - dscudiero - Use Msg
## 03-19-2018 @ 10:43:25 - 2.1.-1 - dscudiero - Change the way we display the java dependencies
## 03-22-2018 @ 13:42:12 - 2.1.-1 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 04-23-2018 @ 09:38:49 - 2.1.-1 - dscudiero - Cosmetic/minor change/Sync
## 07-23-2018 @ 15:29:07 - 2.1.-1 - dscudiero - Comment out the restricted to user code
## 06-13-2019 @ 08:12:16 - 2.1.-1 - dscudiero - 
## 06-24-2019 @ 10:26:18 - 2.1.-1 - dscudiero - 
