## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.71" # -- dscudiero -- Thu 08/03/2017 @  7:27:11.00
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
    local errorCode="${3-3}"
    parentModule="$(echo $(caller) | cut -d' ' -f2)"
    local errorLine="$(Trim "$(sed "$errorLineNo!d" "$parentModule")")"
    parentModule=$(basename $parentModule)
    local message

    case "$sig" in
        ERR)
            message="$FUNCNAME: Unknown error condition ($errorCode) raised in module '$parentModule'\n^Called as: $parentModule $originalArgStr,\
                     \n^$(ColorE "line($errorLineNo)"): $(ColorK "$errorLine")"
            ;;
        EXIT|SIGEXIT|SIGHUP|SIGTERM)
            unset message
            ;;
        SIGINT|SIGQUIT)
            message="$FUNCNAME: Trapped signal: '$sig' in module '$myName'\n^Script '$myName' is terminating at user's request"
            echo -e "\n$(PadChar)"
            Error "$message";
            unset message
            ;;
        *)
            message="$FUNCNAME: Trapped signal: '$sig' in module\n^'$parentModule'\n^Called as: $parentModule $originalArgStr,\
                     \n^$(ColorE "line($errorLineNo)"): $(ColorK "$errorLine")"
    esac

    if [[ -n $message && $errorCode != '255' ]]; then
        indentLevel=0
        echo -e "\n$(PadChar)"
        Error "$message";
        Msg2 "\n^Call Stack:"
        local IFSsave="$IFS" module callStack
        callStack="$(GetCallStack '|')"
        IFS='|' ; for module in $callStack; do
            Msg2 "^^$module"
        done ; IFS="$IFSsave"
        echo -e "$(PadChar)\n"
    fi
    trap - EXIT
    Goodbye $errorCode

} #Signal_handler
export -f SignalHandeler

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:30 CST 2017 - dscudiero - General syncing of dev to prod
## Mon Feb  6 09:41:06 CST 2017 - dscudiero - Tweak messaging
## 04-14-2017 @ 12.04.05 - ("2.0.56")  - dscudiero - refactor how the call path is displayed
## 04-14-2017 @ 12.18.05 - ("2.0.57")  - dscudiero - Send a bad condition code to Goodbye
## 05-10-2017 @ 09.45.48 - ("2.0.65")  - dscudiero - General syncing of dev to prod
## 05-10-2017 @ 12.49.43 - ("2.0.68")  - dscudiero - Do not display call stack for INT signels
## 06-07-2017 @ 09.57.29 - ("2.0.69")  - dscudiero - remove single quotes arround error line
## 07-31-2017 @ 07.18.03 - ("2.0.70")  - dscudiero - Add the original arg string to the outout if an error was caught
## 08-03-2017 @ 07.27.40 - ("2.0.71")  - dscudiero - reformat messages
