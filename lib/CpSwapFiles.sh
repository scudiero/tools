## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:31:11.65
#===================================================================================================
# Copy files protected, copy the file to a different name, check if it made it, then swap names
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CpSwapFiles {
	local callerLineNo=$1; shift || true
	local file="$1"; shift || true
	local fromDir="$1"; shift || true
	local fromFile="$fromDir/$file"
	local toDir="$1"; shift || true
	local toFile="$toDir/$file"
	local backupDir="$1"
	local foundToFile=false
	local srcMd5 tgtMd5

	dump -3 -n callerLineNo file fromDir fromFile toDir toFile backupDir
	[[ ! -r $fromFile ]] && Msg2 $TT1 "Could not find file '$fromFile'\n^^($callerLineNo)"
	srcMd5=$(md5sum $fromFile | cut -f1 -d" ")
	[[ -w $toFile ]] && foundToFile=true && tgtMd5=$(md5sum $toFile | cut -f1 -d" ")
	dump -3 foundToFile

	if [[ $foundToFile == true ]]; then
		## If files are the same just return 0
		[[ $srcMd5 == $tgtMd5 ]] && return 0
		if [[ $backupDir != '' ]]; then
			[[ ! -d $backupDir ]] && mkdir -p $backupDir
			cp -f $toFile $backupDir/$(basename $toFile)
		fi
		local tmpOrigFileName="$toFile $toFile.orig.$BASHPID"
		$DOIT mv $toFile $tmpOrigFileName
	else
		[[ ! -d $toDir ]] && mkdir -p $toDir
	fi

	local tmpNewFileName="$toFile.new.$BASHPID"
	$DOIT cp $fromFile $tmpNewFileName
	if [[ ! -f $tmpNewFileName ]]; then
		$DOIT mv $tmpOrigFileName $toFile
		Msg2 $TT1 "Could not copy file:\n^^From file:'$fromFile'\n^^To file: $toFile to find file\n^^($callerLineNo)"
	fi
	$DOIT mv $tmpNewFileName $toFile
	[[ $foundToFile == true ]] && $DOIT rm -f $tmpOrigFileName

	return 0
} #CpSwapFiles
export -f CpSwapFiles

#===================================================================================================
# Check-in Log
#===================================================================================================

