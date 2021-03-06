## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.4" # -- dscudiero -- Tue 04/24/2018 @  9:59:48.93
#===================================================================================================
# Various git utilities
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

#===================================================================================================
# Check to see if a git repo has uncommitted changes
# Usage: CheckGitRepoFiles <gitRepo> <'returnFileList'>
# Returns:
# 	'true' if there are uncommitted changes or if untracked files exist
#	'false' if there are no uncommitted changes or if untracked files exist
#	'Not a git repository' if the passed directory is not a git repository
# If 'returnFileList' is specified then the the lists of files will also be returned as follows
# true;<comma seperated list of new files>;<comma seperated list of changed files>
#===================================================================================================
function CheckGitRepoFiles {
	local repo="$1"
	local returnFileList=${2:-false}
	[[ $returnFileList != false ]] && returnFileList=true
	[[ ! -d "$repo/.git" ]] && echo "Not a git repository;$repo" && return 0
	Pushd "$repo"
	local returnVal=false
	Pushd "$repo"
	local hasChangeFiles=false; local hasNewFiles=false
	local changedFiles newFiles
	{ git status -s; } > "$tmpFile.$$"
		while read line; do
			[[ -z $line ]] && continue
			gitStat=${line%% *}
			gitFile=${line##* }
			if [[ $gitStat == '??' ]]; then
				hasNewFiles=true
				newFiles=$newFiles','$gitFile
			else
				hasChangeFiles=true
				changedFiles=$changedFiles','$gitFile
			fi
		done < "$tmpFile.$$"
		rm -f "$tmpFile.$$"
		[[ -n $changedFiles ]] && changedFiles=${changedFiles:1}
		[[ -n $newFiles ]] && newFiles=${newFiles:1}
	Popd
	if [[ $hasChangedFiles} == true || $hasNewFiles == true ]]; then
		returnVal=true
	[[ $returnFileList == true ]] && returnVal="$returnVal;$newFiles;$changedFiles"
	fi
	echo "$returnVal"
	return 0
} ##CheckGitRepoFiles
export -f CheckGitRepoFiles

#=======================================================================================================================
# Check to see if a file is in the local git
# Usage: CheckIfFileInGit <gitRepoFile> <fileName>
# Returns: true / false
#=======================================================================================================================
function CheckIfFileInGit {
	local gitRepo="$1"
	local file="$2"
	local found=false
	[[ ${file:0:1} == '/' ]] && file=${file:1}
	Pushd "$tgtDir"
	[[ -n $(ProtectedCall "git ls-tree --full-tree -r --name-only HEAD | grep $file") ]] && found=true
	Popd
	echo $found
	return 0
} #CheckIfFileInGit
export -f CheckIfFileInGit

#===================================================================================================
# Check-in Log
#===================================================================================================
## 08-07-2017 @ 11.13.53 - ("1.0.3")   - dscudiero - Optionaly return the list of new or changed files
## 04-24-2018 @ 11:20:57 - 1.0.4 - dscudiero - Add CheciIfFileInGit function
