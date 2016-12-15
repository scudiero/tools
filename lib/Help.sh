## XO NOT AUTOVERSION
#===================================================================================================
version=2.0.0 # -- dscudiero -- 11/07/2016 @ 14:37:19.89
#===================================================================================================
# Display script help -- passed an array of argument definitinons, see ParseArg function
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Help {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local parseDefs=("$@")
	local helpSet=$(echo $helpSet,script | tr ' ' ',')
	local tempStr="$(ColorK "Usage:") $myName"
	[[ $(Contains ",$helpSet," ",client,") == true ]] && hasClient=true && tempStr="$tempStr [client]"
	tempStr="$tempStr [OPTIONS]"

	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	Msg2; Msg2 "$tempStr"; Msg2
	## Print out header info
		[[ $shortDescription != '' ]] && Msg2 "$(ColorK "$shortDescription.")"
		[[ $longDescription != '' ]] && Msg2 && Msg2 "$longDescription" && Msg2
		[[ $scriptHelpDesc != '' ]] && Msg2 && Msg2 "$scriptHelpDesc" && Msg2
		[[ $author != '' ]] && Msg2 "$(ColorK "Author:") $author"
		[[ $supported != '' ]] && Msg2 "$(ColorK "Supported:") $supported"

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

	Msg2
	Msg2 "$(ColorK "[client]:")"
	Msg2 "^This is the client code (abbreviation) for the client that you wish to work with."


	## print them out
		#dump helpSet validArgs
		local optionsArray switchesArray argGroup argName minLen argType tempStr1 tempStr2 helpText msgString
		unset optionsArray switchesArray argGroup argName minLen argType tempStr1 tempStr2 helpText msgString
		## seperate out options from flags
		for parseStr in "${argList[@]}"; do
			argGroup=$(Lower $(echo $parseStr | cut  -d ',' -f 6))
			#dump parseStr -t argGroup
			[[ $argGroup != '' && $(Contains ",$helpSet," ",$argGroup,") == false ]] && continue
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
			[[ ${argType:0:6} == 'option' ]] && optionsArray+=("$msgString") || switchesArray+=("$msgString")
		done

	Msg2
	Msg2 "$(ColorK "[OPTIONS]:")"
	## Options
		if [[ ${#optionsArray[@]} -gt 0 ]]; then
			Msg2 "^$(ColorK "Arguments with values (i.e. a flag with value e.g. -flag value):")"
			for msgString in "${optionsArray[@]}"; do
				Msg2 "$msgString"
			done
		fi
	## Switches
		if [[ ${#switchesArray[@]} -gt 0 ]]; then
			Msg2
			Msg2 "^$(ColorK "Arguments without values (i.e. a flag e.g. -flag):")"
			for msgString in "${switchesArray[@]}"; do
				Msg2 "$msgString"
			done
		fi

	## print out script specific help notes
		if [[ ${#helpNotes[@]} -gt 0 ]]; then
			Msg2
			Msg2 "$(ColorK "Script specific notes:")"
			for ((cntr = 0 ; cntr < ${#helpNotes[@]} ; cntr++)); do
				let idx=$cntr+1
		 		Msg2 "^$idx) ${helpNotes[$cntr]}"
			done
		fi

	## General help notes for all scripts
		Msg2
		Msg2 "$(ColorK "General Notes:")"
		local notesClient notesAlways notes
		notesClient+=("The minimum abbreviations for argument flags are indicated in the $(ColorK highlight) color above.")
		notesClient+=("A value of '.' may be specified for client to parse the client value from the current working directory.")
		notesClient+=("A value of '?' may be specified for client to display a selection list of all clients.")

		notesAlways+=("All flags must be delimited from other flags by at lease one blank character.")
		notesAlways+=("While all flags may be specified, not all of them may active.")
		notesAlways+=("If a argument is an option with a value, and the value contains blanks/spaces, the argument value needs to be enclosed in single quotes which need to be escaped on the command line, e.g. -wo \'This is a File Name\'")

		notes=("${notesAlways[@]}")
		[[ $hasClient == true ]] && notes=("${notesClient[@]}" "${notes[@]}")

		idx=1
		for line in "${notes[@]}"; do
			Msg2 ",,+1,,true" "$idx) $line"
			((idx+=1))
		done
		Msg2

		Msg2 $V3 "*** $FUNCNAME -- Completed ***"
		return 0
} # Help
export -f Help

#===================================================================================================
# Check-in Log
#===================================================================================================
