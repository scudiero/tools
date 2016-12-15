## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:30:49.57
#===================================================================================================
# Copy a file only if files are diffeent
# copyIfDifferent <srcFile> <tgtFile> <backup {true:false}>
# If backup != false then callBackpCourseleafFile
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CopyFileWithCheck {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && echo true && return 0
	local srcFile=$1
	local tgtFile=$2
	local backup=${3:false}
	local srcMd5 tgtMd5

	srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
	[[ -f $tgtFile ]] && tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ") || unset tgtMd5
	[[ $srcMd5 == $tgtMd5 ]] && echo 'same' && return 0

	[[ $backup != false && -f $tgtFile ]] && BackupCourseleafFile $tgtFile
	cp -fp $srcFile $tgtFile.new &> $tmpFile.$myName.$FUNCNAME.$$
	[[ -f $tgtFile.new ]] && tgtMd5=$(md5sum $tgtFile.new | cut -f1 -d" ") || unset tgtMd5
	[[ $srcMd5 != $tgtMd5 ]] && echo $(cat $tmpFile.$myName.$FUNCNAME.$$) && rm -rf $tmpFile.$myName.$FUNCNAME.$$ && return 0
	[[ -f $tgtFile ]] && rm $tgtFile
	mv -f $tgtFile.new $tgtFile
	echo true
	rm -rf $tmpFile.$myName.$FUNCNAME.$$
	return 0
} #CopyFileWithCheck
export -f CopyFileWithCheck

#===================================================================================================
# Check in Log
#===================================================================================================

