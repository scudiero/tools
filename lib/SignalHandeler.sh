## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.40" # -- dscudiero -- 01/04/2017 @ 13:49:14.72
#===================================================================================================
# Process interrupts
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function SignalHandeler {
    VerboseMsg 3 "*** Starting: $FUNCNAME ***"
	local sig="$(Upper $1)"
    local errorLineNo="$2"
    local errorCode="$3"
    parentModule="$(echo $(caller) | cut -d' ' -f2)"
    local errorLine="$(Trim "$(sed "$errorLineNo!d" "$parentModule")")"
    #dump -p sig errorLineNo errorCode parentModule errorLine
    #printf '%s\n' "${BASH_SOURCE[@]}"
    local message

    case "$sig" in
        ERR)
            message="$FUNCNAME: Unknown error condition ($errorCode) raised in module\n^$parentModule, $(ColorE "line($errorLineNo)"):\n^$(ColorK "$errorLine")"
            ;;
        EXIT|SIGEXIT|SIGHUP|SIGTERM)
            unset message
            ;;
        SIGINT|SIGQUIT)
            message="$FUNCNAME: Trapped signal: '$sig' in module '$myName'\n^Script '$myName' is terminating at user's request"
            ;;
        *)
            message="$FUNCNAME: Trapped signal: '$sig' in module\n^'$parentModule'"
            ;;
    esac

    ## Quit

    if [[ $message != '' && $errorCode != '255' ]]; then
        echo -e "\n$(PadChar)"
        ErrorMsg "$message";
        Msg2 "^Call Stack: $(GetCallStack)"
        echo -e "$(PadChar)\n"
    fi
    trap - EXIT
    exit $?

} #Signal_handler
export -f SignalHandeler

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:30 CST 2017 - dscudiero - General syncing of dev to prod
