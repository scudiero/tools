## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.3" # -- dscudiero -- Thu 07/12/2018 @ 09:42:34
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
	local backupDir="$1"
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

	[[ -n $backupDir && ! -d $backupDir ]] && $DOIT mkdir -p $backupDir

	## Set rsync options
		rsyncOpts='-rptcml' ## r=recursive, p=permissions, t=times, -c=checksums, m=ignoreImptyDirs, l=links
		[[ $quiet != true ]] && rsyncOpts="${rsyncOpts}v"
		[[ $informationOnlyMode == true || -n $DOIT ]] && rsyncOpts="${rsyncOpts}n" # n=dryRun
		[[ -n $backupDir ]] && rsyncOpts="${rsyncOpts}b --backup-dir=$backupDir"
		rsyncOpts="$rsyncOpts --include-from=$rsyncFilters"
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
## 06-05-2018 @ 16:06:13 - 1.0.0 - dscudiero - Cosmetic/minor change/Sync
## 07-12-2018 @ 08:59:00 - 1.0.1 - dscudiero - Fix problem where no backup directory was specified and we were checing to see if the backupDir existed.
## 07-12-2018 @ 09:35:52 - 1.0.2 - dscudiero - If no backupDir was specified then make sure we do not pass backup options to rsync
## 07-12-2018 @ 09:42:41 - 1.0.3 - dscudiero - Cosmetic/minor change/Sync
