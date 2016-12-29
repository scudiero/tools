#!/bin/bash
version=1.0.25 # -- dscudiero -- 06/23/2016 @  9:35:00.61
originalArgStr="$*"
scriptDescription="Install Courseleaf Reporting tools"
TrapSigs 'on'
parentScript=$(cut -d'.' -f1 <<< $(basename ${BASH_SOURCE[0]}))

#==================================================================================================
# functions
#==================================================================================================
function parseArgs-local {
	# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
	argList+=(-force,2,switch,force,,script,'Install the feature even if it is already there, aka refresh')
	:
}
function Goodbye-local {
	:
}

#==================================================================================================
# Declare variables and constants
#==================================================================================================
scratchInstall=false
force=false

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
ParseArgsStd
Hello
Init 'getClient getEnv getDirs checkEnvs getProducts'
[[ $(Contains "$products" 'cim') == true ]] && Init 'getCims getDirs'

tgtDir=$srcDir
srcDir=$skeletonRoot/release
feature=$(echo $myName | cut -d'.' -f1)
changeLogRecs+=("Feature: $feature")

#==================================================================================================
# Main
#==================================================================================================
## Check to see if it is already there
	local editFile=$tgtDir/courseleaf.cfg
	dump -1 tgtDir srcDir editFile
	checkStr='db:reporting|sqlite|/db/reporting.sqlite'
	local grepStr="$(ProtectedCall "grep \"$checkStr\" $editFile")"
	if [[ $grepStr != '' ]]; then
		scratchInstall=true
		if [[ $force == false ]]; then
			unset ans;
			Prompt 'ans' "Feature '$feature' is already installed, Do you wish to force install" "Yes,No" 'No'; ans="$(Lower ${ans:0:1})"
			[[ $ans != 'y' ]] && Goodbye 1
		else
			Msg "N Feature '$feature' is already installed, force option active, refreshing"
		fi
	fi

## Get installation media
	cwd="$(pwd)"
	local dir tarFile
	cd "$courseleafReportsRoot"
	SetFileExpansion 'on'; reportsVersions=$(ls -d -t * 2> /dev/null | cut -d $'\n' -f1); SetFileExpansion
	[[ $reportsVersions == '' ]] && Msg "T Could not locate an directories in '$(pwd)'"
	cd ./$reportsVersions
	SetFileExpansion 'on'; tarFile=$(ls -f -t *.gz 2> /dev/null | cut -d $'\n' -f1); set -f; SetFileExpansion
	[[ $tarFile == '' ]] && Msg "T Could not locate a tar file in '$(pwd)'"
	reportsVersions=${tarFile%%'.tar.gz'}
	tarFile="$(pwd)/$tarFile"
	cd "$cwd"

## Varify OK to run
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
	verifyArgs+=("Reports version:$reportsVersions")
	[[ $products != '' ]] &&verifyArgs+=("Products:$(Upper $(echo "$products" | sed 's/,/, /g'))")
	[[ $cimStr != '' ]] && verifyArgs+=("CIMs:$cimStr")
	[[ $force == true ]] && verifyArgs+=("Force install:$force")
	VerifyContinue "You are asking to install feature: '$myName':"

## Install reports files
	Msg "Copying files..."
	cd $tgtDir/web/courseleaf/localsteps
	tar -xf $tarFile
	Msg "Copying completed"

## Add reporting db declaration
	editFile="$tgtDir/courseleaf.cfg"
	searchStr='db:reporting|sqlite|/db/reporting.sqlite'
	Msg "Checking '$editFile'"
	grepStr=$(ProtectedCall "grep \"^$searchStr\" $editFile")
	if [[ $grepStr == '' ]]; then
		Msg "\tAdding: '$searchStr' to courseleaf.cfg file"
		afterLine="$(ProtectedCall "grep '^db:' $editFile | tail -1")"
		[[ $afterLine == '' ]] && Msg "TT Could not compute location to insert line:\n\t$searchStr\n\tinto file:\n\t$editFile"
		 unset insertMsg; insertMsg=$(InsertLineInFile "$searchStr" "$editFile" "$afterLine")
		[[ $insertMsg != true ]] && Msg "TT Error inserting line into file '$editFile':\n\t$inserMsg"
		changeLogRecs+=("Added 'db:reporting|sqlite|/db/reporting.sqlite' to courseleaf.cfg")
	else
		Msg "\tFile is OK"
	fi

