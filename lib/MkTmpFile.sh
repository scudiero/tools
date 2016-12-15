## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.5" # -- dscudiero -- 11/07/2016 @ 14:39:31.36
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
