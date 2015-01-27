#!/bin/bash
#
# Installing black_hole
#
# xor-function
# BSD 3
#

tstamp() {
  date +"%F"_"%H":"%M"
 }

# func requires arguments (username)
chk_usr() {
   if [ "$(whoami)" != "$1" ]; then
       printf "\nyou need to be root\nexiting....\n\n"
       exit
   fi
}

chk_tubes() {
  printf "\nChecking your tubes..."
  if ! ping -c 1 google.com > /dev/null 2>&1  ; then
      if ! ping -c 1 yahoo.com > /dev/null 2>&1  ; then
         if ! ping -c 1 bing.com > /dev/null 2>&1 ; then
             clear
             printf "\nDo you have an internet connection???\n\n"
             exit
         fi
      fi
  fi
  printf "\ntubes working....\n\n"

}

# func requires argument
get_aptpkg() {

 tpkg=$(dpkg -s $1 | grep "install ok install")
 if [ -z "$tpkg" ]; then

       if [ -z $aptup ]; then
           # rm -rf /var/lib/apt/lists/*
           apt-get update
           aptup=1
       fi

       echo "[*] installing $1"
       if ! apt-get -y install $1; then
          echo "[!] APT failed to install "$1", are your repos working? Exiting..."
          exit 1
       fi
    else
       echo "[+] $1 is already installed"
  fi

}

get_permission() {
  while true; do
     read -e answer
     case $answer in
          [Yy] ) break;;
          [Yy][eE][sS] ) break;;
          [nN] ) printf "\nExiting Now \n"; exit;;
          [Nn][oO] ) printf "\nExiting Now \n"; exit;;
            *  ) printf "\nNot Valid, Answer y or n\n";;
     esac
  done
}

get_pphrase() {

   echo "Enter the the desired passphrase to use"
   echo "for authentication to upload data."
   echo "When done press [Enter]:"
   while true; do
     read -e pphrase
     printf "\nYou entered : [  $pphrase ]"
     printf "\nIf this is correct, select 1 to continue.\n"
     printf "\nWARNING:\nIf you selection is other than 1 you will have to re-enter the passphrase\n"
     printf "\n [1] Continue"
     printf "\n [2] re-enter passphrase\n\n"
     read -e chk
     case $chk in
          [1] ) printf "\ncontinuing\n"; break;;
          [2] ) printf "\nenter passphrase again\n";;
           *  ) printf "\n\n You entered something else than 1 \n" :
     esac
   done

}



chk_usr root
chk_tubes

if [ -e /var/log/blackhole ]; then
   clear
   echo ""
   echo "You already have installed this before"
   echo "continuing will remove the installed packages"
   echo "and configured files."
   echo ""
   echo "WARNING"
   echo "all files in /var/www/* will be removed"
   echo "do you wish to continue (y/n)".
   get_permission
   rm -rf /var/www/*
   apt-get purge lighttpd
   apt-get purge tor
   rm -rf /var/log/blackhole
   echo "Done"
   exit
fi

clear
echo "WARNING....."
echo ""
echo "This configuration script will install the lighttpd webserver"
echo "and configure the black hole cgi to be served as the main page."
echo "If you already have a web server installed DO NOT CONTINUE."
echo "Do you wish to continue? (Y/N)"

get_permission

echo "[*] Fetching packages.."
get_aptpkg lighttpd
get_aptpkg tor

echo "[*] Setting up Perl..."
curl -L https://cpanmin.us | perl - --sudo App::cpanminus
cpanm -i CGI.pm

if [ -d /var/www/ ]; then
   echo "[!] Something when wrong during install, cannot continue."
   exit
fi

echo "[+] Done getting packages..."
echo "[*] Configuring settings...."

# cleaning out default files, coping cgi over to web-root
# and setting apropriate permissions

rm -rf /var/www/*
cp black-hole.pl /var/www/
chown www-data:www-data /var/www/black-hole.pl

mkdir -p /var/cp-data/auth/
touch /var/cp-data/auth/pphrase
chown www-data:www-data -R /var/cp-data/

# prompting installer to generate a passphrase for authentication
clear
get_pphrase
printf "$pphrase" > /var/cp-data/auth/pphrase

# removing comments from torrc hidden service configuration paramaters
chdsrvc='#HiddenServiceDir /var/lib/tor/hidden_service/'
cvirport='#HiddenServicePort 80 127.0.0.1:80'

hdsrvc='HiddenServiceDir /var/lib/tor/hidden_service/'
virport='HiddenServicePort 80 127.0.0.1:80'

sed -i 's/$chdsrvc/$hdsrvc/g' /etc/tor/torrc
sed -i 's/$cvirport/$virport/g' /etc/tor/torrc


# overwriting default config setting to be specific for black_hole
cat > /etc/lighttpd/lighttpd.conf<<EOF
server.modules = (
	"mod_access",
	"mod_alias",
	"mod_compress",
 	"mod_redirect",
        "mod_cgi",
)

server.document-root        = "/var/www"
server.upload-dirs          = ( "/var/cache/lighttpd/uploads" )
server.errorlog             = "/var/log/lighttpd/error.log"
server.breakagelog          = "/var/log/lighttpd/breakage.log"
server.pid-file             = "/var/run/lighttpd.pid"
server.username             = "www-data"
server.groupname            = "www-data"

index-file.names            = ( "index.html", "black-hole.pl" )

url.access-deny             = ( "~", ".inc" )

cgi.assign                  = ( ".x"   => "/usr/bin/perl" )

static-file.exclude-extensions = ( ".php", ".pl", ".fcgi" )

dir-listing.encoding        = "utf-8"
server.dir-listing          = "enable"

compress.cache-dir          = "/var/cache/lighttpd/compress/"
compress.filetype           = ( "application/x-javascript", "text/css", "text/html", "text/plain" )

EOF

# creating log timestamp of installation
cat > /var/log/blackhole<<EOF
installed on $(tstamp)
EOF

# restaring services
service lighttpd restart
service tor restart


# getting .onion hidden service address to display at end
ONION=$(cat /var/lib/tor/hidden_service/hostname)

echo "[+] Finished!"
echo "[+] Your hidden service hostname is $ONION, be sure to wait a few "
echo "    minutes for the hidden service info to propigate befor connecting."

exit
