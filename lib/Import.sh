## XO NOT AUTOVERSION
#===================================================================================================
version="1.0.15" # -- dscudiero -- 12/19/2016 @ 11:37:42.88
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
