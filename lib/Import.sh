## XO NOT AUTOVERSION
#===================================================================================================
# version="1.1.0" # -- dscudiero -- Thu 09/28/2017 @ 13:30:10.83
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

	[[ -z $TOOLSLIBPATH ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"

	## Search for the include file, load the first one
	for includeName in $includeList; do
		#[[ $(MyContains ",$SCRIPTINCLUDES," ",$includeName,") == true ]] && continue
		[[ "${SCRIPTINCLUDES#*$includeName}" != "$SCRIPTINCLUDES" ]] && continue  ## i.e. SCRIPTINCLUDES contains includeName
		found=false
		for searchDir in $searchDirs; do
			if [[ -r ${searchDir}/${includeName}.sh ]]; then
				source ${searchDir}/${includeName}.sh
				SCRIPTINCLUDES="$SCRIPTINCLUDES,$includeName"
				found=true
				break
			fi
		done
		[[ $found != true ]] && echo -e "\n*** Error, Import function, cannot locate '$includeName' *** \n"
	done
	[[ ${SCRIPTINCLUDES:0:1} == ',' ]] && SCRIPTINCLUDES="${SCRIPTINCLUDES:2}"
	return 0
} #Import
export -f Import

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:44 CST 2017 - dscudiero - General syncing of dev to prod
## 09-28-2017 @ 13.45.08 - ("1.1.0")   - dscudiero - Performance tweaks
