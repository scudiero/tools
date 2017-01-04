## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:39:26.43
#===================================================================================================
# find out what the courseleaf pgm is and its location
# Expects to be run from a client root directory (i.e. in .../$client)
# Returns via echo 'courseleafPgmName' 'courselafePgmDir'
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function GetCourseleafPgm {
	local checkDir=${1:-$(pwd)}
	local cwd=$(pwd)

	cd $checkDir
	for token in 'courseleaf' 'pagewiz'; do
		if [[ -x ./$token.cgi ]]; then
			echo "$token" "$checkDir"
			cd $cwd
			return 0
		elif [[ -x $checkDir/$token/$token.cgi ]]; then
			echo "$token" "$checkDir/$token"
			cd $cwd
			return 0
		elif [[ -x $(pwd)/web/$token/$token.cgi ]]; then
			echo "$token" "$checkDir/web/$token"
			cd $cwd
			return 0
		fi
	done
	cd $cwd
	return 0
} #GetCourseleafPgm
export -f  GetCourseleafPgm

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:32 CST 2017 - dscudiero - General syncing of dev to prod
