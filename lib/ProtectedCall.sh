## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.7" # -- dscudiero -- 01/04/2017 @ 13:45:29.10
#===================================================================================================
# Run a command and ignore non zero exit code trapping
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ProtectedCall {
	#GD echo "In $FUNCNAME \$\* = >"$*'<'
	previousTrapERR=$(trap -p ERR | cut -d ' ' -f3-)
	trap - ERR
	[[ $verbose == true && $verboseLevel -gt 1 ]] && printf "\n$FUNCNAME - $(date)\n" >> $stdout && printf "\tcwd: $(pwd)\n" >> $stdout && printf "\t$*\n\n" >> $stdout
	SetFileExpansion 'on'
	rc=0
	eval "$*"
	rc=$?
	SetFileExpansion
	[[ $previousTrapERR != '' ]] && eval "trap $previousTrapERR"
	return 0
} #ProtectedCall
export -f ProtectedCall

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:11 CST 2017 - dscudiero - General syncing of dev to prod
