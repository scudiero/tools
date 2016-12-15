#!/bin/bash
#==================================================================================================
version=2.1.59 # -- dscudiero -- 12/14/2016 @ 11:30:40.93
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Sync git shadow"

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
	function parseArgs-syncCourseleafGitRepos {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		fork=false
		argList+=(-fork,3,switch,fork,,script,"Fork off git sync processes")
	}
	function Goodbye-syncCourseleafGitRepos {
		[[ -f $rsyncFilters ]] && rm -f $rsyncFilters
		[[ -f $myTempFile ]] && rm -f $myTempFile
	}
	function testMode-syncCourseleafGitRepos  {
		:
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
# Trap all errors, i.e. non-zero status codes from ANY command
sendMail=false
unset newReleases
## Find the helper script location
workerScript='cloneGitRepo'; useLocal=true
FindExecutable "$workerScript" 'std' 'bash:sh' ## Sets variable executeFile
workerScriptFile="$executeFile"
addedCalledScriptArgs="-secondaryMessagesOnly"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
unset addedCalledScriptArgs
[[ $verbose == true ]] && addedCalledScriptArgs="$addedCalledScriptArgs -v$verboseLevel"
[[ $batchMode == true ]] && addedCalledScriptArgs="$addedCalledScriptArgs -batchMode"
[[ $fork == true ]] && forkStr='&' || unset forkStr

Hello

#==================================================================================================
# Main
#==================================================================================================
## Loop through the repos
repos="$(echo $scriptData1 | tr ',' ' ')"
[[ $client != '' && $client != 'master' ]] && repos="$(echo $client | tr ',' ' ')"

waitCntr=1;
for repo in $repos; do
	unset tagsStr tags
	[[ $batchMode != true ]] && Msg2 "\nProcessing repo: '$repo'"
	repoDir=$gitRepoShadow/$repo
	[[ ! -d $repoDir ]] && mkdir -p $repoDir
	## Get the release from the master
		[[ $client != 'master' ]] && tagsStr="$(ProtectedCall "ls $gitRepoRoot/${repo}.git/refs/tags | grep -v .bad | grep -v _")"
		tags+=($(echo "$tagsStr"))
		tags+=('master')
		for tag in "${tags[@]}"; do
			[[ $batchMode != true ]] && Msg2 "\tChecking tag: '$tag"
			relDir=$repoDir/$tag
			if [[ -d $relDir  && $tag != 'master' ]]; then
				[[ $batchMode != true ]] && Msg2 "^^Shadow repo already exists, skipping"
			elif [[ -d $relDir-new ]]; then
				[[ $batchMode != true ]] && Msg2  "^^New shadow repo already exists, skipping"
			else
				if [[ $fork == true ]]; then
					Call "$workerScriptFile" "$repo" "$tag" "$gitRepoRoot/${repo}.git" "$relDir" "$addedCalledScriptArgs" &
				else
					Call "$workerScriptFile" "$repo" "$tag" "$gitRepoRoot/${repo}.git" "$relDir" "$addedCalledScriptArgs"
				fi
				[[ $tag != 'master' ]] && newReleases+=("$repo/$tag") && sendMail=true
			fi
		done
	if [[ $fork == true && $((waitCntr%$maxForkedProcesses)) -eq 0 ]]; then
		[[ $batchMode != true ]] && Msg2 "Waiting on forked processes..."
		wait
	fi
	(( waitCntr+=1 ))
done #repos

## Wait for forked processs to end
	[[ $batchMode != true ]] && Msg2 "Waiting on forked processes..."
	wait

## Send out emails
dump -2 -t sendMail noEmails newReleases emailAddrs
if [[ $sendMail == true && $noEmails == false && $newReleases != '' ]]; then
	Note "The following CourseLeaf components have new release:" | tee -a $tmpFile;
	for token in ${newReleases[@]}; do
		Msg2 "^$token" | tee -a $tmpFile;
	done
	Msg2
	Msg2 "Emails sent to: $(echo $emailAddrs | sed s'/,/, /'g)" | tee -a $tmpFile
	for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
		$DOIT mutt -s "$myName found new releases" -- $emailAddr < $tmpFile
	done
fi

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
