## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.8" # -- dscudiero -- Thu 06/22/2017 @ 14:43:20.96
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

function Pushd {
	pushd "$*" >2 /dev/null
	return 0
} #Pushd
export -f Pushd

function Popd {
	popd >2 /dev/null
	return 0
} #Popd
export -f Popd

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:12 CST 2017 - dscudiero - General syncing of dev to prod
## 06-22-2017 @ 14.41.11 - ("2.0.7")   - dscudiero - Added Pushd and Popd
## 06-22-2017 @ 14.43.24 - ("2.0.8")   - dscudiero - General syncing of dev to prod
