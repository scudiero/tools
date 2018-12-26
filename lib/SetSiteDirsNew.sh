#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.0" # -- dscudiero -- Wed 12/26/2018 @ 12:33:08
#===================================================================================================
# Set courseleaf site dirs, pulls data from the data warehouse
#===================================================================================================
SetSiteDirsNew() {
	Import CallC MkTmpFile; local tmpFile=$(mkTmpFile)
	local dirs="pvt dev test next curr prior public"
	for dir in $dirs; do unset ${dir}Dir; done
	## Call the program trapping file descriptor #3
	CallC setSiteDirs $* 3> "$tmpFile"; rc=$?;
	## OK, source the tmpFile if it has data (set return data)
	[[ $(cut -d' ' -f1 <<< $(wc -l "$tmpFile")) -gt 0 ]] && { source <(cat "$tmpFile"); }
	rm -f "$tmpFile"
	return 0;
}

export -f SetSiteDirsNew

#===================================================================================================
## Check-in log
#===================================================================================================