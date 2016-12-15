#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:54:36.13
#===================================================================================================
# Set the standard output file name
# args <client> <env> <product>
#===================================================================================================
# CopyrighFt 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
#===================================================================================================
function GetOutputFile {
	local client="$1"
	local env="$2"
	local product="$3"
	local outDir outFile outFileName
	outFileName=$myName.out
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
