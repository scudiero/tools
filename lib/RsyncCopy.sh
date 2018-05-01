## DO NOT AUTOVERSION
#===================================================================================================
# version="1.0.0" # -- dscudiero -- Thu 04/26/2018 @ 14:07:52.20
#===================================================================================================
#===================================================================================================================
# Use rsync to sychronize two directories
# Returns 	'true' <rsync output file>	if files where updated
#			'false' 					if files where not updated
# via global variable rsyncResults
#===================================================================================================================
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function RsyncCopy {
	local source="$1"; shift || true
	local target="$1"; shift || true
	local ignoreList="$1"; shift || true; [[ $ignoreList == 'none' ]] && unset ignoreList
	local backupDir="${1:-/dev/null}"
	local token rsyncOpts source target rsyncOut rsyncFilters rsyncVerbose rsyncListonly rc
	dump -3 source target ignoreList backupDir

	local tmpFile=$(mkTmpFile)
	local rsyncFilters="$(dirname $tmpFile)/$FUNCNAME.rsyncFilters"
	[[ -f $rsyncFilters ]] && rm -f "$rsyncFilters"
	local rsyncOut="$(dirname $tmpFile)/$FUNCNAME.rsyncOut"
	[[ -f $rsyncOut ]] && rm -f "$rsyncOut"
	local rsyncErr="$(dirname $tmpFile)/$FUNCNAME.rsyncErr"
	[[ -f $rsyncErr ]] && rm -f "$rsyncErr"
	[[ -f $tmpFile ]] && rm -f "$tmpFile"


	[[ ! -d $backupDir && $backupDir != '/dev/null' ]] && $DOIT mkdir -p $backupDir

	## Set rsync options
		rsyncOpts='-rptb'
		[[ $quiet != true ]] && rsyncOpts="${rsyncOpts}v"
		[[ $informationOnlyMode == true || -n $DOIT ]] && rsyncOpts="${rsyncOpts} --dry-run"
		rsyncOpts="-rptb$rsyncVerbose --backup-dir $backupDir --prune-empty-dirs --checksum $rsyncListonly --include-from $rsyncFilters --links"
		dump -3 rsyncOpts

	## Build the filters file
		echo > $rsyncFilters 
		SetFileExpansion 'off'
		for token in $(tr '|' ' ' <<< "$ignoreList"); do echo "- $token" >> $rsyncFilters; done
		echo '+ *.*' >> $rsyncFilters
		SetFileExpansion
		cat $rsyncFilters | Indent | Indent | Indent | Indent >> $logFile

	## Call rsync
		SetFileExpansion 'on'
		[[ $verboseLevel -eq 0 ]] && rsyncStdout="/dev/null" || rsyncStdout="/dev/stdout"
		rsync $rsyncOpts $source $target 2>$rsyncErr | Indent | tee -a "$rsyncOut" "$logFile" > "$rsyncStdout"
		rsyncRc=$?
		SetFileExpansion
	    if [[ $rsyncRc -eq 0 ]]; then
	       [[ $(wc -l < $rsyncOut) -gt 4 ]] && rsyncResults="true" || rsyncResults="false"
			rm -f "$rsyncOut" "$rsyncErr" "$rsyncFilters"
		else
			Msg "^Errors reported from the rsync operation:"
			Msg "^^Source: '$source'"
			Msg "^^Target: '$target'"
			Msg "^^Rsync Options: '$rsyncOpts'\n"
			(( indentLevel = indentLevel + 3 )) || true
			cat "$rsyncErr" | Indent
			(( indentLevel = indentLevel - 3 )) || true
			rm -f "$rsyncOut" "$rsyncErr" "$rsyncFilters"
			Terminate "Stopping processing"
	    fi

	return 0
} #RunRsync
export -f RsyncCopy

#===================================================================================================
# Check-in Log
#===================================================================================================
