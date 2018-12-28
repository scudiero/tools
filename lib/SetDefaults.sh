## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.7" # -- dscudiero -- Fri 12/28/2018 @ 08:21:00
#===================================================================================================
# Load tools defaults from the database using the C program
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
SetDefaults() {

	Import CallC MkTmpFile Msg
	
	# local tmpFile=$(mkTmpFile)
	# echo "HOSTNAME = '$HOSTNAME'"
	# CallC toolsSetDefaults $* > "$tmpFile"
	# echo "$tmpFile"
	# cat "$tmpFile"
	# echo
	# source "$tmpFile"
	
	source <(CallC toolsSetDefaults $*);
	ToolsDefaultsLoaded=true
	return 0;
}

export -f SetDefaults
#===================================================================================================
# Check-in Log
#===================================================================================================## 12-18-2018 @ 08:37:19 - 1.0.2 - dscudiero - Add setting of ToolsDefaultsLoaded variable
## 12-18-2018 @ 14:30:34 - 1.0.3 - dscudiero - Add debug statements
## 12-18-2018 @ 15:28:10 - 1.0.4 - dscudiero - Cosmetic/minor change/Sync
## 12-18-2018 @ 16:18:50 - 1.0.5 - dscudiero - Cosmetic/minor change/Sync
## 12-18-2018 @ 17:02:44 - 1.0.6 - dscudiero - Comment out debug statements
## 12-28-2018 @ 08:22:32 - 1.0.7 - dscudiero - Pass arguments to the c++ module
