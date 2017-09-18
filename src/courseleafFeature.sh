#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.5.132 # -- dscudiero -- Thu 09/14/2017 @ 12:07:25.66
#==================================================================================================
# Install a courseleaf feature on a client site
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================
TrapSigs 'on'
## Main script
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue'
includes="$includes SetFileExpansion ProtectedCall Call PushPop SelectMenuNew"
## Called scripts
includes="$includes "
Import "$includes"

originalArgStr="$*"
scriptDescription="Install a courseleaf feature - dispatcher"

#==================================================================================================
# Standard call back functions
#==================================================================================================
	function courseleafFeature-parseArgsStd {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-feature,2,option,feature,,script,'The feature that you want to install')
		argList+=(-force,2,switch,force,,script,'Install the feature even if it is already there, aka refresh')
	}

	function courseleafFeature-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function courseleafFeature-Help  {
		helpSet='script,client,env'
		[[ $1 == 'setVarsOnly' ]] && return 0

		echo -e "This script can be used to install a CourseLeaf feature into a site."
		echo -e "\nThe following features can be installed:"
		BuildFeaturesList
		Pushd $myPath/features
		for feature in "${features[@]}"; do
			[[ $feature == '|Feature name|Description' ]] && continue
			featureName="${feature%|*}"; featureName=${featureName:1}
			featureDesc="${feature##*|}"; featureDesc="${featureDesc#* }";
			echo -e "\t- ${featureDesc##*|}"
			echo -e "\t\tActions:"
			unset actions ${featureName}actions potentialChangedFiles ${featureName}potentialChangedFiles
			source "${featureName}.sh" 'setVarsOnly'
			varName=${featureName}actions;
			IFS=';' read -r -a lines <<< "${!varName}"
			for line in "${lines[@]}"; do
				echo -e "\t\t\t$line"
			done
			echo -e "\t\tTarget site data files potentially modified:"
			varName=${featureName}potentialChangedFiles;
			IFS=';' read -r -a lines <<< "${!varName}"
			for line in "${lines[@]}"; do
				echo -e "\t\t\t$line"
			done
		done
		Popd
		return 0
	}

#==================================================================================================
# local functions
#==================================================================================================
function BuildFeaturesList {
	unset features
	features+=("|Feature name|Description")
	SetFileExpansion 'on'
	Pushd $myPath/features
	cd $myPath/features
	files=($(ls *.sh))
	SetFileExpansion
	for file in ${files[@]}; do
		unset featureDesc ${file%%.*}scriptDescription ${file%%.*}potentialChangedFiles
		source "$file" 'setVarsOnly'
		featureName="${file%%.*}"
		featureDesc=${file%%.*}scriptDescription; featureDesc="${!featureDesc}"
		[[ $(Contains "$installedFeatures" "$featureName") != true ]] && features+=("|$featureName|$featureDesc")
	done
	Popd
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
		[[ $feature == '' ]] && Goodbye 0 || feature=$(cut -d' ' -f1 <<< $feature)
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
	Call "$feature" 'features'; rc=$?
	[[ $rc -eq 0 ]] && installedFeatures="$installedFeatures,$feature"
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
## Tue Mar  7 14:45:27 CST 2017 - dscudiero - Fix parse of resultes from selectMenuNew after redo
## Tue Mar 14 13:20:30 CDT 2017 - dscudiero - Check the return code from the install scripts before editing the installed features list
## 04-06-2017 @ 10.09.40 - (1.5.69)    - dscudiero - renamed RunCourseLeafCgi, use new name
