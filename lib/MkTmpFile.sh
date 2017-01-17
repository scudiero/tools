## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.7" # -- dscudiero -- 01/17/2017 @  8:24:16.04
#===================================================================================================
# Get a temp file name
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function MkTmpFile {
	local functionName=${1:-$FUNCNAME}
	[[ -z $tmpRoot ]] && tmpRoot=/tmp/$LOGNAME
	[[ ! -d $tmpRoot ]] && mkdir -p $tmpRoot
	local tmpFile="$(mktemp $tmpRoot/$myName.$functionName.XXXXXXXXXX)"
	echo "$tmpFile"
	return 0
}
function mkTmpFile { MkTmpFile "$*" ; }
export -f MkTmpFile
export -f mkTmpFile

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:00 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Jan 17 08:57:48 CST 2017 - dscudiero - Make sure there is a value for tmpRoot id defaults were not loaded
