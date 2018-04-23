## XO NOT AUTOVERSION
#===================================================================================================
# version=3.0.5 # -- dscudiero -- Fri 03/23/2018 @ 16:51:21.13
#===================================================================================================
# Display script help -- passed an array of argument definitinons, see ParseArg function
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Help2 {
	mode="${1-normal}"

	includes='StringFunctions Colors'
	Import "$includes"

	[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName 'setVarsOnly'
	[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME 'setVarsOnly'

	local argShortName shortNamePad argLongName longNamePad argType typePad argVar argCmd arghelpText tmpStr

	local myHelpSet="common,script,$(tr ' ' ',' <<< $helpSet)"
	local tempStr="$(ColorK "Usage:") $myName"

	includes='Msg Colors StringFunctions'
	Import "$includes"

	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	echo; echo
	Msg "$myName version: $version"
	[[ $updatesClData == 'Yes' ]] && Warning "This script updates client side data"
	echo

	sqlStmt="select restrictToUsers,restrictToGroups from $scriptsTable where name=\"$myName\""
	RunSql $sqlStmt
	if [[ -n ${resultSet[0]} ]]; then
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

	## Get the max lengths of the name and min abbreviation from the database
		sqlStmt="select max(length(longname)),max(length(shortname)),max(length(type)) from argdefs"
		RunSql $sqlStmt
		result="${resultSet[0]}";
		maxWidthName="${result%%|*}"; result="${result##*|}"
		maxWidthAbbr="${result%%|*}"; result="${result##*|}"
		maxWidthType="${result}"
		tmpStr='Long Name'; [[ ${#tmpStr} -gt $maxWidthName ]] && maxWidthName=${#tmpStr}
		tmpStr='Short Name'; [[ ${#tmpStr} -gt $maxWidthAbbr ]] && maxWidthAbbr=${#tmpStr}
		tmpStr='Type'; [[ ${#tmpStr} -gt $maxWidthType ]] && maxWidthType=${#tmpStr}
		#dump result maxWidthName maxWidthAbbr maxWidthType -q

	## If we have a myArgs array then check the script defined arguments to set max lengths
		if [[ ${#myArgs[@]} -gt 0 ]]; then
			for ((i=0; i<${#myArgs[@]}; i++)); do
				tmpStr="${myArgs[$i]}"
				argShortName="${tmpStr%%|*}"; tmpStr=${tmpStr#*|}; [[ ${#argShortName} -gt $maxWidthAbbr ]] && maxWidthAbbr=${#argShortName}
				argLongName="${tmpStr%%|*}"; tmpStr=${tmpStr#*|}; [[ ${#argLongName} -gt $maxWidthName ]] && maxWidthName=${#argLongName}
				argType="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; [[ ${#argType} -gt $maxWidthType ]] && maxWidthType=${#argType}
			done
		fi

	## Add a pad char to lengths
 		(( maxWidthName++ ))
  		(( maxWidthAbbr++ ))
  		(( maxWidthType++ ))

	echo
	if [[ $hasClient == true ]]; then
		Msg "$(ColorK "[client]:")"
		Msg "^This is the client code (abbreviation) for the client that you wish to work with."
	fi
	echo
	Msg "$(ColorK "[OPTIONS]")"

	## argument header
	argShortName="Short Name"; let shortNamePad=$maxWidthAbbr-${#argShortName};
	argLongName="Long Name"; let longNamePad=$maxWidthName-${#argLongName};
	argType="Type"; let typePad=$maxWidthType-${#argType};
	local argHeader="$(ColorK "${argLongName}$(PadChar ' ' $longNamePad) (${argShortName})$(PadChar ' ' $shortNamePad) ${argType}$(PadChar ' ' $typePad) -- Description")"

	#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	if [[ ${#myArgs[@]} -gt 0 ]]; then
		Msg "^$(ColorU "$(ColorK "Script specific options:")")"
		Msg "^$argHeader"
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		for ((i=0; i<${#myArgs[@]}; i++)); do
			tmpStr="${myArgs[$i]}"
			argShortName="${tmpStr%%|*}"; tmpStr=${tmpStr#*|}; let shortNamePad=$maxWidthAbbr-${#argShortName};
			argLongName="${tmpStr%%|*}"; tmpStr=${tmpStr#*|}; let longNamePad=$maxWidthName-${#argLongName};
			argType="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; let typePad=$maxWidthType-${#argType};
			argVar="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; [[ $argVar == 'NULL' ]] && unset argVar;
			argCmd="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; [[ $argCmd == 'NULL' ]] && unset argCmd;
			argHelpGrp="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; [[ $argHelpGrp == 'NULL' ]] && unset argHelpGrp;
			arghelpText="${tmpStr%%|*}"; [[ $arghelpText == 'NULL' ]] && unset arghelpText;
			#dump -t argShortName shortNamePad argLongName longNamePad argType argVar argCmd arghelpText
			tmpStr="${argLongName}$(PadChar ' ' $longNamePad) (${argShortName})$(PadChar ' ' $shortNamePad) ${argType}$(PadChar ' ' $typePad) -- $arghelpText"
			Msg "^$tmpStr"
		done
	fi

	## Loop through the commn argument defs
	Msg
	Msg "^$(ColorU "$(ColorK "Common tools scripts options:")")"
	Msg "^$argHeader"
	[[ -n $validArgs ]] && validArgsLower="${validArgs,,[a-z]}"  ## Lower case
	#argDefs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	for ((i=0; i<${#argDefs[@]}; i++)); do
		tmpStr="${argDefs[$i]}"
		argShortName="${tmpStr%%|*}"; tmpStr=${tmpStr#*|}; let shortNamePad=$maxWidthAbbr-${#argShortName};
		argLongName="${tmpStr%%|*}"; tmpStr=${tmpStr#*|}; let longNamePad=$maxWidthName-${#argLongName};
		[[ $validArgsLower != '' && $(Contains ",$validArgsLower," ",${argName,,[a-z]},") != true ]] && continue
		argType="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; let typePad=$maxWidthType-${#argType};
		argVar="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; [[ $argVar == 'NULL' ]] && unset argVar;
		argCmd="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; [[ $argCmd == 'NULL' ]] && unset argCmd;
		argHelpGrp="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"; [[ $argHelpGrp == 'NULL' ]] && unset argHelpGrp;
		arghelpText="${tmpStr%%|*}"; [[ $arghelpText == 'NULL' ]] && unset arghelpText;
		#dump -t argShortName shortNamePad argLongName longNamePad argType argVar argCmd arghelpText
		tmpStr="${argLongName}$(PadChar ' ' $longNamePad) (${argShortName})$(PadChar ' ' $shortNamePad) ${argType}$(PadChar ' ' $typePad) -- $arghelpText"
		Msg "^$tmpStr"
	done

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
	# notesClient+=("A value of '.' may be specified for client to parse the client value from the current working directory.")
	# notesClient+=("A value of '?' may be specified for client to display a selection list of all clients.")

	notesAlways+=("All options $(ColorB "must") be delimited from other options by at lease one blank character.")
	notesAlways+=("Options are processed in the order given above, script specific options are parsed before common options.")
	notesAlways+=("All options of the type 'switch' may be specified as -shortName, alternately they may be specified as --longName.  Regular expression matching is used.")
	notesAlways+=("All options of the type 'option' require a value to be passed, i.e. -option value.\n^   If the value contains blanks/spaces, the argument value needs to be enclosed in single quotes which need to be escaped on the command line, e.g. -file \'This is a File Name\'.")
	notesAlways+=("Options listed in the 'Common tools scripts options' section may not apply this specific script.")
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
		Msg "$(ColorK "Tools library modules used by this script (via tools/lib):")"
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
			Msg "$(ColorK "Python resources used by this script:")"
			grep '^import' "$TOOLSPATH/src/python/getXlsx2.py" | Indent
			echo
		fi
	fi

	return 0
} # Help
export -f Help2

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:41 CST 2017 - dscudiero - General syncing of dev to prod
## 08-30-2017 @ 13.53.59 - (2.0.2)     - dscudiero - treat scriptHelpDescription as an array
## 08-30-2017 @ 14.07.33 - (2.0.6)     - dscudiero - Tweak output format
## 09-01-2017 @ 09.27.30 - (2.0.8)     - dscudiero - Add call myname-FUNCNAME function if found
## 09-01-2017 @ 09.38.26 - (2.0.9)     - dscudiero - Fix spelling error
## 09-25-2017 @ 08.14.09 - (2.1.-1)    - dscudiero - Use Msg
## 11-02-2017 @ 10.27.27 - (3.0.0)     - dscudiero - Initial implimentation
## 03-19-2018 @ 11:17:45 - 3.0.1 - dscudiero - Update how java dependencies are calculated
## 03-19-2018 @ 11:19:26 - 3.0.2 - dscudiero - Cosmetic/minor change/Sync
## 03-19-2018 @ 12:01:59 - 3.0.3 - dscudiero - CHange the way we find the python dependencies
## 03-22-2018 @ 13:42:17 - 3.0.4 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 16:52:17 - 3.0.5 - dscudiero - Msg3 -> Msg
## 04-23-2018 @ 09:39:12 - 3.0.5 - dscudiero - Cosmetic/minor change/Sync
