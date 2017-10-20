#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.7" # -- dscudiero -- Fri 10/20/2017 @  8:18:51.80
#===================================================================================================
# Set the standard output file name
# args <client> <env> <product>
#===================================================================================================
# CopyrighFt 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
#===================================================================================================
function GetOutputFile {
	local client="$1"; shift || true
	local env="$1"; shift || true
	local product="$1"; shift || true
	local extension="${1-log}"
	local outDir outFile outFileName
	outFileName=${myName}.${extension}
	[[ $client == 'all' || $client == '*' ]] && client='allClients'
	[[ $env == 'all' || $env == '*' ]] && env='allClients'
	[[ $product == 'all' || $product == '*' ]] && product='allClients'

	## Set directory
		if [[ -d $localClientWorkFolder ]]; then
			outDir="$localClientWorkFolder"
			[[ $client != '' ]] && outDir="$outDir/$client"
		elif [[ $client != '' && -d "$clientDocs/$client" ]]; then
			outDir="$clientDocs/$client"
			[[ -d $outDir/Implementation ]] && outDir="$outDir/Implementation"
			[[ -d $outDir/Attachments ]] && outDir="$outDir/Attachments"
			[[ $product != '' && -d $outDir/$(Upper $product) ]] && outDir="$outDir/$(Upper $product)"
		else
			outDir=$HOME/$myName
		fi
		[[ ! -d $outDir ]] && $DOIT mkdir -p $outDir

	# Set file name
		[[ $env != '' ]] && outFileName=$env-$outFileName
		[[ $client != '' ]] && outFileName=$client-$outFileName
		outFile=$outDir/$outFileName
		[[ -f $outFile ]] && mv -f $outFile $outFile.old

	echo "$outFile"
	return 0
} #GetOutputFile
export -f GetOutputFile

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:53:37 CST 2017 - dscudiero - General syncing of dev to prod
## 03-24-2017 @ 10.55.10 - ("2.0.6")   - dscudiero - Change the output file extension to .log
## 10-20-2017 @ 08.19.21 - ("2.0.7")   - dscudiero - Add ability to pass in the desired file extension
