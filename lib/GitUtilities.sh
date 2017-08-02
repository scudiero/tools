## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.2" # -- dscudiero -- Wed 08/02/2017 @ 12:00:49.10
#===================================================================================================
# Various git utilities
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

#===================================================================================================
# Check to see if a git repo has uncommitted changes
# Usage: CheckForChangedGitFiles <gitRepo>
# Returns:
# 	'true' if there are uncommitted changes or if untracked files exist
#	'false' if there are no uncommitted changes or if untracked files exist
#	'Not a git repository' if the passed directory is not a git repository
#===================================================================================================
function CheckForChangedGitFiles {
	local repo="$1"
	[[ ! -d "$repo/.git" ]] && echo "Not a git repository" && return 0
	local nonCommittedFiles
	Pushd "$repo"
	nonCommittedFiles=$(git status -s)
	Popd
	[[ -z $nonCommittedFiles ]] && echo false || echo true
	return 0
} ##CheckForChangedGitFiles
export -f CheckForChangedGitFiles

#===================================================================================================
# Check-in Log
#===================================================================================================
