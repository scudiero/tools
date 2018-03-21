## XO NOT AUTOVERSION
#===================================================================================================
function Msg { Msg3 $* ; return 0; }
function Info { Msg "I" $* ; return 0; }
function Note { Msg "N" $* ; return 0; }
function Warning { Msg "W" $* ; return 0; }
function Error { Msg "E" $* ; return 0; }
function Terminate { Msg "T" $* ; return 0; }
function Verbose { Msg "V" $* ; return 0; }
function Quick { Msg "Q" $* ; return 0; }
function Log { Msg "L" $* ; return 0; }
export -f Msg Info Note Warning Error Terminate Verbose Quick Log

#===================================================================================================
## check-in log
#===================================================================================================
## 09-25-2017 @ 08.03.42 - ("1.0.1")   - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 08.06.13 - ("1.0.2")   - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 08.09.54 - ("1.0.4")   - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 08.29.25 - ("1.0.5")   - dscudiero - Quick processing if no arguments passed, just echo and return
## 09-26-2017 @ 07.55.52 - ("1.0.6")   - dscudiero - Move the Quick directive earlier
## 09-26-2017 @ 15.35.34 - ("1.0.7")   - dscudiero - Fix bug with the quick options
## 09-29-2017 @ 06.46.13 - ("1.0.8")   - dscudiero - General syncing of dev to prod
## 10-05-2017 @ 09.06.01 - ("1.0.14")  - dscudiero - switch how we expand tabs to use bash native command
## 10-05-2017 @ 09.42.12 - ("1.0.18")  - dscudiero - General syncing of dev to prod
## 10-11-2017 @ 10.43.22 - ("1.0.19")  - dscudiero - Write message out to the logFile also
## 10-11-2017 @ 10.44.29 - ("1.0.20")  - dscudiero - Cosmetic/minor change
## 10-11-2017 @ 10.49.36 - ("1.0.21")  - dscudiero - check to make sure logFile exists and is writeable before writing
## 10-11-2017 @ 11.11.04 - ("1.0.22")  - dscudiero - Cosmetic/minor change
## 10-11-2017 @ 11.50.11 - ("1.0.23")  - dscudiero - Remove logging to logFile, getting duplicates
## 10-19-2017 @ 07.52.56 - ("1.0.24")  - dscudiero - Fix seting of message level
## 10-19-2017 @ 08.20.48 - ("1.0.31")  - dscudiero - c
## 10-19-2017 @ 09.01.09 - ("1.0.32")  - dscudiero - s
## 10-19-2017 @ 10.35.36 - ("1.0.33")  - dscudiero - Remove debug statements
## 11-09-2017 @ 14.15.05 - ("1.0.34")  - dscudiero - Added NotifyAllApprovers
