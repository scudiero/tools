#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.5.64 # -- dscudiero -- 12/14/2016 @ 11:24:45.48
#==================================================================================================
# Install a courseleaf feature on a client site
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye RunCoureleafCgi WriteChangelogEntry SelectMenuNew'
includes="$includes EditTcfValue BackupCourseleafFile GetCourseleafPgm CopyFileWithCheck ParseCourseleafFile EditCourseleafConsole"
includes="$includes InsertLineInFile EditCourseleafConsole"
Import "$includes"
originalArgStr="$*"
scriptDescription="Install a courseleaf feature - dispatcher"

#==================================================================================================
# local functions
#==================================================================================================
function parseArgs-local {
	# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
	argList+=(-feature,2,option,feature,,script,'The feature that you want to install')
	argList+=(-force,2,switch,force,,script,'Install the feature even if it is already there, aka refresh')
	:
}
function Goodbye-local {
	:
}

function BuildFeaturesList {
	unset features
	features+=("|Feature name|Description")
	SetFileExpansion 'on'
	cwd=$(pwd)
	cd $myPath/features
	files=($(ls *.sh))
	SetFileExpansion
	for file in ${files[@]}; do
		grepStr="$(ProtectedCall "grep \"scriptDescription\" ./$file")"
		if [[ $grepStr != '' ]]; then
			name="$(cut -d'.' -f1 <<< $file)"
			if [[ $(Contains "$installedFeatures" "$name") != true ]]; then
				descript="$(cut -d'=' -f2 <<< $grepStr)"
				descript=${descript:1:${#descript}-2}
				features+=("|$name|$descript")
				featursString="$featuresString,$name"
			fi
		fi
	done
	featursString="${featursString:1}"
	cd "$cwd"
	#printf '%s\n' "${features[@]}"
}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
force=false
unset installedFeatures firstTime featuresString

## Get the list of possible features
	SetFileExpansion 'on'
	cwd=$(pwd)
	cd $myPath/features
	featuresFiles=",$(find -maxdepth 1 -mindepth 1 -type f -name '*.sh' -printf "%f," | sed s"/\.sh//g")"
	SetFileExpansion
	cd "$cwd"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
## Did the user pass in a feature name
if [[ $(Contains "$featuresFiles" ",$1,") == true ]]; then
	feature="$1"
	shift;
	originalArgStr="$*"
fi
helpSet='script'
ParseArgsStd
Hello
displayGoodbyeSummaryMessages=true
Init 'getClient getEnv getDirs checkEnvs'

#==================================================================================================
# Main
#==================================================================================================
# If feature was specified then validate, otherwise put up a select menu
	# if [[ $feature != '' ]]; then
	# 	[[ $(Lower $feature) == 'workflowemails' ]] && feature='customemails'
	# 	#[[ ! -n "$(type -t Install-$(Lower $feature))" || "$(type -t Install-$(Lower $feature))" != function ]] && unset feature
	# fi

## Do forever
while [[ true == true ]]; do
	## feature is null, put up a select menu
	if [[ $feature == '' ]]; then
		[[ $verify != true ]] && Msg "T No value specified for feature and verify is off"
		ProtectedCall "clear"
		Msg2
		BuildFeaturesList
		Msg2
		[[ $env != '' ]] && Msg2 "Please specify the feature you wish to install on '$client/$env':" || Msg2 "Please specify the feature you wish to install on '$client':"
		Msg2
		SelectMenuNew 'features' 'feature' "\nEnter the $(ColorK '(ordinal)') number of the feature you wish to install (or 'x' to quit) > "
		[[ $feature == '' ]] && Goodbye 0 || feature=$(cut -d'|' -f1 <<< $feature)
	else
		[[ $(Contains "$feature" "email") == true ]] && feature='customEmails'
		[[ $(Contains "$feature" "report") == true ]] && feature='courseleafReports'
		[[ $(Contains "$feature" "system") == true ]] && feature='refreshSystem'
		Msg2 $NT1 "Using specified value of '$feature' for feature"
	fi

	## Verify OK to run
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Target Env:$(TitleCase $env) ($siteDir)")
	VerifyContinue "You are asking to install feature: '$feature':"
	Msg2

	## Call the feature script
	[[ $env != '' ]] && sendEnv="-$env"
	## Get the executable
	Call "$feature" 'features'

	# FindExecutable "$feature" 'full' 'Bash:sh' 'features' ## Sets variable executeFile
	# ( source $executeFile ) ## Run helper in a sub shell to protect our variable values
	installedFeatures="$installedFeatures,$feature"
	unset feature
done

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

# 10-16-2015 -- dscudiero -- Update for framework 6 (1.3)
## Wed Mar 16 16:58:16 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Mar 23 17:03:54 CDT 2016 - dscudiero - Fixed call to worker script to pass all the parameters
## Thu Mar 24 10:32:10 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Mar 25 16:20:18 CDT 2016 - dscudiero - Tweaked the menu builder
## Fri Apr  1 13:30:22 CDT 2016 - dscudiero - Swithch --useLocal to $useLocal
## Wed Apr  6 16:09:13 CDT 2016 - dscudiero - switch for
## Wed Apr 13 16:28:05 CDT 2016 - dscudiero - Pass flags on to called script
## Wed Apr 27 07:20:01 CDT 2016 - dscudiero - Switch from using echo to direct input variable for parsing
## Fri Apr 29 14:07:48 CDT 2016 - dscudiero - Refactor to loop on the main menu
## Wed Jun  1 10:28:32 CDT 2016 - dscudiero - Switch Msg to Msg2
## Wed Jun  1 10:54:53 CDT 2016 - dscudiero - Edit out already installed features from the selection list
## Thu Aug  4 11:01:01 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Tue Aug 23 11:21:40 CDT 2016 - dscudiero - Updated to correctly parse output of selectMenuNew
## Thu Aug 25 09:28:30 CDT 2016 - dscudiero - Remove errant quit statement
## Tue Oct 18 13:42:26 CDT 2016 - dscudiero - use var to call feature file
