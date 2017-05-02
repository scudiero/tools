## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.7" # -- dscudiero -- Mon 05/01/2017 @ 13:40:47.27
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
	local tmpFile=$(MkTmpFile ${FUNCNAME}.$$)

	srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
	[[ -f $tgtFile ]] && tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ") || unset tgtMd5
	[[ $srcMd5 == $tgtMd5 ]] && echo 'same' && return 0
	[[ ! -d $(dirname "$tgtFile") ]] && mkdir -p "$(dirname "$tgtFile")"

	[[ $backup != false && -f $tgtFile ]] && BackupCourseleafFile $tgtFile
	cp -fp $srcFile $tgtFile.new &> $tmpFile
	[[ -f $tgtFile.new ]] && tgtMd5=$(md5sum $tgtFile.new | cut -f1 -d" ") || unset tgtMd5
	[[ $srcMd5 != $tgtMd5 ]] && echo $(cat $tmpFile) && rm -rf $tmpFile && return 0
	[[ -f $tgtFile ]] && rm $tgtFile
	mv -f $tgtFile.new $tgtFile
	echo true
	rm -rf $tmpFile
	return 0
} #CopyFileWithCheck
export -f CopyFileWithCheck

#===================================================================================================
# Check in Log
#===================================================================================================

## Wed Jan  4 13:53:10 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Feb  9 08:06:10 CST 2017 - dscudiero - make sure we are using our own tmpFile
## 05-02-2017 @ 07.32.49 - ("2.0.7")   - dscudiero - cleanup tmp files
