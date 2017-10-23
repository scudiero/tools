#!/bin/bash
# DX NOT AUTOVERSION
#=======================================================================================================================
version=3.13.31 # -- dscudiero -- Mon 10/23/2017 @  8:35:53.78
#=======================================================================================================================
TrapSigs 'on'
myIncludes="RunSql2 Colors PushPop SetFileExpansion FindExecutable SelectMenuNew ProtectedCall Pause"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Script dispatcher"

dump originalArgStr

#=======================================================================================================================
# Tools scripts selection front end
#=======================================================================================================================
# 05-28-14 - dgs - Initial coding
# 07-17-15 - dgs - Migrated to framework 5
#=======================================================================================================================
#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
function parseArgs-scriptsAndReports {
	# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
	argList+=(-emailAddrs,1,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	argList+=(-noArgs,1,switch,noArgs,,script,'Do not prompt for additional arguments to send to the script/report')
}
function Goodbye-scriptsAndReports  { # or Goodbye-local
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	return 0
}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#==================================================================================================
## Build the menu list from the database
#==================================================================================================
function BuildMenuList {
	Msg3 "^Building script list..."
	## Eliminate things that do not work on windows if running from windows
		[[ $TERM == 'dumb' ]] && excludeWindowsStuff="and $scriptsTable.name not in (\"wizdebug\")" || unset excludeWindowsStuff

	## Get a list of scripts available to this user in the execution environment we are running in
		unset whereClauseHost; unset whereClauseUser; unset whereClauseGroups
		whereClauseActive="active = \"Yes\" and name != \"$mode\""
		whereClauseActive="$whereClauseActive and showInScripts=\"Yes\""
		# If reports build the auth where clauses
		if [[ $mode == 'scripts' ]]; then
			whereClauseHost="and (os=\"$osName\" and (host = \"$hostName\" or host is null))"
			whereClauseUser="and (restrictToUsers like \"%$userName%\" or restrictToUsers is null)"

			sqlStmt="select code from $authGroupsTable where members like \"%,$userName,%\" "
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -ne 0 ]]; then
				for result in "${resultSet[@]}"; do
					[[ -z $whereClauseGroups ]] && whereClauseGroups="restrictToGroups like \"%$result%\"" || \
													  whereClauseGroups="$whereClauseGroups or restrictToGroups like \"%$result%\""
				done
				whereClauseGroups="and ($whereClauseGroups or restrictToGroups is null)"
			fi
		fi

		fields="keyId,name,shortDescription,author,supported,edate,updatesClData"
		unset $(tr ',' ' ' <<< "$fields")
		sqlStmt="select $fields from $table where $whereClauseActive $whereClauseHost $whereClauseUser $whereClauseGroups order by name"
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Sorry, either no scripts are active or you do not have access to any scripts."

		unset menuList
		menuList+=('|Ordinal|Script Name|Description')
		newItem=false
		for itemRec in "${resultSet[@]}"; do
			itemRec=$(tr "\t" "|" <<< "$itemRec")
			unset itemNum itemName itemDesc itemAuthor itemSupported itemEdate
			itemNum=$(cut -d"|" -f1 <<< "$itemRec")
			itemName=$(cut -d"|" -f2 <<< "$itemRec")
			itemDesc=$(cut -d"|" -f3 <<< "$itemRec")
			itemEdate=$(cut -d"|" -f6 <<< "$itemRec")
			itemUpdates=$(cut -d"|" -f7 <<< "$itemRec")
			#dump -n itemName itemEdate ${myName}LastRunEdate
			[[ $itemEdate != 'NULL' && $itemEdate -gt ${myName}LastRunEdate ]] && itemName="${itemName}*" && newItem=true
			menuList+=("|$itemNum|$itemName|$itemDesc")
		done
	return 0
} #BuildMenuList

