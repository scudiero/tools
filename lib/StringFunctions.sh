## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.3" # -- dscudiero -- 01/11/2017 @ 11:03:13.62
#===================================================================================================
# Various string manipulation functions
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Lower {
	echo $(tr '[:upper:]' '[:lower:]' <<< $*)
	return 0
} #Lower
export -f Lower

#===================================================================================================
function Upper {
	echo $(tr '[:lower:]' '[:upper:]' <<< $*)
	return 0
} #Lower
export -f Upper

#===================================================================================================
function TitleCase {
	local args="$*"
	echo $(tr '[:lower:]' '[:upper:]' <<< ${args:0:1})${args:1}
	return 0
} #Lower
export -f TitleCase

#===================================================================================================
function Trim {
 	echo "$(echo $* | sed 's/^[ \t]*//;s/[ \t]*$//')"
 	return 0
} #Trim
export -f Trim

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
export -f CleanString

#===================================================================================================
function IsValidURL {
	local url=$1
	local tmpFile=$(mkTmpFile $FUNCNAME)
	[[ $(type -t $ProtectedCall) != function ]] && Import 'ProtectedCall'
	ProtectedCall "ping -c 1 $url > $tmpFile 2>&1"
	grepStr=$(ProtectedCall "grep 'ping: unknown host' $tmpFile")
	[[ $grepStr == '' ]] && echo true || echo false
	rm $tmpFile
	return 0
} #IsValidURL
export -f IsValidURL

#===================================================================================================
function IsNumeric {
	local reNum='^[0-9]+$'
	[[ $1 =~ $reNum ]] && echo true || echo false
	return 0
} #IsNumeric
export -f IsNumeric


#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan 11 11:03:37 CST 2017 - dscudiero - Moved IsNumeric into file
