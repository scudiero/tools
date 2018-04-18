## XO NOT AUTOVERSION
#===================================================================================================
# version="1.1.23" # -- dscudiero -- Tue 04/17/2018 @ 16:51:56.44
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

	searchDirs="$TOOLSPATH/lib"
	[[ $useDev == true && -n $TOOLSDEVPATH && -d "$TOOLSDEVPATH/lib" ]] && searchDirs="$TOOLSDEVPATH/lib $searchDirs"
	[[ $useLocal == true && -d "$HOME/tools/lib" ]] && searchDirs="$HOME/tools/lib $searchDirs"

	## Search for the include file, load the first one
	[[ $verboseLevel -ge 4 ]] && echo -e "\t$caller/$FUNCNAME: searchDirs= '$searchDirs'"
	[[ $verboseLevel -ge 4 ]] && echo -e "\t$caller/$FUNCNAME: includeList= '$includeList'"
	for includeName in $includeList; do
		[[ $verboseLevel -ge 3 ]] && echo -e "\t$caller/$FUNCNAME: includeName = '$includeName'"
		[[ $(MyContains ",$SCRIPTINCLUDES," ",$includeName,") == true ]] && continue
		#[[ "${SCRIPTINCLUDES#*$includeName,}" != "$SCRIPTINCLUDES" ]] && continue  ## i.e. SCRIPTINCLUDES contains includeName
		found=false
		for searchDir in $searchDirs; do
			[[ $verboseLevel -ge 4 ]] && echo -e "\t\t$caller/$FUNCNAME: searchDir = '$searchDir'"
			if [[ -r ${searchDir}/${includeName}.sh ]]; then
				[[ $verboseLevel -ge 4 ]] && echo -e "\tImporting: '$includeName' from ${searchDir}"
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
## 10-23-2017 @ 08.30.48 - ("1.1.14")  - dscudiero - Change verbose level for messages
## 10-27-2017 @ 12.58.57 - ("1.1.15")  - dscudiero - Add local library if USELOCAL is truen
## 10-31-2017 @ 10.37.30 - ("1.1.17")  - dscudiero - Look for Imort in local
## 03-29-2018 @ 08:38:56 - 1.1.22 - dscudiero - Change debug message levels
## 04-18-2018 @ 09:35:18 - 1.1.23 - dscudiero - Added TOOLSDEVPATH
