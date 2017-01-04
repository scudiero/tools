## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.4" # -- dscudiero -- 01/04/2017 @ 13:37:19.76
#===================================================================================================
# Remove special chars from a string
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CleanString {
	local inStr="$*"
	local editOut1='\000\001\002\003\004\005\006\007\008\009\010\011\012\013\014\015\016\017\018\019'
	local editOut2='\020\021\022\023\024\025\026\027\028\029\030\031\032\033\034\035\036\037\038\039'
	inStr=$(tr -d $editOut1 <<< "$inStr")
	inStr=$(tr -d $editOut2 <<< "$inStr")
 	echo "$inStr"
 	return 0
} #CleanString

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:53:02 CST 2017 - dscudiero - General syncing of dev to prod
