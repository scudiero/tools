## XO NOT AUTOVERSION
#===================================================================================================
# version="1.1.13" # -- dscudiero -- Fri 09/29/2017 @ 12:55:16.27
#===================================================================================================
# Import need functions into the runtime environment
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Import {
	local includeList="$*"
	[[ -z $includeList ]] && return 0
	local searchDirs includeName found
	local caller=${FUNCNAME[1]}; [[ $caller == 'Import' ]] && caller=${FUNCNAME[2]}

	function MyContains {
		local string="$1"
		local subStr="$2"
		[[ "${string#*$subStr}" != "$string" ]] && echo true || echo false
		return 0
	}

	[[ -z $TOOLSLIBPATH ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"

	## Search for the include file, load the first one
	[[ $verboseLevel -ge 1 ]] && echo -e "$caller/$FUNCNAME: includeList= '$includeList'"
	for includeName in $includeList; do
		[[ $(MyContains ",$SCRIPTINCLUDES," ",$includeName,") == true ]] && continue
		#[[ "${SCRIPTINCLUDES#*$includeName,}" != "$SCRIPTINCLUDES" ]] && continue  ## i.e. SCRIPTINCLUDES contains includeName
		found=false
		for searchDir in $searchDirs; do
			if [[ -r ${searchDir}/${includeName}.sh ]]; then
				[[ $verboseLevel -ge 1 ]] && echo -e "\tImporting: '$includeName' from ${searchDir}"
				source ${searchDir}/${includeName}.sh
				SCRIPTINCLUDES="$SCRIPTINCLUDES,$includeName"
				found=true
				break
			fi
		done
		[[ $found != true ]] && echo -e "\n*** Error, Import function, cannot locate '$includeName' *** \n"
	done
	[[ ${SCRIPTINCLUDES:0:1} == ',' ]] && SCRIPTINCLUDES="${SCRIPTINCLUDES:1}"
	return 0
} #Import
export -f Import

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:44 CST 2017 - dscudiero - General syncing of dev to prod
## 09-28-2017 @ 13.45.08 - ("1.1.0")   - dscudiero - Performance tweaks
## 09-29-2017 @ 12.56.43 - ("1.1.13")  - dscudiero - Fix bug checking to see if the import was already done for this name
