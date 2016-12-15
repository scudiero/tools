## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.6" # -- dscudiero -- 11/11/2016 @  8:44:11.92
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

