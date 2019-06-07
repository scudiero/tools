## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.21" # -- dscudiero -- Tue 05/01/2018 @  8:39:36.26
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
function IsAlpha {
	local reNum='^[a-Z]+$'
	[[ $1 =~ $reNum ]] && echo true || echo false
	return 0
} #IsNumeric
export -f IsAlpha

#===================================================================================================
function Indent {
	local line i tabStr
	local count=${2:-1}
	## Special rquest to inclrease/decrease the indentLevel
		if [[ $1 = '++' || $1 = '--' ]]; then
			for ((i=0; i<$count; i++)); do
				[[ $1 = '++' ]] && ((indentLevel++))||true
				[[ $1 = '--' && $indentLevel -gt 0 ]] && ((indentLevel--))||true
			done
			return 0
		fi

	[[ -z $indentLevel ]] && local indentLevel=1
	for ((i=0; i<$indentLevel; i++)); do
		tabStr="$tabStr\t"
	done

	while read line ; do
		#printf "$tabStr%s\n" "$line"
		echo -e  "${tabStr}${line}"
	done
	return
} #Indent
export -f Indent
function Indent++ { Indent '++'; return 0; }
export -f Indent++
function Indent-- { Indent '--'; return 0; }
export -f Indent--

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
# Compare two segmented version strings, takes into account 'rc' releases
# i.e 1111.2222.3333
# Called as
# 	version1 operator version2
# Where operator in {gt, ge, lt, le, eq}
# returns true or false via echo command
#===================================================================================================
function CompareVersions {

	local version1Orig="$1"; shift || true
	local compareOp="$1"; shift || true
	local version2Orig="$1"
	#dump version1Orig compareOp version2Orig

	## Quick compare if 'equals' is in the compare type
	if [[ $version1Orig == $version2Orig ]]; then
		[[ $compareOp == 'eq' ]] && { echo true; return 0; }
		[[ ${compareOp:1:1} == 'e' ]] && { echo true; return 0; }
	else
		[[ $compareOp == 'eq' ]] && { echo false; return 0; }
	fi

	local version1rc=$(Contains "$version1Orig" "rc")
	local version2rc=$(Contains "$version2Orig" "rc")
	#dump version1rc version2rc

	local version1=${version1Orig//[a-zA-Z ]/}
	local version2=${version2Orig//[a-zA-Z ]/}

	#dump version1 version2

	local token1=$(cut -d'.' -f1 <<< $version1); token1=${token1}00; token1=${token1:0:3}
	local token2=$(cut -d'.' -f2 <<< $version1); token2=${token2}00; token2=${token2:0:3}
	local token3=$(cut -d'.' -f3 <<< $version1)
	version1="${token1}${token2}${token3}"

	token1=$(cut -d'.' -f1 <<< $version2); token1=${token1}00; token1=${token1:0:3}
	token2=$(cut -d'.' -f2 <<< $version2); token2=${token2}00; token2=${token2:0:3}
	token3=$(cut -d'.' -f3 <<< $version2)
	version2="${token1}${token2}${token3}"
	#dump version1 version2

	#dump version1 compareOp version2
	local result
	case "$compareOp" in
		'ge' | 'gt')
			[[ $version1 -gt $version2 ]] && { echo true; return 0; }
			[[ $version1 -lt $version2 ]] && { echo false; return 0; }
			[[ $version1rc == true && $version2rc == false ]] && { echo false; return 0; }
			echo true; return 0;
			;;
		'le' | 'lt')
			[[ $version1 -lt $version2 ]] && { echo true; return 0; }
			[[ $version1 -gt $version2 ]] && { echo false; return 0; }
			[[ $version1rc == true && $version2rc == false ]] && { echo true; return 0; }
			echo false; return 0;
			;;
	esac

	return 0
}

