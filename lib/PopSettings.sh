## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.8" # -- dscudiero -- 01/04/2017 @ 11:33:10.17
#===================================================================================================
#
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function PopSettings {
	#vSetting=$(set -o | grep verbose | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	#xSetting=$(set -o | grep xtrace | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	set +vx

	local idx=${1:-N/A}
	local i setting settingsString attr attrVal tempArray
	[[ ${#savedSettings[@]} -eq 0 ]] && return 0

	for ((i = ${#savedSettings[@]}-1 ; i >= 0 ; i--)); do
		#echo; echo $i ${savedSettings[$i]}
		savedIdx=$(echo ${savedSettings[$i]} | cut -d' ' -f 1)
		[[ $savedIdx == $idx || $savedIdx == 'N/A' ]] && break
	done
	if [[ $i -ge 0 ]]; then
		settingsString=$(echo ${savedSettings[$i]} | cut -d' ' -f 2-)
		#dump settingsString
		IFSave="$IFS"; IFS=$'|'
		read -r -a tempArray <<< "${settingsString}"
		IFS="$IFSave"
		for setting in "${tempArray[@]}"; do
			attr=$(echo $setting | cut -d' ' -f 1)
			attrVal=$(echo $setting | cut -d' ' -f 2)
			#dump -n setting -t attr attrVal
			[[ $attrVal == 'on' ]] && set -o ${attr} || set +o ${attr}
		done
		unset savedSettings[$i]
	fi
	#[[ $vSetting == 'on' ]] && set -o verbose || set +o verbose
	#[[ $xSetting == 'on' ]] && set -o xtrace || set +o xtrace
	return 0
} #PopSettings
export -f PopSettings

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 12:25:36 CST 2017 - dscudiero - do not force tracing settings
