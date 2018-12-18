## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.4" # -- dscudiero -- Tue 12/18/2018 @ 15:27:44
#===================================================================================================
# Load tools defaults from the database using the C program
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
SetDefaults() {

	Import CallC MkTmpFile Msg
	local tmpFile=$(mkTmpFile)

	CallC toolsSetDefaults $* > "$tmpFile"
	echo "$tmpFile"
	cat "$tmpFile"
	echo
	source "$tmpFile"
	
	# source <(CallC toolsSetDefaults);
	ToolsDefaultsLoaded=true
	return 0;
}

export -f SetDefaults
#===================================================================================================
# Check-in Log
#===================================================================================================## 12-18-2018 @ 08:37:19 - 1.0.2 - dscudiero - Add setting of ToolsDefaultsLoaded variable
## 12-18-2018 @ 14:30:34 - 1.0.3 - dscudiero - Add debug statements
## 12-18-2018 @ 15:28:10 - 1.0.4 - dscudiero - Cosmetic/minor change/Sync