## Edit console file - insert reports records if not there
	rebuildConsole=false
	displayedHeading=false
	editFile="$tgtDir/web/courseleaf/index.tcf"
	Msg "Checking: '$editFile'"
	insertRec='navlinks:CAT|Catalog Report|^%progname%?page=/courseleaf/index.html&step=reports^<h4>Catalog Report</h4>Catalog Report'
	changesMade=$(EditCourseleafConsole 'insert' "$editFile" "$insertRec")
	[[ $changesMade != '' && $changesMade != true ]] && Msg "TT Could not edit file '$file':\n\t$changesMade"
	if [[ $changesMade == true ]]; then
		Msg "\tAdded 'Catalog Report' to Courseleaf console"
		changeLogRecs+=("Added 'Catalog Report' to /courseleaf/index.tcf")
		rebuildConsole=true
	else
		Msg "\t'Catalog Report' already present in Courseleaf console"
	fi

	if [[ $(Contains "$products" 'cim') == true ]]; then
		for cim in $(echo $cimStr | tr ',' ' '); do
			title="$(TitleCase ${cim%%admin})"
			insertRec="navlinks:CIM|$title Admin Report|^%progname%?page=/courseadmin/index.html&step=reports^<h4>$title Report</h4>$title Report"
			changesMade=$(EditCourseleafConsole 'insert' "$editFile" "$insertRec")
			[[ $changesMade != '' && $changesMade != true ]] && Msg "TT Could not edit file '$file':\n\t$changesMade"
			if [[ $changesMade == true ]]; then
				[[ $displayedHeading != true ]] && Msg "Checking: '$editFile'" && displayedHeading=true
				Msg "\tAdded '$title Report' to Courseleaf console"
				changeLogRecs+=("Added '$title Report' to /courseleaf/index.tcf")
				rebuildConsole=true
			else
				Msg "\t'$title Report' already present in Courseleaf console"
			fi
		done
	fi

