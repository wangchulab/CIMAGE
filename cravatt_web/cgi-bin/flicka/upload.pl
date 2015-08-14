#!/usr/bin/perl

use CGI;

$CGI::POST_MAX = 1024 * 5000; # 5MB limit
$safe_filename_characters = "a-zA-Z0-9_.-";
$upload_dir = "/home/gabriels/uploaded_files/";

$q = new CGI;
$filename = $q->param('filename');

if ( !$filename ) {
    print $q->header ();
    print "Problem! try a smaller file!";
    exit;
}

$filename =~ tr/\s/_/;
$filename =~ s/[^$safe_filename_characters]//g;

$upload_filehandle = $q->upload("filename");

open (UPLOADFILE, ">$upload_dir/$filename" ) or die "$!";
while ( <$upload_filehandle> ) {
    print UPLOADFILE;
}

close UPLOADFILE;

print $q->header ();
print <<END_HTML;
<html>
<head></head>
<body>
thank you for uploading your file!!
</body>
</html>
END_HTML

