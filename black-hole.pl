#!/usr/bin/perl
#  _          _           _      _
# |_)|   /\  |  |_/  |_| | | |  |_
# |_)|_ /--\ |_ | \  | | |_| |_ |_
#
# BLACK_HOLE
# by xor-function 
# license BSD 3 

use CGI;
use File::Basename;
use strict;

$CGI::POST_MAX=1024 * 10000;

sub tstamp{ 

	my $tlog = qx(date +"%m""%d""%H""%M""%N");
	chomp($tlog);
	$tlog =~ s/\r|\n//g;

	return $tlog;
}

sub get_param{

	my $param_one	= $_[0];
	my $param_two 	= $_[1];
	my $param_three = $_[2];
	my $param_four  = $_[3];

	my $sanitize = "a-zA-Z0-9_.-";

	my $q = CGI->new();
	$param_one = $q->param($param_two) or die("nothing recieved");

	if (!'enc' && $q->cgi_error) {
	     print $q->header(-status=>$q->cgi_error);
	     exit 0;
	}

	my $type = $q->uploadInfo($param_one)->{'Content-Type'};
	unless ($type eq 'application/octet-stream') {
	    die "STREAM FILES ONLY!";
	}

        $param_one =~ s/^[^$sanitize]//g;          

        my ( $name, $path, $ext ) = fileparse( $param_one, '\..*' );
        $param_one = $name."-"."$param_three";

        my $upload_fh = $q->upload($param_two);

        open( UPLOADFILE, ">$param_four/$param_one" ) or die("Upload failed");
        binmode UPLOADFILE;
        while ( <$upload_fh>) { print UPLOADFILE; }
        close UPLOADFILE;
        print "file received....\n";

	return $param_one;   

}

sub main { 

	my $time = tstamp();
	my $priv_key = "../cp-data/auth/private.pem";
	my $upload_dir = "/var/cp-data/";
	my $ext_eml = "$time.eml";
	my $enc_dir = "../tmp/";
	my $enc   = 'enc';
	my $sym   = 'sym';
	my $data  = 'data';
	my $auth  = $_[0];
	my $tpass = $_[1];
	my $file  = $_[2];  
	my $fupload_append = "$time";


	# FIRST upload param deals with authentication of post data
	$auth = get_param($auth, $enc, $ext_eml, $enc_dir);
	
	# validation of correct public key through successfull decryption
	system("openssl", "smime", "-decrypt", "-in", "$enc_dir/$auth", "-inkey", "$priv_key", "-out", "$enc_dir/check-$time" ) == 0 
   		or die("de-enc failed");

	# validation of authorized individual who used public key to encrypt correct passphrase
	my $decrypt = qx(cat $enc_dir/check-$time);
	my $pph = qx(cat ../cp-data/auth/pphrase);

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

	# SECOND post upload param, create a disposable passpharase for the following uploaded data.
	$tpass = get_param($tpass, $sym, $ext_eml, $upload_dir);

	# validation of correct public key through successfull smime decryption
	my $enckey = qx(cat $upload_dir/$tpass);
	my $symkey = qx(echo "$enckey" | openssl smime -decrypt -aes256 -inkey $priv_key) or die("DEC TMPKEY FAILED");

	# making sure there are no white spaces or carrige returns 
	chomp($symkey);
	$symkey =~ s/\r|\n//g;

	# cleanup encrypted file
	system("rm", "$upload_dir/$tpass");

	# THIRD upload param, has capture info
	$file = get_param($file, $data, $fupload_append, $upload_dir);

	# decrypting symmetric encryption on server
	system("openssl", "enc", "-aes-256-cbc", "-d", "-a", "-in", "$upload_dir/$file", "-out", "$upload_dir/dec-$file", "-k", "$symkey" ) == 0
   		or die("decrypting uploaded data failed");

	# cleaning up encrypted version
	system("rm", "-f", "$upload_dir/$file");
	print "UPLOAD SUCCESSFUL!\n";

}

print <<"EOF";
	Content-Type: text/html\n
        <body bgcolor="#000000">
        <h1><font color="white">you do not belong here...</font></h1>
EOF

main(@ARGV);

