#!/bin/bash
# XO NOT AUTOVERSION
#===================================================================================================
version=3.11.27 # -- dscudiero -- 01/12/2017 @ 13:07:04.17
#===================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports Call SelectMenuNew"
Import "$imports"
originalArgStr="$*"
scriptDescription="Script dispatcher"

#===================================================================================================
# Tools scripts selection front end
#===================================================================================================
# 05-28-14 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#===================================================================================================
#===================================================================================================
# Standard call back functions
#===================================================================================================
function parseArgs-scriptsAndReports {
	# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
	argList+=(-emailAddrs,1,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
}

#===================================================================================================
# local functions
#===================================================================================================

#==================================================================================================
## Build the menu list from the database
#==================================================================================================
function BuildMenuList {

	## Eliminate things that do not work on windows if running from windows
		[[ $TERM == 'dumb' ]] && excludeWindowsStuff="and $scriptsTable.name not in (\"wizdebug\")" || unset excludeWindowsStuff

	## Get a list of scripts available to this user in the execution environment we are running in
		unset whereClauseHost; unset whereClauseUser; unset whereClauseGroups
		whereClauseActive="(active = \"Yes\" and name != \"$mode\")"
		# If reports build the auth where clauses
		if [[ $mode == 'scripts' ]]; then
			whereClauseHost="and (os=\"$osName\" and (host = \"$hostName\" or host is null))"
			whereClauseUser="and (restrictToUsers like \"%$userName%\" or restrictToUsers is null)"

			sqlStmt="select code from $authGroupsTable where members like \"%,$userName,%\" "
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -ne 0 ]]; then
				for result in "${resultSet[@]}"; do
					[[ $whereClauseGroups == '' ]] && whereClauseGroups="restrictToGroups like \"%$result%\"" || \
													  whereClauseGroups="$whereClauseGroups or restrictToGroups like \"%$result%\""
				done
				whereClauseGroups="and ($whereClauseGroups or restrictToGroups is null)"
			fi
		fi

		fields="name,shortDescription,author,supported,edate"
		unset $(echo $fields | tr ',' ' ')
		sqlStmt="select $fields from $table where $whereClauseActive $whereClauseHost $whereClauseUser $whereClauseGroups order by name"
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Sorry, you do not have access to any scripts.\n\tsqlStmt: $sqlStmt"

		unset menuList
		[[ $fullDisplay == true ]] && menuList+=('|Script Name|Description|Author|Supported') || menuList+=('|Script Name|Description')
		newItem=false
		for itemRec in "${resultSet[@]}"; do
			itemRec=$(tr "\t" "|" <<< "$itemRec")
			unset itemName itemDesc itemAuthor itemSupported itemEdate
			itemName=$(cut -d"|" -f1 <<< "$itemRec")
			itemDesc=$(cut -d"|" -f2 <<< "$itemRec")
			itemEdate=$(cut -d"|" -f5 <<< "$itemRec")
			#dump -n itemName itemEdate ${myName}LastRunEdate
			[[ $itemEdate != 'NULL' && $itemEdate -gt ${myName}LastRunEdate ]] && itemName="$(ColorN "$itemName")" && newItem=true
			if [[ $fullDisplay == true ]]; then
				itemAuthor=$(cut -d"|" -f3 <<< "$itemRec")
				itemAuthor="$(printf "%-$maxWidthAuthor"s "$itemAuthor")"
				itemSupported=$(cut -d"|" -f4 <<< "$itemRec")
				menuList+=("|$itemName|$itemDesc|$itemAuthor|$itemSupported")
			else
				menuList+=("|$itemName|$itemDesc")
			fi
		done
} #BuildMenuList