#==================================================================================================
## Execute a script
#==================================================================================================
function ExecScript {
	local name=$1; shift
	local userArgs="$1"
	local field fieldVal tmpStr

	## Lookup detailed script info from db
		local fields="exec,lib,scriptArgs"
		local sqlStmt="select $fields from $scriptsTable where lower(name) =\"$(Lower $name)\" "
		RunSql2 $sqlStmt
		[[ ${#resultSet[0]} -eq 0 ]] &&Terminate "Could not lookup script name ('$name') in the $mySqlDb.$scriptsTable"
		resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString" )
		local fieldCntr=1
		for field in $(tr ',' ' ' <<< $fields); do
			eval local $field; eval unset $field
			fieldVal=$(cut -d'|' -f$fieldCntr <<< "$resultString")
			[[ $fieldVal == 'NULL' ]] && fieldVal=''
			eval $field=\"$fieldVal\"
			((fieldCntr += 1))
		done
		[[ -n $scriptArgs ]] && scriptArgs="$scriptArgs $userArgs" || scriptArgs="$userArgs"

	## Parse the exec string for overrides, <scriptName> <scriptArgs>
		if [[ -n $exec ]]; then
			name=$(cut -d' ' -f1 <<< "$exec")
			local tmpStr="$(cut -d' ' -f2- <<< "$exec")"
			[[ -n $tmpStr ]] && scriptArgs="$tmpStr $scriptArgs"
		fi

	## Find the exedcutable
		executeFile=$(FindExecutable '-source' "$name")
		[[ -z $executeFile || ! -r $executeFile ]] && { echo; echo; Terminate "$myName.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"; }

	## Override the log file
		logFileSave="$logFile"
		logFile=/dev/null
		if [[ $noLog != true ]]; then
			logFile=${logsRoot}${name}/$userName--$backupSuffix.log
			[[ -e $logFile ]] && rm -f "$logFile"
			if [[ ! -d $(dirname $logFile) ]]; then
				mkdir -p "$(dirname $logFile)"
				chown -R "$userName:leepfrog" "$(dirname $logFile)"
				chmod -R ug+rwx "$(dirname $logFile)"
			fi
			touch "$logFile"
			chmod ug+rwx "$logFile"
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
		chmod ug+rwx "$logFile"
	 	rm $logFile.bak
	 	touch "$(dirname $logFile)"
		logFile="$logFileSave"

	return $?
} #ExecScript

#==================================================================================================
## Execute a report
#==================================================================================================
function ExecReport {
	local name=$1; shift
	local additionalArgs="$*"
	[[ -n ${additionalArgs}${client} ]] && additionalArgs="$client $additionalArgs"
	[[ -z $additionalArgs && -n $client ]] && additionalArgs="$client"
	local exec rc

	## Lookup detailed script info from db
		local fields="shortDescription,type,header,db,dbType,sqlStmt,script,scriptArgs,ignoreList"
		local sqlStmt="select $fields from $reportsTable where lower(name) =\"$(Lower $name)\" "
		RunSql2 $sqlStmt
		[[ ${#resultSet[0]} -eq 0 ]] && Terminate "Could not lookup report name ('$name') in the $mySqlDb.$reportsTable"
		myData="Name: '$name' "
		[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'Update' $myLogRecordIdx "$myData"
		resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString" )
		local fieldCntr=1
		for field in $(tr ',' ' ' <<< $fields); do
			eval local $field; eval unset $field
			eval $field=\"$(cut -d'|' -f$fieldCntr <<< "$resultString")\"
			((fieldCntr += 1))
		done

		if [[ $scriptArgs == '<prompt>' ]]; then
			unset scriptArgs;
			if [[ $(Contains ",$noArgPromptList," ",$itemName,") != true && $batchMode != true  && $quiet != true ]]; then
				Msg3 "^Optionally, please specify any arguments that you wish to pass to '$itemName'";
				unset userArgs; Prompt userArgs "^Please specify parameters to be passed to '$itemName'" '*optional*' '' '4'
			fi
		fi

	## Run report
		outDir="$HOME/Reports/$name"
		[[ ! -d $outDir ]] && mkdir -p "$outDir"
		outFileXlsx="$outDir/$(date '+%Y-%m-%d@%H.%M.%S').xls"
		outFileText="$outDir/$(date '+%Y-%m-%d@%H.%M.%S').txt"

		## Report record defines a query
		if [[ $type == 'query' ]]; then
			if [[ $dbType == 'mysql' ]]; then
				RunSql2 $sqlStmt
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					resultSet=("$(tr ',' '|' <<< "$header")" "${resultSet[@]}")
					[[ -f $tmpFile ]] && rm $tmpFile
					for ((i=0; i<${#resultSet[@]}; i++)); do
						echo "${resultSet[$i]}" >> "$tmpFile"
					done
				fi
			else
				Terminate "dbType type of '$dbType' not supported at this time"
			fi
			ignoreList='returnsRaw'
		## Report record is to run a script
		elif [[ $type == 'script' ]]; then
			reportScript=$(cut -d'|' -f 7 <<< "$resultString")
			reportArgs=$(cut -d'|' -f 8 <<< "$resultString"); [[ $reportArgs == 'NULL' ]] && unset reportArgs
			reportIgnoreList=$(cut -d'|' -f 9 <<< "$resultString") ; [[ $reportIgnoreList == 'NULL' ]] && unset reportIgnoreList
			## Call script
			scriptArgs="-reportName $name -noHeaders"
			if [[ $(Lower "$reportIgnoreList") == 'standalone' ]]; then
				FindExecutable $reportScript -report $originalArgStr $reportArgs $scriptArgs | tee "$tmpFile"
			else
				FindExecutable $reportScript -report $originalArgStr $reportArgs $scriptArgs > "$tmpFile"
			fi
		else
			Terminate "Report type of '$type' not supported at this time"
		fi

		if [[ $(wc -l < "$tmpFile") -gt 1 ]]; then
			if [[  $(Lower "$ignoreList") == 'returnsraw' ]]; then
				Msg3 | tee "$outFileXlsx" > "$outFileText"
				Msg3 "$name report run by $userName on $(date +"%m-%d-%Y") at $(date +"%H.%M.%S")" | tee -a "$outFileXlsx" >> "$outFileText"
				Msg3 "($shortDescription)" | tee -a "$outFileXlsx" >> "$outFileText"
				Msg3  | tee -a "$outFileXlsx" >> "$outFileText"
				sed s"/|/\t/g" < "$tmpFile" >> "$outFileXlsx"
				mapfile -t resultSet < "$tmpFile"
				PrintColumnarData 'resultSet' '|' >> "$outFileText"
			else
				cp -fp "$tmpFile" "$outFileText"
				cp -fp "$tmpFile" "$outFileXlsx"
			fi
			[[ $quiet != true ]] && cat "$outFileText"
			sendMail=true
		else
			Warning "No data returned from report script"
		fi

	return 0
} #ExecReport

#=======================================================================================================================
# Declare variables and constants, bring in includes file with subs
#=======================================================================================================================
tmpFile=$(mkTmpFile)
askedDisplayWidthQuestion=false

mode=$(tr '[:upper:]' '[:lower:]' <<< "$1")
[[ $mode == 'reports' || $mode == 'scripts' ]] && shift && originalArgStr="$*"
[[ -z $mode ]] && mode='scripts'
[[ $mode != 'scripts' && $mode != 'reports' ]] && Terminate "Invalid mode ($mode) specified on call"

## Check to see if the first argument is a report name
	## Is it a client name?
	# sqlStmt="select count(*) from $clientInfoTable where LOWER(name)=\"$(Lower $1)\" and recordStatus=\"A\""
	# RunSql2 $sqlStmt
	# count=${resultSet[0]}
	# ## Not a client name, look for report or script name
	# if [[ $count -eq 0 ]]; then
	# 	if [[ $mode == 'scripts' ]]; then
	# 		sqlStmt="select count(*) from $scriptsTable where LOWER(name)=\"$(Lower $1)\" and active=\"Yes\" and showInScripts=\"Yes\""
	# 		RunSql2 $sqlStmt
	# 		count=${resultSet[0]}
	# 		[[ $count -ne 0 ]] && script=$1 && shift && originalArgStr="$*"
	# 	elif [[ $mode == 'reports' ]]; then
	# 		unset report
	# 		sqlStmt="select count(*) from $reportsTable where LOWER(name)=\"$(Lower $1)\" and active=\"Yes\""
	# 		RunSql2 $sqlStmt
	# 		count=${resultSet[0]}
	# 		[[ $count -ne 0 ]] && report=$1 && shift && originalArgStr="$*"
	# 	fi
	# fi

## Set tables based on mode
	if [[ $mode == 'scripts' ]]; then
		itemType='script'
		itemTypeCap='Script'
		table=$scriptsTable
	elif [[ $mode == 'reports' ]]; then
		itemType='report'
		itemTypeCap='Report'
		table=$reportsTable
	fi

noArgPromptList="_clearClientValue_"
unset scriptArgs

#=======================================================================================================================
## Check to see the user has access to the 'scripts' program, if not then add one to their .bashrc file
#=======================================================================================================================
if [[ $batchMode != true ]]; then
	previousTrapERR=$(trap -p ERR | cut -d ' ' -f3-) ; trap - ERR ; set +e
	grep -q 'scripts="$TOOLSPATH/bin/scripts"' $HOME/.bashrc ; rc=$?
	[[ -n $previousTrapERR ]] && eval "trap $previousTrapERR"
	if [[ $rc -gt 0 ]]; then
		Msg3
		Msg3 "Do you wish to add an alias to the scripts command to your .bashrc file (recommended) ?"
		Msg3 "This will allow you to access the scripts command in the future by simply entering 'scripts' on the Linux command line."
		Msg3
		unset ans; Prompt ans "Yes to add, No to skip" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
		if [[ $ans == 'y' ]]; then
			echo '' >> $HOME/.bashrc
			echo "export TOOLSPATH=\"$TOOLSPATH\" ## Added by' '$myName' on $(date)" >> $HOME/.bashrc
			echo "alias scripts=\"\$TOOLSPATH/bin/scripts\" ## Added by' '$myName' on $(date)" >> $HOME/.bashrc
			Msg3
			Info "An alias for the scripts command has been added to your '$HOME/.bashrc' file."
			Msg3
		fi
	fi
else
	[[ -z ${script}${report} ]] && Terminate "Running in batchMode and no value specified for report/script"
fi

#=======================================================================================================================
## parse arguments
#=======================================================================================================================
Hello
helpSet='script,client'
parseQuiet=true
GetDefaultsData $myName -fromFiles
ParseArgsStd

[[ $newsDisplayed == true ]] && Pause "\nNews was displayed, please review and press any key to continue"
[[ $mode == 'scripts' && -n $client ]] && Init 'getClient'
#[[ $mode == 'reports' && $client != '' ]] && report="$client"

dump -1 mode report script originalArgStr itemType itemTypeCap table
dump -1 client report emailAddrs myName ${myName}LastRunDate ${myName}LastRunEDate

#==================================================================================================
## Main
#==================================================================================================
## If we do not have a report or script name then build & display the menu
	## Check to see if we have TOOLSPATH/bin in the path, if not added it
	unset pathSave
	grepStr=$(ProtectedCall "env | grep '^PATH=' 2> /dev/null")
	[[ $(Contains "$grepStr" "$TOOLSPATH/bin") != true ]] && pathSave="$PATH" && export PATH="$PATH:$TOOLSPATH/bin"
	loop=true
	while [[ $loop == true ]]; do
		if [[ -z ${report}${script} ]]; then
			unset itemName
			[[ ${#menuList[@]} -eq 0 ]] && BuildMenuList
			ProtectedCall "clear"
			Msg3
			Msg3 "\n^Please specify the $(ColorM '(ordinal)') number of the $itemType you wish to run, 'x' to quit."
			[[ $newItem == true ]] && Note "0 1" "Items with an '*' are new since the last time you ran '${itemType}s'"
			Msg3
			#[[ $mode == 'scripts' && $client != '' ]] && clientStr=" (client: '$client')" || unset clientStr
			SelectMenuNew 'menuList' 'itemName'
			[[ -z $itemName ]] && Goodbye 'x'
			itemName=$(cut -d ' ' -f1 <<< $itemName)
			length=${#itemName}
			[[ ${itemName:$length-1:1} == '*' ]] && itemName=${itemName:0:$length-1}
			Msg3
			menuDisplayed=true
		else
			## Otherwise use the passed in script/report
			itemName="${report}${script}"
			loop=false
			menuDisplayed=false
		fi
		[[ $itemName == 'REFRESHLIST' ]] && continue
		unset userArgs;
		if [[ $(Contains ",$noArgPromptList," ",$itemName,") != true && $batchMode != true  && $quiet != true && $noArgs != true ]]; then
			Msg3 "^Optionally, please specify any arguments that you wish to pass to '$itemName'";
			unset userArgs; Prompt userArgs "^Please specify parameters to be passed to '$itemName'" '*optional*' '' '3'
			[[ -n $userArgs ]] && scriptArgs="$userArgs $scriptArgs"
		fi

		## call function to 'execute' the request
		calledViaScripts=true
		#itemName="$(echo -e $itemName | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")"
		#TrapSigs 'off'

		sendMail=false
		Exec$itemTypeCap "$itemName" "$scriptArgs" ; rc=$?
		#TrapSigs 'on'
		Msg3
		# [[ $rc -eq 0 ]] && Msg3 "Execution of '$(echo $itemName | cut -d' ' -f1)' completed successfully" || \
		# 	Msg3 "Execution of '$(echo $itemName | cut -d' ' -f1)' completed with errors (exit code = $rc) \
		# 	\nPlease record any Messages and contact the $itemType owner\n"
		[[ $menuDisplayed == true ]] && Pause "Please press enter to go back to '${itemType}s'"
		unset calledViaScripts

		## Send out emails
		if [[ -n $emailAddrs && $mode == 'reports' && $noEmails == false && $sendMail == true ]]; then
			Msg3 | tee -a $outFileText; Msg3 "Sending email(s) to: $emailAddrs" | tee -a $outFileText; Msg3 | tee -a "$outFileText"
			for addr in $(tr ',' ' ' <<< "$emailAddrs"); do
				[[ $(Contains "$addr" '@') != true ]] && addr="$addr@leepfrog.com"
				$DOIT mutt -a "$outFileXlsx" -s "$report report results: $(date +"%m-%d-%Y")" -- $addr < "$outFileText"
			done
		fi
		#[[ -f $outFileText ]] && rm -f "$outFileText"
	done


#==================================================================================================
## Bye-bye
[[ -n $pathSave ]] && export PATH="$pathSave"
Goodbye 0

#==================================================================================================
# 08-07-2015 -- dscudiero -- touch up formatting (3.3)
# 10-16-2015 -- dscudiero -- Update for framework 6 (3.6)
# 11-25-2015 -- dscudiero -- Added highlighting for new scripts since last run (3.8)
# 12-18-2015 -- dscudiero -- use GetFrameworkVersion function to see if user has tools scripts already (3.9)
## Wed Mar 30 11:29:30 CDT 2016 - dscudiero - Fix problem with stty call
## Wed Mar 30 12:05:32 CDT 2016 - dscudiero - Switch to use SelectMenuNew
## Wed Mar 30 13:43:27 CDT 2016 - dscudiero - Use SelectMenuNew
## Thu Apr  7 16:28:20 CDT 2016 - dscudiero - Tweak window sizes
## Mon Apr 18 08:22:29 CDT 2016 - dscudiero - Tweaked report message
## Wed Apr 27 15:54:45 CDT 2016 - dscudiero - Switch to use RunSql
## Fri Apr 29 10:30:37 CDT 2016 - dscudiero - Fixed DisplayNews
## Wed May  4 14:45:23 CDT 2016 - dscudiero - Hide problem with highlighting script names
## Thu May  5 10:04:48 CDT 2016 - dscudiero - Fix problem with highlighted text in the itemName
## Wed Jun  1 13:50:15 CDT 2016 - dscudiero - Flesh out script type reports
## Wed Jun  1 14:00:54 CDT 2016 - dscudiero - tweaked the call to a report script
## Thu Jun  2 11:45:52 CDT 2016 - dscudiero - Updated auxulilliary parameter parsing
## Thu Jun  2 15:47:55 CDT 2016 - dscudiero - Tweaked the call to report scripts to pass un-parsed arguments
## Thu Jun 16 15:56:33 CDT 2016 - dscudiero - Changed colors for menuw
## Tue Jul 12 08:09:49 CDT 2016 - dscudiero - Fix reports to put out tab delimted file and make file .xls
## Wed Jul 13 11:18:22 CDT 2016 - dscudiero - Add prompt for script arguments
## Mon Jul 18 10:34:30 CDT 2016 - dscudiero - Do not prompt for args if running in batchMode
## Tue Jul 19 16:19:49 CDT 2016 - dscudiero - Pass -reportName for report scripts
## Wed Jul 20 14:20:02 CDT 2016 - dscudiero - Tweaked argument passing to report scripts
## Fri Jul 22 16:46:50 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Jul 29 06:56:30 CDT 2016 - dscudiero - Add who emails were sent to for reports
## Mon Aug  1 08:55:32 CDT 2016 - dscudiero - Add email sent to message to output file for reports
## Tue Aug 16 10:13:50 CDT 2016 - dscudiero - Refactor displaying the results of a report
## Tue Aug 16 15:17:01 CDT 2016 - dscudiero - Added an aditional prompt line for additonal args
## Wed Aug 17 16:28:41 CDT 2016 - dscudiero - Make the additional args just enter prompt info color
## Tue Aug 23 11:22:23 CDT 2016 - dscudiero - Updated to correctly parse output of selectMenuNew
## Tue Aug 23 12:31:21 CDT 2016 - dscudiero - Fix spelling error
## Mon Aug 29 07:28:05 CDT 2016 - dscudiero - wrap clear command in protectCall
## Mon Sep 19 11:09:45 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Sep 19 13:27:20 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Oct  3 15:45:03 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Oct  3 16:50:53 CDT 2016 - dscudiero - Refactor editing the users .bashrc
## Mon Oct  3 16:53:46 CDT 2016 - dscudiero - Refactor editing the users .bashrc
## Mon Oct  3 16:56:00 CDT 2016 - dscudiero - Refactor editing the users .bashrc
## Mon Oct  3 16:58:29 CDT 2016 - dscudiero - Refactor editing the users .bashrc
## Tue Oct  4 08:34:09 CDT 2016 - dscudiero - Ask the user before updating the .bashrc file
## Tue Oct  4 08:38:50 CDT 2016 - dscudiero - Tweamessaging
## Tue Oct  4 08:43:09 CDT 2016 - dscudiero - Tweak messaging
## Tue Oct  4 08:46:26 CDT 2016 - dscudiero - Tweak messaging
## Tue Oct  4 09:49:02 CDT 2016 - dscudiero - Refactor logic to find out if we should edit user .bashrc
## Tue Oct  4 09:56:50 CDT 2016 - dscudiero - tweak messaging
## Tue Oct  4 10:03:13 CDT 2016 - dscudiero - Remove debug code
## Wed Oct 12 11:47:33 CDT 2016 - dscudiero - Tweak messaging for entering arguments
## Fri Oct 14 08:25:04 CDT 2016 - dscudiero - Tweak code that adds alias to users .bashrc, also set /steamboat/leepfrog/docs/tools variable
## Fri Oct 14 11:39:22 CDT 2016 - dscudiero - Refactored script calls
## Wed Oct 19 10:25:34 CDT 2016 - dscudiero - Make sure toolspath/bin is in the path before calling the script
## Wed Oct 19 10:32:39 CDT 2016 - dscudiero - Only add TOOLSPATH to the path if it is not already there
## Tue Jan  3 16:40:07 CST 2017 - dscudiero - update comments
## Wed Jan  4 10:29:40 CST 2017 - dscudiero - Add missing functions to imports
## Wed Jan  4 11:18:14 CST 2017 - dscudiero - Removed specific debug code
## Wed Jan  4 13:05:56 CST 2017 - dscudiero - remove pause on debug statements
## Wed Jan  4 13:16:25 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan  4 13:27:02 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan  4 13:29:24 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan  4 15:43:54 CST 2017 - dscudiero - Fix problem when checking to see if the user has a scripts alias in their .bashrc file
## Fri Jan 20 13:21:12 CST 2017 - dscudiero - Add prompt for additional arguments
## Fri Jan 20 13:58:14 CST 2017 - dscudiero - fix problems passing arguments to the script
## Tue Jan 24 16:20:52 CST 2017 - dscudiero - Updated logic setting scriptArgs
## Wed Jan 25 10:36:03 CST 2017 - dscudiero - Fix spelling errors in messaging
## Thu Feb 16 08:10:58 CST 2017 - dscudiero - Switch to use the scriptID as the ordinal numbers
## Thu Feb 16 08:21:54 CST 2017 - dscudiero - Switch to use keyId inlookups
## Tue Mar 14 14:49:25 CDT 2017 - dscudiero - Fix problem where the correct logfile was not being written out
## Thu Mar 16 13:00:00 CDT 2017 - dscudiero - Tweaked messaging
## 05-05-2017 @ 13.21.31 - (3.11.72)   - dscudiero - Remove GD code
## 05-10-2017 @ 12.50.19 - (3.11.73)   - dscudiero - turn off messages for success or faliure of called script
## 05-12-2017 @ 13.45.57 - (3.11.76)   - dscudiero - Misc cleanup
## 05-17-2017 @ 10.50.32 - (3.11.82)   - dscudiero - Update prompts to accomidate the new timed prompt support
## 05-17-2017 @ 13.41.33 - (3.11.83)   - dscudiero - Do not pause if called with a scripr or report name
## 05-17-2017 @ 16.09.17 - (3.11.86)   - dscudiero - Added delimiter parsing for report headers
## 05-19-2017 @ 13.31.47 - (3.11.87)   - dscudiero - Fix problem with not pausing after report / script is run from menu
## 05-19-2017 @ 14.24.29 - (3.11.90)   - dscudiero - skip
## 05-24-2017 @ 08.09.07 - (3.11.93)   - dscudiero - Fix bug when running in batchMode and passing in a script name
## 05-25-2017 @ 09.38.47 - (3.11.95)   - dscudiero - rename the output file for reports
## 05-26-2017 @ 06.40.08 - (3.12.-1)   - dscudiero - Updated output formatting for reports
## 06-01-2017 @ 10.09.29 - (3.12.0)    - dscudiero - General syncing of dev to prod
## 06-07-2017 @ 14.57.32 - (3.12.1)    - dscudiero - Change the way we determine if scripts is not isstalled
## 06-12-2017 @ 07.35.25 - (3.12.2)    - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.28.20 - (3.12.4)    - dscudiero - Move the .bashrc check for the scrips alias before any other activities
## 06-12-2017 @ 11.29.13 - (3.12.5)    - dscudiero - Remove debug stateement
## 06-12-2017 @ 11.30.57 - (3.12.6)    - dscudiero - tweak messaging
## 09-13-2017 @ 11.30.02 - (3.12.11)   - dscudiero - Update to just pull the scripts that have showinscripts=Yes
## 09-19-2017 @ 10.39.37 - (3.12.20)   - dscudiero - Add Pause to the includes list
## 09-25-2017 @ 09.01.59 - (3.12.29)   - dscudiero - Switch to Msg3
## 10-02-2017 @ 12.47.55 - (3.12.30)   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 12.49.57 - (3.12.32)   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.17.11 - (3.12.33)   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.41.37 - (3.13.7)    - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.46.05 - (3.13.9)    - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.52.59 - (3.13.12)   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 14.07.11 - (3.13.14)   - dscudiero - Check to make sure the executeFile has a value and is readable
## 10-02-2017 @ 14.22.44 - (3.13.18)   - dscudiero - remove debug
## 10-02-2017 @ 15.32.13 - (3.13.19)   - dscudiero - General syncing of dev to prod
## 10-11-2017 @ 11.28.50 - (3.13.21)   - dscudiero - Write startup messages to log only
## 10-11-2017 @ 12.51.42 - (3.13.23)   - dscudiero - Add parents arround script call
## 10-12-2017 @ 14.30.48 - (3.13.24)   - dscudiero - Remove special code for dscudiero
## 10-12-2017 @ 14.43.31 - (3.13.25)   - dscudiero - Do not rebuild the menu list on re-display
## 10-13-2017 @ 14.39.30 - (3.13.26)   - dscudiero - swap out Call in reports
## 10-19-2017 @ 12.19.40 - (3.13.27)   - dscudiero - touch the logFile upon return to set time date stamp
## 10-19-2017 @ 15.09.39 - (3.13.28)   - dscudiero - Cleanup the logFile when done calling the script
## 10-19-2017 @ 15.12.58 - (3.13.29)   - dscudiero - Cleanup the logFile from called task
## 10-23-2017 @ 08.40.51 - (3.13.31)   - dscudiero - remove debug stuff