#=======================================================================================================================
# Print out structured data in a nicely formatted columnar fashion
# Usage: PrintColumnarData <arrayName> [<delimiter>]
#	- If delimiter is not specified it defaults to '|'
#	- The first row of data (arrayName[0]) is taken to be the header record
#=======================================================================================================================
function PrintColumnarData() {
	local dataArrayName=$1[@]
	local dataArray=("${!dataArrayName}"); shift
	local delim="${1-'|'}"

	local header=${dataArray[0]}
	local numCols=$(grep -o "$delim" <<< "$header" | wc -l) ; ((numCols+=1))

	## Loop through data finding the max data widths for each column
		local i j local tmpStr
		for ((i=1; i<=$numCols; i++)); do
			local col${i}Width
			maxWidth=0
			for ((j=0; j<${#dataArray[@]}; j++)); do
				tmpStr=$(cut -d "$delim" -f $i <<< "${dataArray[$j]}" )
				#dump -s -t j tmpStr
				[[ ${#tmpStr} -gt $maxWidth ]] && maxWidth=${#tmpStr}
			done
			eval "col${i}Width=$maxWidth"
			#eval "width=\$col${i}Width"
			#echo "Max width for column $i = $width"
		done

	## Loop through the data printing the data
		local outString data len
		for ((j=0; j<${#dataArray[@]}; j++)); do
			[[ $j -eq 0 ]] && data="$(tr "$delim" ' ' <<< ${dataArray[$j]})" || data="${dataArray[$j]}"
			unset outString
			for ((i=1; i<=$numCols; i++)); do
				eval "width=\$col${i}Width"
				tmpStr=$(cut -d "$delim" -f $i <<< "${dataArray[$j]}" )
				outString="${outString} "$(printf "%-${width}s" "$tmpStr")" |"
			done
			len=${#outString}; ((len-=1))
			echo "$(Trim "${outString:0:$len}")"
			[[ $j -eq 0 ]] && echo "$(PadChar "=" $len)"
		done
	return 0
} ##PrintColumnarData

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan 11 11:03:37 CST 2017 - dscudiero - Moved IsNumeric into file
## Wed Jan 11 11:15:52 CST 2017 - dscudiero - Moved Conains into this file
## Thu Jan 19 09:57:30 CST 2017 - dscudiero - Swithch to use printf since echo was absorbing leading -n and -e
## Tue Mar 14 12:18:34 CDT 2017 - dscudiero - Added CompareVersions function
## Thu Mar 23 08:24:48 CDT 2017 - dscudiero - Remove the return code from Indent
## 05-17-2017 @ 16.08.15 - ("1.0.9")   - dscudiero - Added IsAlpha function
## 05-25-2017 @ 09.36.32 - ("1.0.10")  - dscudiero - Added PrintColumnarData function
## 05-25-2017 @ 09.52.37 - ("1.0.11")  - dscudiero - remove extranious < from PrintCoumnarData
## 12-20-2017 @ 15.04.35 - ("1.0.12")  - dscudiero - Added ++ and -- options to the Indent function to increment/decrement the indentLevel
## 12-20-2017 @ 15.09.53 - ("1.0.13")  - dscudiero - Added Indent++ and Indent-- functions
## 03-30-2018 @ 12:27:32 - 1.0.14 - dscudiero - Update CompareVersions to take into account rc releases
## 03-30-2018 @ 13:45:26 - 1.0.15 - dscudiero - Fix issue with lt
## 03-30-2018 @ 13:50:18 - 1.0.16 - dscudiero - Remove debug statements
## 04-02-2018 @ 16:25:08 - 1.0.18 - dscudiero - Use Msg for indent outout
## 04-03-2018 @ 10:36:11 - 1.0.20 - dscudiero - Use echo command in Indent
## 05-01-2018 @ 08:42:42 - 1.0.21 - dscudiero - Add a count parameter to Indent ++ and -
## 06-07-2019 @ 09:06:23 - 1.0.21 - dscudiero - 
## 06-07-2019 @ 09:46:15 - 1.0.21 - dscudiero - 
