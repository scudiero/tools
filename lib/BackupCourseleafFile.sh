## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:26:01.73
#===================================================================================================
# Backup a courseleaf file, copy to the attic createing directories as necessary
# Expects the variable 'client' to be set
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function BackupCourseleafFile {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local file=$1; shift || true
	[[ ! -r $file ]] && return 0

	local client=$(ParseCourseleafFile "$file" | cut -d ' ' -f1)
	local clientRoot=$(ParseCourseleafFile "$file" | cut -d ' ' -f3)
	local fileEnd=$(ParseCourseleafFile "$file" | cut -d ' ' -f4)
	local backupRoot="${clientRoot}/attic/$myName.$userName.$(date +"%H-%M-%S")"
	[[ ! -d $backupRoot ]] && mkdir -p $backupRoot
	local bakFile="${backupRoot}${fileEnd}"

	if [[ -f $file ]]; then
		[[ ! -d $(dirname $bakFile) ]] && mkdir -p $(dirname $bakFile)
		$DOIT cp -fp $file $bakFile
	elif [[ -d $file ]]; then
		[[ ! -d $bakFile ]] && $DOIT mkdir -p $bakFile
		$DOIT cp -rfp $file $bakFile
	fi

	return 0
} #BackupCourseleafFile
export -f BackupCourseleafFile

#===================================================================================================
# Checkin Log
#===================================================================================================

