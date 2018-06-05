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
	local ignoreList="${1:-none}"; shift || true; [[ $ignoreList == 'none' ]] && unset ignoreList
	local backupDir="${1:-/dev/null}"
	local token rsyncOpts source target rsyncOut rsyncFilters rsyncVerbose rc
	dump source target ignoreList backupDir | Indent | Indent >> "$logFile"

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
		rsyncOpts='-rptcmb' ## r=recursive, p=permissions, t=times, -c=checksums, m=ignoreImptyDirs, b=backup
		[[ $quiet != true ]] && rsyncOpts="${rsyncOpts}v"
		[[ $informationOnlyMode == true || -n $DOIT ]] && rsyncOpts="${rsyncOpts}n" # n=dryRun
		rsyncOpts="$rsyncOpts --backup-dir=$backupDir --include-from=$rsyncFilters --links"
		dump rsyncOpts | Indent | Indent >> "$logFile"

	## Build the filters file
		[[ -f $rsyncFilters ]] && rm -f "$rsyncFilters"
		SetFileExpansion 'off'
		for token in $(tr '|' ' ' <<< "$ignoreList"); do echo "- $token" >> $rsyncFilters; done
		echo '+ *' >> $rsyncFilters
		echo '+ .*' >> $rsyncFilters
		echo '+ *.*' >> $rsyncFilters
		SetFileExpansion
		Indent ++ 2; cat $rsyncFilters | Indent >> $logFile; Indent -- 2

	## Call rsync
		[[ ! -d $target ]] && mkdir -p "$target"
		Pushd "$target"
		SetFileExpansion 'on'
		#[[ $verboseLevel -eq 0 ]] && rsyncStdout="/dev/null" || rsyncStdout="/dev/stdout"
		#rsync $rsyncOpts $source $target >$rsyncErr | Indent | tee -a "$rsyncOut" "$logFile" > "$rsyncStdout"
		dump pwd | Indent | Indent >> "$logFile"
		rsync $rsyncOpts $source $target &> "$rsyncOut"
		rsyncRc=$?
		dump rsyncRc | Indent | Indent >> "$logFile"
		SetFileExpansion
		Popd "$target"
	    if [[ $rsyncRc -eq 0 ]]; then
	       [[ $(wc -l < $rsyncOut) -gt 4 ]] && rsyncResults="true" || rsyncResults="false"
	       	cat "$rsyncOut" | Indent | Indent >> "$logFile"
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

	    echo $rsyncResults
	return 0
} #RunRsync
export -f RsyncCopy

#===================================================================================================
# Check-in Log
#===================================================================================================
## 05-01-2018 @ 16:14:23 - 1.0.0 - dscudiero - Updated to allow rsync output to go out to the logFile
## 05-04-2018 @ 07:03:46 - 1.0.0 - dscudiero - Add a default value for ignoreList
## 06-01-2018 @ 09:34:03 - 1.0.0 - dscudiero - Add debug statements
## 06-05-2018 @ 15:23:25 - 1.0.0 - dscudiero - Tweaked rsync call amd default include statements
