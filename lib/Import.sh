## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.59" # -- dscudiero -- Thu 09/07/2017 @ 11:16:22.43
#===================================================================================================
# Import need functions into the runtime environment
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Import {
	function MyContains {
		[[ $# -lt 2 ]] && echo false && return 0
		local string="$1"
		local substring="$2"
		local testStr=${string#*$substring}

		[[ "$testStr" != "$string" ]] && echo true || echo false
		return 0
	} #MyContains

	includeList="$*"
	[[ -z $includeList ]] && return 0
	local searchDirs includeName found token

	[[ $TOOLSLIBPATH == '' ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"

	#echo -e"\nincludeList = '$includeList'"
	#echo -e"\tSCRIPTINCLUDES Initial = '$SCRIPTINCLUDES'"
	## Search for the include file, load the first one
	for includeName in $includeList; do
		#echo -e "\tincludeName = '$includeName'\t\t$SCRIPTINCLUDES"
		[[ $(MyContains ",$SCRIPTINCLUDES," ",$includeName,") == true ]] && continue
		found=false
		for searchDir in $searchDirs; do
			if [[ -r ${searchDir}/${includeName}.sh ]]; then
				unset includes imports
				source ${searchDir}/${includeName}.sh
				[[ -z $SCRIPTINCLUDES ]] && SCRIPTINCLUDES="$includeName" || SCRIPTINCLUDES="$SCRIPTINCLUDES,$includeName"
				#echo -e "\t\tSCRIPTINCLUDES = '$SCRIPTINCLUDES'"
				#echo -e "\t\${includes}\${imports}  = '${includes}${imports} '"
				if [[ -n ${includes}${imports} ]]; then
					for token in ${includes} ${imports}; do
						[[ $(MyContains ",$SCRIPTINCLUDES," ",$token,") != true ]] && SCRIPTINCLUDES="$SCRIPTINCLUDES,$token"
					done
				fi
				found=true
			fi
			[[ $found == true ]] && break ## searchDir
		done
		[[ $found != true ]] && echo -e "\n*** Error, Import function, cannot locate '$includeName' *** \n" && exit
	done
	#echo "SCRIPTINCLUDES Final = '$SCRIPTINCLUDES'";echo;echo
	return 0
} #Import
export -f Import

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:44 CST 2017 - dscudiero - General syncing of dev to prod
