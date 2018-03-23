#!/bin/bash
#==================================================================================================
version=2.1.84 # -- dscudiero -- Fri 03/23/2018 @ 16:56:37.15
#==================================================================================================
TrapSigs 'on'

myIncludes="FindExecutable ProtectedCall"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="This script can be used to sync the master toolsprod shadow of the CourseLeaf git repositories"

#==================================================================================================
# Check f0r new courseleaf git git tags and download new ones
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 08-03-15 -- dgs - Initial coding
#==================================================================================================
#==================================================================================================
# local functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function syncCourseleafGitRepos-ParseArgsStd {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}
	function syncCourseleafGitRepos-Goodbye {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}
	function syncCourseleafGitRepos-testMode  {
		return 0
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
# Trap all errors, i.e. non-zero status codes from ANY command
sendMail=false
unset newReleases
## Find the helper script location
	workerScript='cloneGitRepo'
	workerScriptFile="$(FindExecutable -sh $workerScript)"
	[[ -z $workerScriptFile ]] && Terminate "Could find the workerScriptFile file ('$workerScript')"

addedCalledScriptArgs="-secondaryMessagesOnly"
tmpFile=$(MkTmpFile)

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
Hello
GetDefaultsData $myName
ParseArgsStd $originalArgStr
unset addedCalledScriptArgs
[[ $verbose == true ]] && addedCalledScriptArgs="$addedCalledScriptArgs -v$verboseLevel"
[[ $batchMode == true ]] && addedCalledScriptArgs="$addedCalledScriptArgs -batchMode"
[[ $fork == true ]] && forkStr='&' || unset forkStr

[[ $batchMode != true ]] && VerifyContinue "You are asking to sync the master toolsprod shadow of the CourseLeaf git repositories"
#==================================================================================================
# Main
#==================================================================================================
## Loop through the repos
repos="$(echo $scriptData1 | tr ',' ' ')"
[[ -n $client && $client != 'master' ]] && repos="$(echo $client | tr ',' ' ')"

waitCntr=1;
for repo in $repos; do
	unset tagsStr tags
	[[ $batchMode != true ]] && Msg "\nProcessing repo: '$repo'"
	repoDir=$gitRepoShadow/$repo
	[[ ! -d $repoDir ]] && mkdir -p $repoDir
	## Get the release from the master
		[[ $client != 'master' ]] && tagsStr="$(ProtectedCall "ls $gitRepoRoot/${repo}.git/refs/tags | grep -v .bad | grep -v _")"
		tags+=($(echo "$tagsStr"))
		tags+=('master')
		for tag in "${tags[@]}"; do
			[[ $batchMode != true ]] && Msg "^Checking tag: '$tag"
			relDir=$repoDir/$tag
			if [[ -d $relDir  && $tag != 'master' ]]; then
				[[ $batchMode != true ]] && Msg "^^Shadow repo already exists, skipping"
			elif [[ -d $relDir-new ]]; then
				[[ $batchMode != true ]] && Msg  "^^New shadow repo already exists, skipping"
			else
				if [[ $fork == true ]]; then
					source "$workerScriptFile" "$repo" "$tag" "$gitRepoRoot/${repo}.git" "$relDir" "$addedCalledScriptArgs" &
				else
					source "$workerScriptFile" "$repo" "$tag" "$gitRepoRoot/${repo}.git" "$relDir" "$addedCalledScriptArgs"
				fi
				[[ $tag != 'master' ]] && newReleases+=("$repo/$tag") && sendMail=true
			fi
		done
	if [[ $fork == true && $((waitCntr%$maxForkedProcesses)) -eq 0 ]]; then
		[[ $batchMode != true ]] && Msg "Waiting on forked processes..."
		wait
	fi
	(( waitCntr+=1 ))
done #repos

## Wait for forked processs to end
	[[ $batchMode != true ]] && Msg "Waiting on forked processes..."
	wait

## Tar up any new release shadows
	for token in ${newReleases[@]}; do
		repo="${token%%/*}"
		release="${token##*/}"
		tarFile="$repo-$release--$(date '+%m-%d-%y').tar.gz"
		srcDir="$gitRepoShadow/$repo/$release"
		[[ ! -d "$srcDir" ]] && continue
		cd "$srcDir"
		[[ -f $tarFile ]] && rm -f "$tarFile"
		[[ $repo == 'pdfgen' ]] && repo='pdf'
		tar -cpzf "$tarFile" ./$repo --exclude '*.gz' --exclude '.git*'
	done

## Send out emails
dump -2 -t sendMail noEmails newReleases emailAddrs
if [[ -n $newReleases ]]; then
	sendMail=false
	Note "The following CourseLeaf components have new release:" | tee -a $tmpFile;
	for token in ${newReleases[@]}; do
		release="${token##*/}"
		[[ $release == 'master' ]] && continue
		Msg "^$token" | tee -a "$tmpFile"
		sendMail=true
	done
fi
if [[ $sendMail == true && $noEmails == false ]]; then
	Msg
	Msg "Emails sent to: $(echo $emailAddrs | sed s'/,/, /'g)" | tee -a $tmpFile
	for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
		$DOIT mutt -s "$myName found new releases" -- $emailAddr < $tmpFile
	done
fi

[[ -f $tmpFile ]] && rm -f $tmpFile
#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 'alert'
# 12-18-2015 -- dscudiero -- Expand to other repositories (2.1.0)
## Fri Apr  1 11:14:21 CDT 2016 - dscudiero - Switch from -noFork to -forl
## Fri Apr  1 13:31:11 CDT 2016 - dscudiero - Switch --useLocal to $useLocal
## Tue Apr  5 13:48:34 CDT 2016 - dscudiero - Add in control limits for forking jobs
## Wed Apr  6 16:09:48 CDT 2016 - dscudiero - switch for
## Thu Apr  7 07:33:26 CDT 2016 - dscudiero - Pull setting of maxForkedProcess as it is now done in the framework
## Thu Jun 16 13:00:10 CDT 2016 - dscudiero - Moved Master to last
## Fri Feb 10 13:59:56 CST 2017 - dscudiero - make sure tmpFile is setup correctly
## 04-26-2017 @ 16.34.25 - (2.1.61)    - dscudiero - Build tar files for the repo directories
## 04-28-2017 @ 08.42.10 - (2.1.65)    - dscudiero - Fix problem generating tar file
## 05-01-2017 @ 08.31.45 - (2.1.67)    - dscudiero - Do not send out emails if the only repos synced are masters
## 05-01-2017 @ 08.32.16 - (2.1.68)    - dscudiero - General syncing of dev to prod
## 05-04-2017 @ 07.08.33 - (2.1.69)    - dscudiero - Fix problem when taring up the repos if the srcDir does not exist
## 05-05-2017 @ 07.15.26 - (2.1.70)    - dscudiero - Fix problem of sending emails when no named releases were created
## 05-16-2017 @ 13.13.03 - (2.1.71)    - dscudiero - Add debug statements
## 06-13-2017 @ 08.36.40 - (2.1.72)    - dscudiero - Remove debug code
## 09-29-2017 @ 10.15.14 - (2.1.76)    - dscudiero - Update FindExcecutable call for new syntax
## 10-18-2017 @ 14.18.08 - (2.1.80)    - dscudiero - Update includes list
## 10-18-2017 @ 15.35.13 - (2.1.81)    - dscudiero - Use Msg
## 11-02-2017 @ 06.59.00 - (2.1.82)    - dscudiero - Switch to ParseArgsStd
## 03-23-2018 @ 15:36:15 - 2.1.83 - dscudiero - D
## 03-23-2018 @ 16:58:13 - 2.1.84 - dscudiero - Msg3 -> Msg
