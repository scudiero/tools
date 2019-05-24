## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.12" # -- dscudiero -- Fri 05/24/2019 @ 13:57:33
#===================================================================================================
# Load tools defaults from the database using the C program
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
SetDefaults() {
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
## 05-24-2019 @ 13:10:24 - 1.0.7 - dscudiero - 
## 05-24-2019 @ 13:59:48 - 1.0.12 - dscudiero -  remove dead code
