## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.5" # -- dscudiero -- 11/07/2016 @ 14:35:07.32
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

