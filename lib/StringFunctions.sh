## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.7" # -- dscudiero -- 03/23/2017 @  8:14:17.65
#===================================================================================================
# Various string manipulation functions
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

#===================================================================================================
function Lower {
	printf "%s" "$(tr '[:upper:]' '[:lower:]' <<< $*)"
	return 0
} #Lower

#===================================================================================================
function Upper {
	printf "%s" "$(tr '[:lower:]' '[:upper:]' <<< $*)"
	return 0
} #Upper

#===================================================================================================
function TitleCase {
	local args="$*"
	printf "%s" "$(tr '[:lower:]' '[:upper:]' <<< ${args:0:1})${args:1}"
	return 0
} #TitleCase
export -f TitleCase

#===================================================================================================
function Trim {
 	printf "%s" "$(sed 's/^[ \t]*//;s/[ \t]*$//' <<< "$*")"
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
 	printf "%s" "$inStr"
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
function Indent {
	local line i
	[[ -z $indentLevel ]] && local indentLevel=1

	for ((i=0; i<$indentLevel; i++)); do
		local tabStr="$tabStr\t"
	done

	while read line ; do
		printf "$tabStr%s\n" "$line"
	done
	return
} #Indent
export -f Indent

#===================================================================================================
# Check if a string contains another string
# 	string substring
# returns true if found or false if not, returned via echo command
#===================================================================================================
function Contains {
	local string="$1"
	local substring="$2"
	local testStr=${string#*$substring}

	[[ "$testStr" != "$string" ]] && echo true || echo false
	return 0
} #Contains
export -f Contains

#===================================================================================================
# Compare two segmented version strings
# i.e 1111.2222.3333
# Called as
# 	version1 operator version2
# Where operator in {gt, ge, lt, le, eq}
# returns true or false via echo command
#===================================================================================================
function CompareVersions {

	local version1="$1"; shift || true
	local compareOp="$1"; shift || true
	local version2="$1"
	local token1 token2 token3

	token1=$(cut -d'.' -f1 <<< $version1); token1=${token1}00; token1=${token1:0:3}
	token2=$(cut -d'.' -f2 <<< $version1); token2=${token2}00; token2=${token2:0:3}
	token3=$(cut -d'.' -f3 <<< $version1)
	version1="${token1}${token2}${token3}"

	token1=$(cut -d'.' -f1 <<< $version2); token1=${token1}00; token1=${token1:0:3}
	token2=$(cut -d'.' -f2 <<< $version2); token2=${token2}00; token2=${token2:0:3}
	token3=$(cut -d'.' -f3 <<< $version2)
	version2="${token1}${token2}${token3}"

	#dump version1 compareOp version2
	case "$compareOp" in
		gt) [[ $version1 -gt $version2 ]] && echo true || echo false ;;
		ge) [[ $version1 -ge $version2 ]] && echo true || echo false ;;
		lt) [[ $version1 -lt $version2 ]] && echo true || echo false ;;
		le) [[ $version1 -lt $version2 ]] && echo true || echo false ;;
		*)  [[ $version1 -eq $version2 ]] && echo true || echo false ;;
	esac
	return 0
}

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan 11 11:03:37 CST 2017 - dscudiero - Moved IsNumeric into file
## Wed Jan 11 11:15:52 CST 2017 - dscudiero - Moved Conains into this file
## Thu Jan 19 09:57:30 CST 2017 - dscudiero - Swithch to use printf since echo was absorbing leading -n and -e
## Tue Mar 14 12:18:34 CDT 2017 - dscudiero - Added CompareVersions function
## Thu Mar 23 08:24:48 CDT 2017 - dscudiero - Remove the return code from Indent
