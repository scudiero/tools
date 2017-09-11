## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.11" # -- dscudiero -- Fri 09/08/2017 @ 14:10:03.60
#===================================================================================================
# Save or restore shell settings
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function PushSettings {
	local tempArray=($(set -o | tr "\t" ' ' | tr -s ' '))
	local vSetting=$(set -o | grep verbose | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	local xSetting=$(set -o | grep xtrace | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	set +vx

	local idx=${1:-N/A}
	local i settingsString attr attrVal

	for ((i = 0 ; i < ${#tempArray[@]} ; i++)); do
	 	attr=${tempArray[$i]}
	 	attrVal=${tempArray[$i+1]}
	 	#echo -e 'attr = >'$attr'<, attrVal = >'$attrVal'<'
	 	settingsString="${settingsString}|${attr} ${attrVal}"
	 	#echo -e 'settingsString = >'$settingsString'<'
	 	i=$((i + 1))
	done
	savedSettings+=("${idx} ${settingsString:1}")
	[[ $vSetting == 'on' ]] && set -o verbose || set +o verbose
	[[ $xSetting == 'on' ]] && set -o xtrace || set +o xtrace
	return 0
} #PushSettings
export -f PushSettings

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
function Pushd {
	pushd "$*" &> /dev/null
	return 0
} #Pushd
export -f Pushd

#===================================================================================================
function Popd {
	popd &> /dev/null
	return 0
} #Popd
export -f Popd

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:12 CST 2017 - dscudiero - General syncing of dev to prod
## 06-22-2017 @ 14.41.11 - ("2.0.7")   - dscudiero - Added Pushd and Popd
## 06-22-2017 @ 14.43.24 - ("2.0.8")   - dscudiero - General syncing of dev to prod
## 08-01-2017 @ 13.40.55 - ("2.0.9")   - dscudiero - Fix problem with Popd and Pushd creating '2' files
