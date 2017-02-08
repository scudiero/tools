## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.8" # -- dscudiero -- 02/07/2017 @ 17:03:37.80
#===================================================================================================
# Get a temp file name
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function MkTmpFile {
	[[ -z $tmpRoot ]] && tmpRoot=/tmp/$LOGNAME
	[[ ! -d $tmpRoot ]] && mkdir -p $tmpRoot
	if [[ -z "$1" ]]; then
		echo "$(mktemp $tmpRoot/$myName.XXXXXXXXXX)"
	else
		echo "$(mktemp $tmpRoot/$myName.$1.XXXXXXXXXX)"
	fi
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
## Wed Feb  8 10:57:38 CST 2017 - dscudiero - General syncing of dev to prod
