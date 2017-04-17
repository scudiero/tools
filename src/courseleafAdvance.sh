#!/bin/bash
# XO NOT AUTOVERSION
#===================================================================================================
version=1.1.29 # -- dscudiero -- Mon 04/17/2017 @  8:05:07.10
#===================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye WriteChangelogEntry BackupCourseleafFile'
includes="$includes GetCourseleafPgm ParseCourseleafFile RunCourseLeafCgi"
Import "$includes"
originalArgStr="$*"
scriptDescription="Advance a courseleaf site to next edition"

#= Description +===================================================================================
# Advance a courseleaf site to next edition
#==================================================================================================

#= Change Log =====================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# xx-xx-16 -- dgs - Initial coding
#==================================================================================================

#==================================================================================================
# Standard call back functions
#==================================================================================================
	function parseArgs-courseleafAdvance  { # or parseArgs-$myName
		argList+=(-edition,2,option,edition,,script,'The new edition value')
		argList+=(-refreshVersion,2,option,refreshVersion,,script,"The refresh version to apply")
		argList+=(-catalogAudit,2,switch,catalogAudit,,script,"Run the catalog audit report as part of the process")
		return 0
	}
	function Goodbye-courseleafAdvance  { # or Goodbye-$myName
		eval $errSigOn
		#if [[ -f $stepFile ]]; then echo rm stepFile; rm -f $stepFile; fi
		#if [[ -f $backupStepFile ]]; then mv -f $backupStepFile $stepFile; fi
		return 0
	}
	function testMode-courseleafAdvance  { # or testMode-$myName
		[[ $userName != 'dscudiero' ]] && Msg2 "T You do not have sufficient permissions to run this script in 'testMode'"
		client='N/A'
		noCheck=true
		env='dev'
		siteDir=$HOME/testData/dev
		tgtDir=$HOME/testData/dev
		return 0
	}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
trueVars=''
falseVars='catalogAudit'
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
scriptHelpDesc="This script can be used to advance a Courseleaf site from one edition to another.  \nThe following actions will be performed: \n\
\n\t 1) The site's edition variable will be set based on user input. \
\n\t 2) The site will have the log and archive files/directories cleand out.
\n\t 2) All '.git' files/directories will be removed. \
\n\t 4) The couseleaf directories will be refreshed from either the master version or the most recent named courseleaf release. \
\n\nEdited/changed files will be backed up to the /attic and actions will be logged in the /changelog.txt file."

GetDefaultsData $myName
ParseArgsStd
displayGoodbyeSummaryMessages=true
Hello
if [[ $noCheck == true ]]; then
	Init 'getClient'
	GetSiteDirNoCheck $client $env
	[[ -n $siteDir ]] && tgtDir="$siteDir" || Terminate "Could not resolve target site directory"
else
	Init "getClient getEnv getDirs checkEnvs"
fi

cleanDirs=$scriptData1
cleanFiles=$scriptData2

GetDefaultsData 'courseleafPatch'
ignoreCatReleases="$(cut -d':' -f2 <<< $scriptData1)"
ignoreCimReleases="$(cut -d':' -f2 <<< $scriptData2)"

[[ $verify == false && $edition == '' ]] && Msg2 $T "New edition has not been set and '-noPrompt' flag was specified on the call"
if [[ $edition == '' ]]; then
	## Get the current edition from the defults.tcf file
		unset grepStr
		currentEdition=$(ProtectedCall "grep "^edition:" $siteDir/web/courseleaf/localsteps/default.tcf" | cut -d':' -f2)
		currentEdition=$(tr -d '\040\011\012\015' <<< "$currentEdition")
	## Set the new edition and prompt user
		Msg2; Msg2 "Current CAT edition is: '$currentEdition'."
		unset newEdition
		if [[ $currentEdition != '' && $currentEdition != *'migration'* ]]; then
			if [[ $(Contains "$currentEdition" '-') == true ]]; then
				fromYear=$(echo $currentEdition | cut -d'-' -f1)
				toYear=$(echo $currentEdition | cut -d'-' -f2)
				[[ $(IsNumeric $fromYear) == true  && $(IsNumeric $toYear) == true ]] && (( fromYear++ )) && (( toYear++ )) && newEdition="$fromYear-$toYear"
			elif [[ $(Contains "$currentEdition" '_') == true ]]; then
				fromYear=$(echo $currentEdition | cut -d'_' -f1)
				toYear=$(echo $currentEdition | cut -d'_' -f2)
				[[ $(IsNumeric $fromYear) == true  && $(IsNumeric $toYear) == true ]] && (( fromYear++ )) && (( toYear++ )) && newEdition="$fromYear-$toYear"
			else
				[[ $(IsNumeric $currentEdition) == true ]] && newEdition=$currentEdition && (( newEdition++ ))
			fi
		else
			:
		fi
		if [[ $newEdition != '' ]]; then
			Prompt edition "Please specify the new edition value" "$newEdition,*any*" "$newEdition"
		else
			Prompt edition "Please specify the new edition value" "*any*"
		fi
