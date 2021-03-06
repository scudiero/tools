## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.11" # -- dscudiero -- Wed 11/01/2017 @  7:51:36.31
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
		echo "$(mktemp $tmpRoot/$myName.$$.$BASHPID.XXXXXXXXXX)"
	else
		echo "$(mktemp $tmpRoot/$myName.$$.$BASHPID.$1.XXXXXXXXXX)"
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
## 05-30-2017 @ 07.14.47 - ("2.0.9")   - dscudiero - add processid to the tmp file name
## 05-31-2017 @ 12.31.22 - ("2.0.10")  - dscudiero - change the name of the tmpfile to include $$
## 05-31-2017 @ 12.31.57 - ("2.0.10")  - dscudiero - Change the namd of the tmpFile to include the current process id
## 11-01-2017 @ 07.58.03 - ("2.0.11")  - dscudiero - Cosmetic/minor change
