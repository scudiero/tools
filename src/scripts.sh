##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version="2.1.16" # -- dscudiero -- Thu 04/04/2019 @ 12:13:47
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
		## Build menu items list from the users UsersScripts array
			local columns headers token subToken maxLen i
			columns=('Ordinal' 'Script Name' 'Script Description')
			for ((i=1; i<${#columns[@]}+1; i++)); do 
				eval "local maxLenCol$i"
				eval "maxLenCol$i=${#columns[$i-1]}"
				header="$header|${columns[$i-1]}"
			done;
			header="${header:1}"
			Msg "Retrieving script list..."
			sqlStmt="select keyId,name,description,showInScripts from scripts where (keyId in"
			sqlStmt+=" (select scriptKey from auth2script where groupKey in (select authKey from auth2user where empKey=31))"
			sqlStmt+=" or"
			sqlStmt+=" (keyId in (select scriptKey from user2script where empKey=31))"
			sqlStmt+=" or"
			sqlStmt+=" (keyId not in (select scriptKey from auth2script) and keyId not in (select scriptKey from user2script))"
			sqlStmt+=" and"
			sqlStmt+=" name not in (\"loader\",\"dispatcher\")"
			sqlStmt+=" ) order by name"
			dump 2 -n sqlStmt -n
			RunSql $sqlStmt
			for rec in "${resultSet[@]}"; do UsersScripts+=("$rec"); done

			## Find the max widths of each column for SelectMenu
			menuItems=();
			for token in "${UsersScripts[@]}"; do
				showInScripts="${token##*|}"; token="${token%|*}"
				[[ $showInScripts != 'Yes' ]] && continue
				dump 2 -n token
				unset menuItem
				for ((i=1; i<${#columns[@]}+1; i++)); do
					subToken="${token%%|*}"; token="${token#*|}";
					eval "col${i}data=${#subToken}";
					eval "maxLen=\$maxLenCol$i"
					[[ ${#subToken} -gt $maxLen ]] && { eval "maxLenCol$i=${#subToken}"; }
					dump 2 -t i subToken -t maxLen maxLenCol$i
					menuItem="$menuItem|$subToken"
				done
				menuItems+=("${menuItem:1}")
			done
			menuItems=('Ordinal|Script Name|Script Description' "${menuItems[@]}");
			menuItems=("$maxLenCol1|$maxLenCol2|$maxLenCol3" "${menuItems[@]}");
			menuItems=('|' "${menuItems[@]}")
			#for ((xx=0; xx<${#menuItems[@]}; xx++)); do echo "menuItems[$xx] = >${menuItems[$xx]}<"; done; Pause

		return 0
	} #BuildMenuArray

	#==================================================================================================
	## Execute a script
	#==================================================================================================
	function runScript {
		local name=$1; shift
		local userArgs="$1"
		local field fieldVal tmpStr lib exec args

		# local data="${scriptsHash["$scriptName"]}"
		# data="${data#*|}"; data="${data#*|}"; data="${data#*|}";
		# local exec="${data%%|*}"; data="${data#*|}"
		# local lib="${data%%|*}"; data="${data#*|}"; 
		# local args="${data%%|*}";

		[[ -n $args ]] && scriptArgs="$userArgs $args" || scriptArgs="$userArgs"

		## Parse the exec string for overrides, <scriptName> [<scriptArgs>]
			if [[ -n $exec ]]; then
				name="${exec%% *}"; args="${exec#* }"
				[[ $args != $name ]] && scriptArgs="$args $scriptArgs"
			fi
			dump 2 name
			
		## Check to make sure we can run
			checkMsg=$(CheckRun $name)
			if [[ -n $checkMsg && $checkMsg != true ]]; then
				if [[ $(Contains ",$administrators," ",$userName,") == true ]]; then
					echo; Warning "$checkMsg"; echo; Alert 2;
				else
					[[ $name != 'testsh' ]] && { echo; Error "$checkMsg"; return 0; }
				fi
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
# GetDefaultsData $myName #-fromFiles
source <(CallC toolsSetDefaults $myName);
# ParseArgsStd $originalArgStr
source <(CallC parseArgs $originalArgStr); client="${unknownArgs%% *}"; unknownArgs="${unknownArgs##* }"
scriptArgs="$unknowArgs"
Hello

scriptNameIn="$client"
[[ -z $scriptNameIn && $batchMode == true ]] && Terminate "Running in batchMode and no value specified for report/script"

#==================================================================================================
## Main
#==================================================================================================
## If we do not have a report or script name then build & display the menu
	## Check to see if this user has the scripts alias setup 
	pathSave="$PATH"
	export PATH="$PATH:$TOOLSPATH/bin"
	if [[ -z $TOOLSPATH ]]; then
		Prompt ans "^Do you wish to add an alias to your .bashrc file to make it easier to run 'scripts' in the future" "Yes,No";
		ans=${ans,,[a-z]} ans=${ans:0:1};
		if [[ $ans == 'y' ]]; then
			echo "export TOOLSPATH=\"/steamboat/leepfrog/docs/tools\" ## Added by' '$myName' on $(date)" #>> "$HOME/.bashrc"
			echo "alias scripts=\"$TOOLSPATH/bin/scripts\" ## Added by' '$myName' on $(date)" #>> "$HOME/.bashrc"
			Info 0 1 "In the future you will able to start 'scripts' by just typing 'scripts' on the command line and pressing 'enter'\n"
		fi	
	fi
	
	loop=true
	while [[ $loop == true ]]; do
		if [[ -z $scriptNameIn
	 ]]; then
			unset scriptName
			[[ ${#menuItems[@]} -eq 0 ]] && BuildMenuArray
			ProtectedCall "clear"
			Msg; Msg;
			SelectMenu -fast -ordinalInData 'menuItems' 'scriptName'
			[[ -z $scriptName ]] && Goodbye 'x'
			menuDisplayed=true
		else
			## Otherwise use the passed in script/report
			scriptName=$scriptNameIn
			loop=false
		fi
		[[ $scriptName == 'REFRESHLIST' ]] && continue

		# ## Get additional arguments
		# 	unset userArgs;
		# 	if [[ $menuDisplayed == true ]]; then
		# 		Msg
		# 		Msg "^Please 'Enter' to optionally specify parameters to be passed to '$(ColorM $scriptName)'"
		# 		unset userArgs; Prompt userArgs "^Please specify parameters to be passed to '$(ColorM $scriptName)'" '*optional*' '' '3'
		# 		[[ -n $userArgs ]] && scriptArgs="$userArgs $scriptArgs"
		# 		echo
		# 	fi
		## Call function to fulfill the request
			runScript "$scriptName" "$scriptArgs" ; rc=$?
			[[ $menuDisplayed == true ]] && { Msg; Pause "Please press enter to go back to 'scripts'"; }
	done


#==================================================================================================
## Bye-bye
[[ -n $pathSave ]] && export PATH="$pathSave"
Goodbye 0
## 06-01-2018 @ 09:34:59 - 2.0.19 - dscudiero - Copy full scripts functionality and make standaole
## 06-01-2018 @ 10:10:56 - 2.0.22 - dscudiero - Fix problem because we did not add exec,lib,args to the scripts data
## 06-13-2018 @ 13:52:37 - 2.0.23 - dscudiero - Cosmetic/minor change/Sync
## 06-18-2018 @ 08:13:08 - 2.0.70 - dscudiero - Change how menu item calculation
## 06-18-2018 @ 10:51:28 - 2.0.70 - dscudiero - Filter out the scripts wint showInScripts = No
## 06-18-2018 @ 16:14:35 - 2.0.70 - dscudiero - Check if we can run the selected script
## 06-18-2018 @ 16:16:53 - 2.0.70 - dscudiero - Cosmetic/minor change/Sync
## Tue Jul 17 08:33:28 CDT 2018 - dscudiero - -m Tweak the display of the users groups
## 11-07-2018 @ 14:34:14 - 2.0.72 - dscudiero - Remove -fromFiles from GetDefaultsData call
## 12-03-2018 @ 07:52:35 - 2.0.78 - dscudiero - Pull logic to determin the script list into the script script
## 12-03-2018 @ 10:31:02 - 2.0.79 - dscudiero - Comment out the display of the users auth groups
## 12-03-2018 @ 11:55:24 - 2.1.1 - dscudiero - Comment out the additional arguments question
## 12-07-2018 @ 07:24:08 - 2.1.2 - dscudiero - Switch to use toolsSetDefaults module
## 12-07-2018 @ 10:18:26 - 2.1.3 - dscudiero - Add dump of sqlStmt
## 12-07-2018 @ 10:32:00 - 2.1.4 - dscudiero - Add debug stuff
## 12-07-2018 @ 10:39:56 - 2.1.5 - dscudiero - Remove debug stuff
## 02-07-2019 @ 12:11:24 - 2.1.14 - dscudiero - Update the code that automatically adds the scripts alias to the users .bashrc file
## 04-04-2019 @ 12:14:40 - 2.1.16 - dscudiero - Fix problem with determining if we should prompt the user to set the scripts alias