fi

refreshSrcDir=$gitRepoShadow/courseleaf/master
masterDate=$(stat -c %y $refreshSrcDir | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')

## Get current release level for courseleaf, ask the user which version they want to use
	if [[ $refreshVersion != '' ]]; then
		## Check the passed in release
		isOk=true
		[[ $(Contains "$ignoreCatReleases" "$refreshVersion") == true ]] && isOk=false
		[[ ! -d "$gitRepoShadow/courseleaf/$refreshVersion" ]] && isOk=false
		if [[ $isOk == false ]]; then
			Msg2 $NT1 "The Specified refresh version ($refreshVersion) is not supported at this time, ignoring"
			unset refreshVersion
		fi
	fi

	if [[ $refreshVersion == '' ]]; then
		currentRel=$(ls -t $gitRepoShadow/courseleaf 2> /dev/null  | grep -v master | head -1)
		if [[ -z $currentRel || $(Contains "$ignoreCatReleases" "$currentRel") == true ]]; then
			unset currentRel
			refreshVersion='master'
			Msg2 $I "No valid named releases found, using '$refreshVersion'"
		else
			refreshSrcDir=$gitRepoShadow/courseleaf/$currentRel
			currDate=$(stat -c %y $refreshSrcDir/.syncDate | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')
		fi

		if [[ $verify != false && $refreshVersion == '' ]]; then
			if [[ $currentRel != '' ]]; then
				Msg2; Msg2 "Do you want to refresh/patch from the most recent named release of courseleaf $(ColorK "('$currentRel' - $currDate)") ('Yes')"
				Msg2 "Or refresh/patch from the current shadow of the skeleton $(ColorK "('master' - $masterDate)") ('No')"
				unset ans; Prompt ans "Yes = latest named courseleaf release (recommended), No = maser shadow of the skeleton" "Yes No" "Yes"; ans=$(Lower ${ans:0:1})
				[[ $ans == 'y' ]] && refreshVersion="$currentRel" || refreshVersion='master'
			else
				refreshVersion="$currentRel"
			fi
		fi
	fi

if [[ $verify != false ]]; then
	unset ans; Prompt ans "Do you wish to run the catalog audit report" "Yes No" "Yes"; ans=$(Lower ${ans:0:1})
	[[ $ans == 'y' ]] && catalogAudit=true
fi

## Verify run
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Env:$(TitleCase $env) ($siteDir)")
	verifyArgs+=("New CAT Edition:$edition")
	verifyArgs+=("Refreshing from Courseleaf release:$refreshVersion")
	verifyArgs+=("Run Catalog Audit Report:$catalogAudit")
	VerifyContinue "You are asking to advance the Courseleaf site"

## Log start
	myData="Client: '$client', Env: '$env', edition: '$edition' "
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#==================================================================================================
# Main
#==================================================================================================

## Run the catalog Audit report
if [[ $catalogAudit == true ]]; then
	Msg2 "Running the catalog audit report (usually takes a bit of time)"
	SetIndent '+1'
	Call 'catalogAudit' "-ignoreXmlFiles -secondaryMessagesOnly" 2>&1;
	SetIndent '-1'
fi

## Set the new edtion value
	Msg2; Msg2 "Setting edition variable..."
	$DOIT BackupCourseleafFile $siteDir/web/courseleaf/localsteps/default.tcf
	fromStr=$(ProtectedCall "grep "^edition:" $siteDir/web/courseleaf/localsteps/default.tcf")
	toStr="edition:$edition"
	sed -i s"_^${fromStr}_${toStr}_" $siteDir/web/courseleaf/localsteps/default.tcf
	Msg2 "^$toStr"


## Clean out old files
	Msg2 "Reseting console status (this may take a while)..."
	Msg2 "^wfstatinit..."
	RunCourseLeafCgi $siteDir "wfstatinit /index.html"
	Msg2 "^wfstatbuild..."
	RunCourseLeafCgi $siteDir "-e wfstatbuild /"

## Clean out old files
	Msg2 "Cleaning up..."
	if [[ -d $siteDir/requestlog ]]; then
		cd $siteDir/requestlog
		if [[ $(ls) != '' ]]; then
			Msg2 "^Archiving last requestlog directory..."
			set +f; $DOIT tar -cJf ../requestlog-archive/requestlog-$(date "+%Y-%m-%d").tar.bz2 * --remove-files; set -f
		fi
	fi

	if [[ -d $siteDir/requestlog-archive ]]; then
		cd $siteDir/requestlog-archive
		if [[ $(ls | grep -v 'archive') != '' ]]; then
			Msg2 "^Taring up requestlog-archive..."
			cd $siteDir/requestlog-archive
			set +f; $DOIT tar -cJf ../requestlog-archive/archive-$(date "+%Y-%m-%d").tar.bz2 *  --exclude '*archive*' --remove-files; set -f
		fi
	fi

	Msg2 "^Emptying files"
	for file in $(echo $cleanFiles | tr ',' ' '); do
		Msg2 "^\t$file"
		[[ $DOIT == '' ]] && echo > $siteDir/$file
	done
	Msg2 "^Emptying directories (this may take a while)"
	for dir in $(echo $cleanDirs | tr ',' ' '); do
		Msg2 "^\t$dir"
		if [[ -d $siteDir/$dir ]]; then
			cd $siteDir/$dir
			set +f; $DOIT rm -rf *; set -f
		fi
	done
	Msg2 "^Removing .git files/directories (relative to '$siteDir')"
	cd $siteDir
	for dirFile in $(find -maxdepth 4 -name '*.git*'); do
		Msg2 "^\t$dirFile"
		$DOIT rm -rf $dirFile
	done

## Refresh courseleaf from the repo
	Msg2; Msg2 "Refreshing courseleaf using 'courseleafPatch' ..."
	Call courseleafPatch -products 'cat' -secondaryMessagesOnly # inherits current values for client, env, refreshVersion

## Republish the site
	Msg2; Msg2 "${colorPurple}The target site needs to be republished.${colorDefault}"
	Msg2 "Please goto $client's CourseLeaf Console and use the 'Refresh System' tool/action"
	Msg2 "to republished the site."

## log updates in changelog.txt
	unset changeLogRecs
	changeLogRecs+=("Edition set to: $edition")
	changeLogRecs+=("Courseleaf refreshed to: $refreshVersion")
	WriteChangelogEntry 'changeLogRecs' "$siteDir/changelog.txt"

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 'alert' "$(ColorK "$(Upper $client)")/$(ColorK "$(Upper $env)") to $(ColorK "'$edition'") from $(ColorK "'$refreshVersion'")"

#==================================================================================================
## Check-in log
#==================================================================================================
## Fri Apr  1 13:30:12 CDT 2016 - dscudiero - Swithch --useLocal to $useLocal
## Wed Apr  6 16:09:06 CDT 2016 - dscudiero - switch for
## Thu Jun 16 15:37:17 CDT 2016 - dscudiero - Add wfstatinit and wfstatbuild
## Thu Aug  4 11:00:41 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Thu Sep  8 14:49:41 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Sep 21 11:10:27 CDT 2016 - dscudiero - Add option to run auditCatalog report
## Wed Sep 28 08:03:51 CDT 2016 - dscudiero - Changed to print republish messages locally, update release selection
## Tue Oct 18 13:47:10 CDT 2016 - dscudiero - Use to call the exernam program
## Wed Oct 19 10:35:53 CDT 2016 - dscudiero - Call courseleafPatch not courseleafReresh
## Wed Oct 19 10:42:36 CDT 2016 - dscudiero - fixed another reference to courseleafRefresh
## Thu Jan 12 10:23:48 CST 2017 - dscudiero - Add logic to get siteDir if nocheck is specified
## Fri Jan 27 10:12:24 CST 2017 - dscudiero - Update finding out what the latest release of courseleaf is to use defaults variable for directory
## Fri Jan 27 10:35:07 CST 2017 - dscudiero - Trap error messages from ls command looking for courseleaf releases
## 04-06-2017 @ 10.09.32 - (1.1.25)    - dscudiero - renamed RunCourseLeafCgi, use new name
## 04-17-2017 @ 08.18.27 - (1.1.29)    - dscudiero - fix problem if current edition number is not numeric
