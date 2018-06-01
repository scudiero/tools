##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=2.0.19 # -- dscudiero -- Thu 05/31/2018 @ 16:09:39.30
#=======================================================================================================================
TrapSigs 'on'
myIncludes="RunSql Colors FindExecutable SelectMenu ProtectedCall Pause"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Script dispatcher"

#=======================================================================================================================
# Tools scripts selection front end
#=======================================================================================================================
#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================

#=======================================================================================================================
# local functions
#=======================================================================================================================

	#==================================================================================================
	## Build the menu list from the database
	#==================================================================================================
	function BuildMenuArray {
		## Build scripts hash from the data files
			unset scriptsKeys 
			maxKeyIdLen=7
			maxScriptNameLen=11
			maxScriptDescLen=18

			dump 2 UsersAuthGroups
			for group in common ${UsersAuthGroups//,/ }; do
				dump 2 -n group
				ifs="$IFS"; IFS=$'\r'; while read line; do
					dump 2 -t line
					keyId="${line%%|*}"; line="${line#*|}"
					script="${line%%|*}"; line="${line#*|}"
					desc="${line%%|*}"; line="${line#*|}"					
					[[ $script == 'wizdebug' && $TERM == 'dumb' ]] && continue
					[[ ${scriptsHash["$script"]+abc} ]] && continue
					[[ ${#keyId} -gt $maxKeyIdLen ]] && maxKeyIdLen=${#keyId}
					[[ ${#script} -gt $maxScriptNameLen ]] && maxScriptNameLen=${#script}
					[[ ${#desc} -gt $maxScriptDescLen ]] && maxScriptDescLen=${#desc}
					scriptsKeys+=($script)
					scriptsHash["$script"]="${keyId}|${script}|${desc}"
				done < "$TOOLSPATH/auth/$group"
				IFS="$ifs"
			done
			menuItems=();
			menuItems+=("|");
			menuItems+=("$maxKeyIdLen|$maxScriptNameLen|$maxScriptDescLen");
			menuItems+=("Ordinal|Script Name|Script Description");
			for key in $(printf "%s\n" "${scriptsKeys[@]}" | sort -u); do
				menuItems+=("${scriptsHash[$key]}");
			done;
			DumpArray 2 menuItems[@]

		return 0
	} #BuildMenuArray

	#==================================================================================================
	## Execute a script
	#==================================================================================================
	function runScript {
		local name=$1; shift
		local userArgs="$1"
		local field fieldVal tmpStr lib

		local data="${scriptsHash["$scriptName"]}"
		data="${data#*|}"; data="${data#*|}"; data="${data#*|}";
		local exec="${data%%|*}"; data="${data#*|}"
		local lib="${data%%|*}"; data="${data#*|}"; 
		local args="${data%%|*}";

		[[ -n $args ]] && scriptArgs="$userArgs $args" || scriptArgs="$userArgs"

		## Parse the exec string for overrides, <scriptName> [<scriptArgs>]
			if [[ -n $exec ]]; then
				name="${exec%% *}"; args="${exec#* }"
				[[ $args != $name ]] && scriptArgs="$args $scriptArgs"
			fi

		## Find the exedcutable
			executeFile=$(FindExecutable '-source' "$name")
			[[ -z $executeFile || ! -r $executeFile ]] && { echo; echo; Terminate "$myName.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"; }

		## Override the log file
			logFileSave="$logFile"
			logFile=/dev/null
			if [[ $noLog != true ]]; then
				logFile="${logsRoot}${name}/$userName--$(date +"%m-%d-%Y@%H.%M.%S").log"
				[[ -e $logFile ]] && rm -f "$logFile"
				if [[ ! -d $(dirname $logFile) ]]; then
					mkdir -p "$(dirname $logFile)"
					chown -R "$userName:leepfrog" "$(dirname $logFile)"
					chmod -R 775 "$(dirname $logFile)"
				fi
				touch "$logFile"
				chown -R "$userName:leepfrog" "$logFile"
				chmod 660 "$logFile"
				echo -e "$(PadChar)" > $logFile
				[[ -n $scriptArgs ]] && scriptArgsTxt=" $scriptArgs" || unset scriptArgsTxt
				echo -e "$myName:\n^$executeFile\n^$(date)\n^^${callPgmName}${scriptArgsTxt}" >> $logFile
				echo -e "$(PadChar)" >> $logFile
				echo >> $logFile
			fi

		## Call the script
			myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
			myPath="$(dirname $executeFile)"
			(source $executeFile $scriptArgs) 2>&1 | tee -a $logFile
			mv $logFile $logFile.bak
		 	cat $logFile.bak | sed "s/\x1B\[[0-9;]*[a-zA-Z]//g" | tr -d '\007' > $logFile
			chown -R "$userName:leepfrog" "$logFile"
			chmod 660 "$logFile"
		 	rm $logFile.bak
		 	touch "$(dirname $logFile)"
			logFile="$logFileSave"

		return $?
	} #runScript

#=======================================================================================================================
# Declare variables and constants, bring in includes file with subs
#=======================================================================================================================
tmpFile=$(mkTmpFile)
unset scriptArgs
calledViaScripts=true
menuDisplayed=false
declare -A scriptsHash

#=======================================================================================================================
## parse arguments
#=======================================================================================================================
helpSet='script,client'
Hello
GetDefaultsData $myName -fromFiles
ParseArgsStd $originalArgStr
scriptArgs="$unknowArgs"

scriptNameIn="$client"
[[ -z $scriptNameIn && $batchMode == true ]] && Terminate "Running in batchMode and no value specified for report/script"

#==================================================================================================
## Main
#==================================================================================================
## If we do not have a report or script name then build & display the menu
	## Check to see if we have TOOLSPATH/bin in the path, if not added it
	unset pathSave
	menuItems=()
	grepStr=$(ProtectedCall "env | grep '^PATH=' 2> /dev/null")
	[[ $(Contains "$grepStr" "$TOOLSPATH/bin") != true ]] && pathSave="$PATH" && export PATH="$PATH:$TOOLSPATH/bin"
	loop=true
	while [[ $loop == true ]]; do
		if [[ -z $scriptNameIn
	 ]]; then
			unset scriptName
			[[ ${#menuItems[@]} -eq 0 ]] && BuildMenuArray
			ProtectedCall "clear"
			Msg
			[[ -n $UsersAuthGroups ]] && Info 0 1 "Your authorization groups are $(sed 's/,/, /g' <<< \"$UsersAuthGroups\")"
			Msg "\n^Please specify the $(ColorM '(ordinal)') number of the $itemType you wish to run, 'x' to quit."
			Msg
			#[[ $mode == 'scripts' && $client != '' ]] && clientStr=" (client: '$client')" || unset clientStr
			SelectMenu -fast -ordinalInData 'menuItems' 'scriptName'
			[[ -z $scriptName ]] && Goodbye 'x'
			menuDisplayed=true
		else
			## Otherwise use the passed in script/report
			scriptName=$scriptNameIn
			loop=false
		fi
		[[ $scriptName == 'REFRESHLIST' ]] && continue

		## Get additional arguments
			unset userArgs;
			if [[ $menuDisplayed == true ]]; then
				Msg
				Msg "^Please 'Enter' to optionally specify parameters to be passed to '$(ColorM $scriptName)'"
				unset userArgs; Prompt userArgs "^Please specify parameters to be passed to '$(ColorM $scriptName)'" '*optional*' '' '3'
				[[ -n $userArgs ]] && scriptArgs="$userArgs $scriptArgs"
				echo
			fi
		## Call function to fulfill the request
			runScript "$scriptName" "$scriptArgs" ; rc=$?
			[[ $menuDisplayed == true ]] && { Msg; Pause "Please press enter to go back to 'scripts'"; }
	done


#==================================================================================================
## Bye-bye
[[ -n $pathSave ]] && export PATH="$pathSave"
Goodbye 0
## 06-01-2018 @ 09:34:59 - 2.0.19 - dscudiero - Copy full scripts functionality and make standaole