#==================================================================================================
## Execute a script
#==================================================================================================
function ExecScript {
	local name=$1; shift
	local scriptArgs="$1"
	local field fieldVal

	## Lookup detailed script info from db
		local fields="exec,lib,scriptArgs"
		local sqlStmt="select $fields from $scriptsTable where lower(name) =\"$(Lower $name)\" "
		RunSql2 $sqlStmt
		[[ ${#resultSet[0]} -eq 0 ]] && Msg2 $T "Could not lookup script name ('$name') in the $mySqlDb.$scriptsTable"
		resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString" )
		local fieldCntr=1
		for field in $(tr ',' ' ' <<< $fields); do
			eval local $field; eval unset $field
			fieldVal=$(cut -d'|' -f$fieldCntr <<< "$resultString")
			[[ $fieldVal == 'NULL' ]] && fieldVal=''
			eval $field=\"$fieldVal\"
			((fieldCntr += 1))
		done

	if [[ $scriptArgs == '<prompt>' ]]; then
		unset scriptArgs;
		if [[ $(Contains ",$noArgPromptList," ",$itemName,") != true && $batchMode != true  && $quiet != true ]]; then
			Msg2 "^Optionally, please specify any arguments that you wish to pass to '$itemName'";
			Prompt scriptArgs "^$(ColorI "If you do not know what to enter here just press [ENTER] or '-h' for more info)")" '*optional*' '' 4;
		fi
	fi
	if [[ $exec != '' ]]; then
		name=$(cut -d' ' -f1 <<< "$exec")
		scriptArgs="$(cut -d' ' -f2- <<< "$exec") $scriptArgs"
	fi
	Call "$name" 'bash:sh' "$lib" "$scriptArgs"
	return $?
} #ExecScript

#==================================================================================================
## Execute a report
#==================================================================================================
function ExecReport {
	local name=$1; shift
	local additionalArgs="$*"
	[[ $additionalArgs != '' && $client != '' ]] && additionalArgs="$client $additionalArgs"
	[[ $additionalArgs == '' && $client != '' ]] && additionalArgs="$client"
	local exec rc

	## Lookup detailed script info from db
		local fields="shortDescription,type,header,db,dbType,sqlStmt,script,scriptArgs,ignoreList"
		local sqlStmt="select $fields from $reportsTable where lower(name) =\"$(Lower $name)\" "
		RunSql2 $sqlStmt
		[[ ${#resultSet[0]} -eq 0 ]] && Msg2 $T "Could not lookup report name ('$name') in the $mySqlDb.$reportsTable"
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
				Msg2 "^Optionally, please specify any arguments that you wish to pass to '$itemName'";
				Prompt scriptArgs "^$(ColorI "If you do not know what to enter here just press [ENTER] or '-h' for more info)")" '*optional*' '' 3;
			fi
		fi

	## Run report
		## Report record defines a query
		if [[ $type == 'query' ]]; then
			outDir=/home/$userName/Reports/$name
			[[ ! -d $outDir ]] && mkdir -p $outDir
			outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').xls;
			if [[ -f $outFile ]]; then rm $outFile; fi
			if [[ $dbType == 'mysql' ]]; then
				#sqlStmt=$(sed "s/<ignoreList>/$ignoreList/g" <<< $sqlStmt)
				$trapErrexitOff; RunSql2 $sqlStmt; rc=$?; $trapErrexitOn
				[[ $rc -ne 0 ]] && Msg2 $T "Running MySql\n\tsqlStmt: '$sqlStmt'\n"

				if [[ ${#resultSet[@]} -eq 0 ]]; then
					Msg2 $W "No records returned from report query\n"
				else
					echo -e "$name report run by $userName on $(date +"%m-%d-%Y") at $(date +"%H.%M.%S")" > $outFile
					echo -e "($shortDescription)\n" >> $outFile
					echo -e "$(tr "," "\t" <<< "$header")" >> $outFile
					for result in "${resultSet[@]}"; do
						echo -e "$(tr '|' "\t" <<< "$result" )" >> $outFile
					done
					if [[ $quiet == false ]]; then Msg2; while read -r line; do echo -e "\t$line"; done < $outFile; fi
					Msg2; Msg2 $N "Report output can be found in: $outFile"
					sendMail=true
				fi
			else
				Msg2 $T "dbType type of '$dbType' not supported at this time"
			fi
		## Report record is to run a script
		elif [[ $type == 'script' ]]; then
			reportScript=$(cut -d'|' -f 7 <<< "$resultString")
			reportArgs=$(cut -d'|' -f 8 <<< "$resultString"); [[ $reportArgs == 'NULL' ]] && unset reportArgs
			reportIgnoreList=$(cut -d'|' -f 9 <<< "$resultString") ; [[ $reportIgnoreList == 'NULL' ]] && unset reportIgnoreList
			## Call script
				scriptArgs="-reportName $name -noHeaders"
				Call "$reportScript" "$originalArgStr $reportArgs $scriptArgs"
		else
			Msg2 $T "Report type of '$type' not supported at this time"
		fi
	return 0
} #ExecReport

#===================================================================================================
# Declare variables and constants, bring in includes file with subs
#===================================================================================================
fullDisplay=false
askedDisplayWidthQuestion=false

mode=$(echo $1 | tr '[:upper:]' '[:lower:]')
[[ $mode == 'reports' || $mode == 'scripts' ]] && shift && originalArgStr="$*"
[[ $mode == '' ]] && mode='scripts'
[[ $mode != 'scripts' && $mode != 'reports' ]] && Terminate "Invalid mode ($mode) specified on call"

## Check to see if the first argument is a report name
	## Is it a client name?
	sqlStmt="select count(*) from $clientInfoTable where LOWER(name)=\"$(Lower $1)\" and recordStatus=\"A\""
	RunSql2 $sqlStmt
	count=${resultSet[0]}
	## Not a client name, look for report or script name
	if [[ $count -eq 0 ]]; then
		if [[ $mode == 'scripts' ]]; then
			sqlStmt="select count(*) from $scriptsTable where LOWER(name)=\"$(Lower $1)\" and active=\"Yes\""
			RunSql2 $sqlStmt
			count=${resultSet[0]}
			[[ $count -ne 0 ]] && script=$1 && shift && originalArgStr="$*"
		elif [[ $mode == 'reports' ]]; then
			unset report
			sqlStmt="select count(*) from $reportsTable where LOWER(name)=\"$(Lower $1)\" and active=\"Yes\""
			RunSql2 $sqlStmt
			count=${resultSet[0]}
			[[ $count -ne 0 ]] && report=$1 && shift && originalArgStr="$*"
		fi
	fi

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

#===================================================================================================
## parse arguments
#===================================================================================================
helpSet='script,client'
parseQuiet=true
GetDefaultsData $myName
ParseArgsStd
Hello

[[ $newsDisplayed == true ]] && Pause "\nNews was displayed, please review and press any key to continue"
[[ $mode == 'scripts' && $client != '' ]] && Init 'getClient'
#[[ $mode == 'reports' && $client != '' ]] && report="$client"

dump -1 mode report script originalArgStr itemType itemTypeCap table
dump -1 client report emailAddrs myName ${myName}LastRunDate ${myName}LastRunEDate

#==================================================================================================
## Main
#==================================================================================================
## Check to see the user has access to the 'scripts' program, if not then add one to their .bashrc file
	if [[ $batchMode != true ]]; then
		PushSettings "$myName"
		previousTrapERR=$(trap -p ERR | cut -d ' ' -f3-) ; trap - ERR ; set +e
		grep -q 'alias scripts="$TOOLSPATH/bin/scripts"' $HOME/.bashrc ; rc=$?
		[[ $previousTrapERR != '' ]] && eval "trap $previousTrapERR"
		PopSettings "$myName"

		if [[ $rc -gt 0 ]]; then
			Msg2
			Msg2 "Do you wish to add an alias to the scripts command to your .bashrc file?"
			Msg2 "This will allow you to access the scripts command in the future by simply entering 'scripts' on the Linux command line."
			Msg2
			unset ans; Prompt ans "Yes to add, No to skip" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
			if [[ $ans == 'y' ]]; then
				echo '' >> $HOME/.bashrc
				echo "export TOOLSPATH=\"$TOOLSPATH\" ## Added by' '$myName' on $(date)" >> $HOME/.bashrc
				echo "alias scripts=\"\$TOOLSPATH/bin/scripts\" ## Added by' '$myName' on $(date)" >> $HOME/.bashrc
				Msg2; Msg2 $I "An alias for the scripts command has been added to your '$HOME/.bashrc' file."
				Msg2
			fi
		fi
	else
		[[ $report == '' && $script == '' ]] && Terminate "Running in batchMode and no value specified for report/script"
	fi

## If we do not have a report or script name then build & display the menu
	## Check to see if we have TOOLSPATH/bin in the path, if not added it
	unset pathSave
	grepStr=$(ProtectedCall "env | grep '^PATH=' 2> /dev/null")
	[[ $(Contains "$grepStr" "$TOOLSPATH/bin") != true ]] && pathSave="$PATH" && export PATH="$PATH:$TOOLSPATH/bin"
	loop=true
	while [[ $loop == true ]]; do
		if [[ $report == '' && $script == '' ]]; then
			unset itemName
			BuildMenuList
			ProtectedCall "clear"
			Msg2
			Msg2 "^Please specify the $(ColorM '(ordinal)') number of the $itemType you wish to run, 'x' to quit."
			Msg2 "^$(ColorN "Note -- ")The ordinal number of the $itemType may change from time to time."
			Msg2
			[[ $newItem == true ]] && Msg2 "^$(ColorN "Note -- ")Items in $(ColorN "green") are new or have been updated since the last time you ran '$mode'."
			#[[ $mode == 'scripts' && $client != '' ]] && clientStr=" (client: '$client')" || unset clientStr
			SelectMenuNew 'menuList' 'itemName'
			[[ $itemName == '' ]] && Goodbye 'x' || itemName=$(cut -d'|' -f1 <<< $itemName)
			Msg2
		else
			## Otherwise use the passed in script/report
			itemName="${report}${script}"
			loop=false
		fi
		[[ $itemName == 'REFRESHLIST' ]] && continue

		## call function to 'execute' the request
		$trapErrexitOff
		calledViaScripts=true
		itemName="$(echo -e $itemName | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")"
		Exec$itemTypeCap "$itemName" "$scriptArgs" ; rc=$?
		$trapErrexitOn
		Msg2
		[[ $rc -eq 0 ]] && Msg2 "Execution of '$(echo $itemName | cut -d' ' -f1)' completed succesfully" || \
			Msg2 "Execution of '$(echo $itemName | cut -d' ' -f1)' completed with errors (exit code = $rc) \
			\nPlease record any Messages and contact the $itemType owner\n"
		[[ $batchMode != true && $quiet != true && $verify == true ]] && Pause "Please press enter to go back to '${itemType}s'"
		unset calledViaScripts
	done

## Send out emails
	if [[ $emailAddrs != '' && $mode == 'reports' && $noEmails == false && $sendMail == true ]]; then
		Msg2 | tee -a $outFile; Msg2 "Sending email(s) to: $emailAddrs" | tee -a $outFile; Msg2 | tee -a $outFile
		for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
			$DOIT mutt -a "$outFile" -s "$report report results: $(date +"%m-%d-%Y")" -- $emailAddr < $outFile
		done
	fi

#==================================================================================================
## Bye-bye
[[ $pathSave != '' ]] && export PATH="$pathSave"
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
