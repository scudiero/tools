## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.16" # -- dscudiero -- 01/04/2017 @ 13:45:59.73
#===================================================================================================
# Import need functions into the runtime environment
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Import {
	includeList="$*"
	local searchDirs includeName found

	[[ $TOOLSLIBPATH == '' ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"

	## Search for the include file, load the first one
	for includeName in $includeList; do
		## Is the function already defined, if yes then skip
		[[ $(type -t $myName) = function ]] && continue
		found=false
		for searchDir in $searchDirs; do
			[[ -r ${searchDir}/${includeName}.sh ]] && source ${searchDir}/${includeName}.sh && found=true && break
		done
		[[ $found != true ]] && echo -e "\n*** Error, Import function, cannot locate '$includeName' *** \n" && exit
	done

	return 0
} #Import
export -f Import

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:44 CST 2017 - dscudiero - General syncing of dev to prod
