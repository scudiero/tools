##  #!/bin/bash
#DO NOT AUTOVERSION
#==================================================================================================
version="2.0.24" # -- dscudiero -- Wed 06/06/2018 @ 13:54:03
#=======================================================================================================================
TrapSigs 'on'
myIncludes="SelectMenu ProtectedCall"
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
			maxreportNameLen=11
			maxScriptDescLen=18

			declare -A reportsHashShort
			fields="keyId,name,shortDescription,type,header,sqlStmt,script,scriptArgs,ignoreList"
			ifs="$IFS"; IFS=$'\r'; while read line; do
				dump 1 -n -t line
				local keyId="${line%%|*}"; line="${line#*|}"
				local name="${line%%|*}"; line="${line#*|}"
				local desc="${line%%|*}"; line="${line#*|}"
				local type="${line%%|*}"; line="${line#*|}"
				local header="${line%%|*}"; line="${line#*|}"; [[ ${header,,[a-z]} == 'null' ]] && unset header
				local sqlStmt="${line%%|*}"; line="${line#*|}"; [[ ${sqlStmt,,[a-z]} == 'null' ]] && unset sqlStmt
				local script="${line%%|*}"; line="${line#*|}"; [[ ${script,,[a-z]} == 'null' ]] && unset script
				local args="${line%%|*}"; line="${line#*|}"; [[ ${args,,[a-z]} == 'null' ]] && unset args
				local options="${line%%|*}"; line="${line#*|}"; [[ ${options,,[a-z]} == 'null' ]] && unset options
				dump 2 -t2 keyId name desc type header sqlStmt script args options

				[[ ${reportsHash["$name"]+abc} ]] && continue
				[[ ${#keyId} -gt $maxKeyIdLen ]] && maxKeyIdLen=${#keyId}
				[[ ${#name} -gt $maxreportNameLen ]] && maxreportNameLen=${#name}
				[[ ${#desc} -gt $maxScriptDescLen ]] && maxScriptDescLen=${#desc}
				reportsKeys+=($name)
				reportsHashShort["$name"]="$keyId|$name|$desc"
				reportsHash["$name"]="$keyId|$name|$desc|$type|$header|$sqlStmt|$script|$args|$options"
			done < "$TOOLSPATH/auth/reports"
			IFS="$ifs"

			menuItems=();
			menuItems+=("|");
			menuItems+=("$maxKeyIdLen|$maxreportNameLen|$maxScriptDescLen");
			menuItems+=("Ordinal|Report Name|Script Description");
			for key in "${reportsKeys[@]}"; do
				menuItems+=("${reportsHashShort[$key]}");
			done;

		return 0
	} #BuildMenuArray
	#==================================================================================================
	## Execute a script
	#==================================================================================================
	function runReport {
		local name=$1; shift
		local userArgs="$1"
		local field fieldVal tmpStr lib exec args
		local data="${reportsHash["$name"]}"
		data="${data#*|}"; data="${data#*|}";
		desc="${data%%|*}"; data="${data#*|}"; 
		type="${data%%|*}"; data="${data#*|}"; 
		header="${data%%|*}"; data="${data#*|}"; 
		sqlStmt="${data%%|*}"; data="${data#*|}"; 
		scriptName="${data%%|*}"; data="${data#*|}"; 
		scriptArgs="${data%%|*}"; data="${data#*|}"; 
		options="${data%%|*}"; data="${data#*|}"; 

		[[ -n $scriptArgs ]] && scriptArgs="$userArgs $scriptArgs" || scriptArgs="$userArgs"

		## Set report output file
		outDir="$HOME/Reports/$name"
		[[ ! -d $outDir ]] && mkdir -p "$outDir"
		outFileXls="$outDir/$(date '+%Y-%m-%d@%H.%M.%S').xls"
		outFileText="$outDir/$(date '+%Y-%m-%d@%H.%M.%S').txt"

		## Process the report record
		[[ -f $outFileText ]] && rm -f $outFileText
		if [[ $type == 'script' ]]; then
			[[ -z $scriptName ]] && scriptName="$name"
			if [[ ${options,,{a-z]} == 'standalone' ]]; then
				(FindExecutable $scriptName -report -run $scriptArgs) | tee "$outFileText"
			else
				(FindExecutable $scriptName -report -run $scriptArgs) > "$outFileText"
			fi
		else
			eval RunSql $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
				resultSet=("$(tr ',' '|' <<< "$header")" "${resultSet[@]}")
				[[ -f $tmpFile ]] && rm -f $tmpFile
				for ((i=0; i<${#resultSet[@]}; i++)); do
					echo "${resultSet[$i]}" >> "$tmpFile"
				done
			fi
		fi
		if [[ -f "$tmpFile" && $(wc -l < "$tmpFile") -gt 1 ]]; then
			if [[ ${options,,{a-z]} == 'returnsraw' ]]; then
				Msg "\n$name report run by $userName on $(date +"%m-%d-%Y") at $(date +"%H.%M.%S")" >> "$outFileXlsx"
				Msg "($shortDescription)\n" >> "$outFileXlsx"
				sed s"/|/\t/g" < "$tmpFile" >> "$outFileXlsx"
				# mapfile -t resultSet < "$tmpFile"
				# PrintColumnarData 'resultSet' '|' >> "$outFileText"
				outFile="$outFileXlsx"
			else
				outFile="$outFileText"
				cp -fp "$tmpFile" "$outFileText"
			fi
			Msg "\n^Report output can be found in: '$outFile'"
			Msg "^(On MS windows explorer, go to '\\\\\\saugus\\$userName\\Reports\\$name\\$(basename $outFile)')"
			sendMail=true
		else
			Warning "No data returned from report script"
		fi

		return 0
	} #runReport

#=======================================================================================================================
# Declare variables and constants, bring in includes file with subs
#=======================================================================================================================
tmpFile=$(mkTmpFile)
unset scriptArgs
calledViaScripts=true
menuDisplayed=false
declare -A reportsHash reportsHashShort


#=======================================================================================================================
## parse arguments
#=======================================================================================================================
helpSet='script,client'
Hello
GetDefaultsData $myName -fromFiles
ParseArgsStd $originalArgStr
scriptArgs="$unknowArgs"

reportNameIn="$client"
[[ -z $scriptNameIn && $batchMode == true ]] && Terminate "Running in batchMode and no value specified for report/script"

#==================================================================================================
## Main
#==================================================================================================
menuItems=()
loop=true
while [[ $loop == true ]]; do
	[[ ${#menuItems[@]} -eq 0 ]] && BuildMenuArray
	if [[ -z $reportNameIn ]]; then
		unset reportName
		ProtectedCall "clear"
		Msg
		Msg "\n^Please specify the $(ColorM '(ordinal)') number of the report you wish to run, 'x' to quit."
		Msg
		SelectMenu -fast -ordinalInData 'menuItems' 'reportName'
		[[ -z $reportName ]] && Goodbye 'x'
		menuDisplayed=true
	else
		## Otherwise use the passed in script/report
		reportName=$reportNameIn
		loop=false
	fi
	[[ $reportName == 'REFRESHLIST' ]] && { unset menuItems; continue; }
	reportSpec="${reportsHash["$reportName"]}"
	reportType="${reportSpec#*|}"; reportType="${reportType#*|}"; reportType="${reportType#*|}"; reportType="${reportType%%|*}";
	if [[ $reportType == 'script' ]]; then
		## Get additional arguments
		unset userArgs;
		if [[ $menuDisplayed == true ]]; then
			# unset userArgs; Prompt userArgs "^Please specify parameters to be passed to '$(ColorM $reportName)'" '*optional*' '' '3'
			[[ -n $userArgs ]] && reportArgs="$userArgs $reportArgs"
		fi
	fi

	## Call function to fulfill the request
		runReport "$reportName" "$reportArgs"; rc=$?
		[[ $menuDisplayed == true ]] && { Msg; Pause "Please press enter to go back to 'reports'"; }
done

#==================================================================================================
## Bye-bye
[[ -n $pathSave ]] && export PATH="$pathSave"
Goodbye 0
## 06-01-2018 @ 09:34:59 - 2.0.19 - dscudiero - Copy full scripts functionality and make standaole
## 06-01-2018 @ 10:10:56 - 2.0.22 - dscudiero - Fix problem because we did not add exec,lib,args to the scripts data
## 06-12-2018 @ 07:09:21 - 2.0.24 - dscudiero - Re-factored into a standalone script