## Bulid the reports_fields sring and edit into setup step settings in /localsteps.default.tcf

	## Retrieve current step settings from /localsteps/defalut.tcf
	editFile=$tgtDir/web/courseleaf/localsteps/default.tcf
	grepStr=$(ProtectedCall "grep \"^steps:Set Up|\" $editFile")
	if [[ $grepStr != '' ]]; then
		BackupCourseleafFile $editFile
		Msg "Checking $editFile:"
		grepStr=$(echo $grepStr | tr -d '\011\012\015')
		if [[ $(Contains "$grepStr" 'report_fields') == true ]]; then
			Msg "WT1 The 'steps:Set Up' already contains a report_fields value\n\tYou will need to manually merge your new fields into the existing data record:\n\t$editFile"
		else
			## Build reports_fields string
				local stdReportFields fieldName fieldTitle ans token
				stdReportFields+=("title:Title")
				stdReportFields+=("college:College")
				stdReportFields+=("department:Department")
				stdReportFields+=("deptwebsite:Department web site")
				stdReportFields+=("pagedesc:Page Description")
				stdReportFields+=("keywords:Keywords")
				Msg
				Msg "The standard reporting fields are:"
				for token in "${stdReportFields[@]}"; do
					fieldName=$(echo $token | cut -d':' -f'1')'               '; fieldName=${fieldName:0:12}
					fieldTitle=$(echo $token | cut -d':' -f'2')
					Msg "\t$fieldName : $fieldTitle"
				done
				Msg
				unset ans; Prompt ans "Do you wish to add additional fields?" "Yes No"; ans=$(Lower ${ans:0:1})
				if [[ $ans == 'y' ]]; then
					token=junk
					Msg "Please enter fieldName:fieldTitle pair, just press enter when done"
					until [[ $token == '' ]]; do
						unset token; Prompt token "Field" '*optional*'
						if [[ $token != '' ]]; then
							[[ $(Contains "$token" ':') != true ]] && Msg "*Error* -- Invalid value ('$token'), please try again" && continue
							fieldName=$(echo $token | cut -d':' -f'1')
							fieldTitle=$(echo $token | cut -d':' -f'2')
							stdReportFields+=("${fieldName}:${fieldTitle}")
						fi
					done
				fi
				reportFields='report_fields='
				for token in "${stdReportFields[@]}"; do
					reportFields="${reportFields}${token},"
				done
				reportFields=${reportFields:0:${#reportFields}-1}
				dump -2 reportFields

			## Retrieve current step settings from /localsteps/defalut.tcf
			editFile=$tgtDir/web/courseleaf/localsteps/default.tcf
			grepStr=$(ProtectedCall "grep \"^steps:Set Up|\" $editFile")
			if [[ $grepStr != '' ]]; then
				BackupCourseleafFile $editFile
				Msg "Checking $editFile:"
				grepStr=$(echo $grepStr | tr -d '\011\012\015')
				if [[ $(Contains "$grepStr" '|isadmin=true;') == true ]]; then
					tempStr="$(sed "s#|isadmin=true;##" <<< $grepStr)"
					toStr="${tempStr}${reportFields};|isadmin=true;"
				else
					toStr=toStr="${grepStr}${reportFields};"
				fi
				sed -i s"#^$grepStr#$toStr#"g $editFile
				Msg "\tUpdated 'steps:Set Up' record"
				changeLogRecs+=("Updated 'steps:Set Up' record in /localsteps/default.tcf")
			else
				Msg "-TT Could not locate the 'steps:Set Up' record in:\n\t$editFile"
			fi
		fi
	fi

## If we made any changes then rebuild the console page
	if [[ $rebuildConsole == true ]]; then
		Msg "Rebuilding console..."
		RunCoureleafCgi $tgtDir "-r /courseleaf/index.tcf"
	fi

## If fresh install then insall the admin table
	if [[ $scratchInstall == false ]]; then
		Msg "Initializing reports..."
		RunCoureleafCgi $tgtDir "report_init /courseleaf/index.html"
	else
		Msg "Placing reports in 'maintenance' mode..."
		sqlStmt="update admin set value=\'maintenance\' where config=\'mode\'"
		runSql "sqlite" "$siteDir/db/reporting.sqlite" $sqlStmt
	fi

## Initialize the reporting envirponments for each product installed
	local tokens
	[[ $(Contains "$products" 'cat') == true ]] && tokens='courseleaf courseeval'
	[[ $(Contains "$products" 'cim') == true ]] && tokens="$tokens $(echo $cimStr | tr ',' ' ')"
	for token in $tokens; do
		if [[ -d $tgtDir/web/$token ]]; then
			Msg "Initializing '$(TitleCase $token)' Reporting environment (Patience you must have my young padawon, this takes a while)..."
			RunCoureleafCgi $tgtDir "report_install /$token/index.html"
		fi
	done

## If fresh install then insall the admin table
	if [[ $scratchInstall == true ]]; then
		Msg "Placing reports in 'reporting' mode..."
		sqlStmt="update admin set value=\'reporting\' where config=\'mode\'"
		runSql "sqlite" "$siteDir/db/reporting.sqlite" $sqlStmt
	fi

# If changes made then log to changelog.txt
	[[ ${#changeLogRecs[@]} -gt 1 ]] && myName=$parentScript && WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Change Log
#==================================================================================================