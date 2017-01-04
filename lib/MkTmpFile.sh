## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.6" # -- dscudiero -- 01/04/2017 @ 13:43:04.56
#===================================================================================================
# Get a temp file name
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function MkTmpFile {
	local functionName=${1:-$FUNCNAME}
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
