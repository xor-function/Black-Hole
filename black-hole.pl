#!/usr/bin/perl
#  _          _           _      _
# |_)|   /\  |  |_/  |_| | | |  |_
# |_)|_ /--\ |_ | \  | | |_| |_ |_
#
# BLACK_HOLE
# by xor-function 



use CGI;
use File::Basename;
use strict;

$CGI::POST_MAX=1024 * 10000;

my $time = qx(date +"%m""%d""%H""%M""%N");
chomp($time);
$time =~ s/\r|\n//g;

my $q = CGI->new();
my $priv_key = "../cp-data/auth/private.pem";
my $sanitize = "a-zA-Z0-9_.-";
my $upload_dir = "/var/cp-data/";
my $ext_eml = "$time.eml";
my $enc_dir = "../tmp/";
my $enc = 'enc';
my $decrypt;
my $pph;
my $auth;
my $sym = 'sym';
my $tpass;
my $enckey;
my $symkey;
my $data = 'data';
my $file;
my $fupload_append = "$time";

sub get_param{

	$_[0] = $q->param($_[1]) or die("nothing recieved");
	if (!$enc && $q->cgi_error) {
	     print $q->header(-status=>$q->cgi_error);
	     exit 0;
	}

	my $type = $q->uploadInfo($_[0])->{'Content-Type'};
	unless ($type eq 'application/octet-stream') {
	    die "STREAM FILES ONLY!";
	}

        $_[0] =~ s/^[^$sanitize]//g;          

        my ( $name, $path, $ext ) = fileparse( $_[0], '\..*' );
        $_[0] = $name."-"."$_[2]";

        my $upload_fh = $q->upload($_[1]);

        open( UPLOADFILE, ">$_[3]/$_[0]" ) or die("Upload failed");
        binmode UPLOADFILE;
        while ( <$upload_fh>) {
          print UPLOADFILE;
        }
        close UPLOADFILE;
        print "file received....\n";
   
}

print <<"EOF";
Content-Type: text/html\n\n
<body bgcolor="#000000">
<h1><font color="white">you do not belong here....</font></h1>
EOF

####
# FIRST upload param deals with authentication of post data
get_param($auth, $enc, $ext_eml, $enc_dir);

# validation of correct public key through successfull decryption
system("openssl", "smime", "-decrypt", "-in", "$enc_dir/$auth", "-inkey", "$priv_key", "-out", "$enc_dir/check-$time" ) == 0 
   or die("de-enc failed");

# validation of authorized individual who used public key to encrypt correct passphrase
$decrypt = qx(cat $enc_dir/check-$time);
$pph = qx(cat ../cp-data/auth/pphrase);

# removing whitespaces and carrige returns
chomp($decrypt);
$decrypt =~ s/\r|\n//g;

chomp($pph);
$pph =~ s/\r|\n//g;

# authenticating
if ( "$decrypt" ne "$pph" ) {
 print "UNATHORIZED USER";
 die("UNATHORIZED USER");
}

# cleaning up temp files 
system("rm", "$enc_dir/$auth", "$enc_dir/check-$time");



####
# SECOND post upload param, create a disposable passpharase for the following uploaded data.
get_param($tpass, $sym, $ext_eml, $upload_dir);

# validation of correct public key through successfull smime decryption
$enckey = qx(cat $upload_dir/$tpass);
$symkey = qx(echo "$enckey" | openssl smime -decrypt -aes256 -inkey $priv_key) or die("DEC TMPKEY FAILED");

# making sure there are no white spaces or carrige returns 
chomp($symkey);
$symkey =~ s/\r|\n//g;

# cleanup encrypted file
system("rm", "$upload_dir/$tpass");


####
# THIRD upload param, has capture info
get_param($file, $data, $fupload_append, $upload_dir);

# decrypting symmetric encryption on server
system("openssl", "enc", "-aes-256-cbc", "-d", "-a", "-in", "$upload_dir/$file", "-out", "$upload_dir/dec-$file", "-k", "$symkey" ) == 0
   or die("decrypting uploaded data failed");

# cleaning up encrypted version
system("rm", "-f", "$upload_dir/$file");
print "UPLOAD SUCCESSFUL!\n";


