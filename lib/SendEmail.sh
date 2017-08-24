## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.0" # -- dscudiero -- Thu 08/24/2017 @ 10:04:40.42
#===================================================================================================
# Common script to send email, if we have an attachment then attach using mutt if we have it, otherwise
# include the attachment text in the body of the email
# Usage:
#	SendMail -subject <subject> -to <emailAddrs> [-from <fromStr>]  [-mt <msgText>] [-mf <msgTextFile>]
#			 -attach <attachFile>] [-content <contentType>]
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
    function SendEmail {
        [[ $sendMail == false || $sendEmail == false || $noEmails == true ]] && return
        local from subject emailAddrs msgTextFile attachFile contentType mailRc
        local tmpMailFile=$(MkTmpFile $FUNCNAME)

        ## Parse arguments
            until [[ -z "$*" ]]; do
                origArgToken="$1"; shift || true
                [[ ${origArgToken:0:1} == '-' ]] && origArgToken=${origArgToken:1}
                case ${origArgToken:0:1} in
                    s )
                        subject="$1"
                        ;;
                    f ) from="$1" ;;
                    t ) emailAddrs="$1" ;;
                    a ) attachFile="$1";;
                    c ) contentType="$1";;
                    * )
                        [[ ${origArgToken:0:2} == 'mf' ]] && msgTextFile="$1"
                        [[ ${origArgToken:0:2} == 'mt' ]] && msgText="$1"
                esac

            done
            [[ -n $from ]] && from="$myName"
            [[ -n $emailAddrs ]] && from="$LOGNAME@$(dnsdomainname)"
            [[ -n $contentType ]] && contentType="text/plain"

        [[ -n $msgText ]] && stdbuf -oL echo -e "$msgText" >> "$tmpMailFile"
        [[ -n $msgTextFile && -r $msgTextFile ]] && stdbuf -oL cat $msgTextFile >> "$tmpMailFile"
        stdbuf -oL echo >> $tmpMailFile

        ## Check to see if we have mutt
            local whichOut=$(which mutt 2> /dev/null)
            [[ -n ${whichOut%% *} ]] && haveMutt=true || haveMutt=false

        ## If we have mutt and attachments then use it, otherwise use sendmail
        if [[ -n $attachFile && $haveMutt == true ]]; then
            [[ -n $msgText ]] && stdbuf -oL echo -e "$msgText" >> "$tmpMailFile"
            [[ -n $msgTextFile && -r $msgTextFile ]] && stdbuf -oL cat $msgTextFile >> "$tmpMailFile"
            stdbuf -oL echo >> $tmpMailFile
            $DOIT mutt -s "$subject" -a "$attachFile" -- $emailAddrs < $tmpMailFile
        else
            ## Headers
                stdbuf -oL echo "From: $from" > "$tmpMailFile"
                stdbuf -oL echo "To: $(tr ' ' ',' <<< "$emailAddrs")" >> "$tmpMailFile"
                stdbuf -oL echo "Subject: $subject" >> "$tmpMailFile"
                stdbuf -oL echo "MIME-Version: 1.0" >> "$tmpMailFile"
                stdbuf -oL echo "Content-Type: $contentType" >> "$tmpMailFile"
                stdbuf -oL echo "" >> "$tmpMailFile"
            ## Body
                [[ -n $msgText ]] && stdbuf -oL echo -e "$msgText" >> "$tmpMailFile"
                [[ -n $msgTextFile && -r $msgTextFile ]] && stdbuf -oL cat $msgTextFile >> "$tmpMailFile"
                stdbuf -oL echo >> $tmpMailFile
            ## Attachmnent
                if [[ -n $attachFile ]]; then
                    stdbuf -oL echo "-----------------------------------------------------------------" >> "$tmpMailFile"
                    stdbuf -oL echo "Attached file '$attachFile':" >> "$tmpMailFile"
                    stdbuf -oL echo "" >> "$tmpMailFile"
                    stdbuf -oL cat $attachFile >> "$tmpMailFile"
                    stdbuf -oL echo "" >> "$tmpMailFile"
                fi
            ## Send
                $DOIT cat "$tmpMailFile" | sendmail -i -t ; mailRc=$?
        fi

        rm -f $tmpMailFile
    } #SendEmail
export -f SendEmail

#===================================================================================================
# Check-in Log
#===================================================================================================
## 08-24-2017 @ 10.04.54 - ("1.0.0")   - dscudiero - uncoment out mutt
