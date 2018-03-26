## XO NOT AUTOVERSION
#===================================================================================================
#version="3.0.0" # -- dscudiero -- Mon 03/26/2018 @  9:10:27.55
#===================================================================================================
# Start a remote session via ssh
# StartRemoteSession userid@domain [command]
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function StartRemoteSession {
	local host=$1
	local jar="$TOOLSPATH/jars/myPutty.jar"
	java -jar $jar -s $host
	return 0
} ## StartRemoteSession
export -f StartRemoteSession

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:32 CST 2017 - dscudiero - General syncing of dev to prod
## 09-22-2017 @ 12.14.39 - ("2.0.12")  - dscudiero - Added to includes
## 03-22-2018 @ 13:16:53 - 2.0.13 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 16:57:26 - 2.0.14 - dscudiero - Msg3 -> Msg
