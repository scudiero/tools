## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.6" # -- dscudiero -- 01/04/2017 @ 13:38:35.41
#===================================================================================================
# Find the adminstration navlink in /courseleaf/index.tcf
# FindCourseleafNavlinkName <siteDir>
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function FindCourseleafNavlinkName {
	local dir=$1
	local editFile="$dir/web/courseleaf/index.tcf"
	local navlink grepStr
	[[ ! -f $editFile ]] && return 0
	for navlinkName in CourseLeaf Courseleaf Administration; do
		grepStr="$(ProtectedCall "grep \"^navlinks:$navlinkName\" $editFile | tail -1")"
		[[ $grepStr != '' ]] && echo "$navlinkName" && break
	done
	return 0
} #FindCourseleafNavlinkName
export -f FindCourseleafNavlinkName

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:24 CST 2017 - dscudiero - General syncing of dev to prod
