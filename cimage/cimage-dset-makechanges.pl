#!/usr/bin/perl

use CGI;

$q = new CGI;

$filename = $q->param('filename');
$organism = $q->param('organism');
$type = $q->param('type');
$itype = $q->param('itype');
$name = $q->param('name');
$probe = $q->param('probe');
$description = $q->param('description');

print <<ENDOFHTML;
Content-type: text/html

<html>
<head><title>Changes Saved!</title>
<style>
    ul{list-style: none}
a{text-decoration:none}
a:hover{color:orange; /*text-decoration:underline; font-style: italic;*/}
</style>
<SCRIPT>
    function clearDefault(el){
if(el.defaultValue==el.value) el.value=""
}
</SCRIPT>
</head>
<body link="696969" vlink="696969" bgcolor="FFFFFF">

<font face="arial, helvetica">
ENDOFHTML

print "<H3>Changes saved!</H3>\n";

print "You have successfully changed the description for the <code>$filename</code> dataset.  <A HREF=\"/cgi-bin/cravatt/restricted/cimage-dset-search.pl\">Click here</A> to return.<BR>\n";

open (IND, '/srv/www/htdocs/cimage/cimage_data/index.txt') or die "Cannot open index.txt";
@ind = <IND>;
close IND;


#print "$filename:<P>\n";
print "<H3>Summary of changes:</H3>\n";
print "<HR>\n";
print "<B>Dataset description:</B>\n";
print "<TABLE BORDER=1>\n";
print "<TR><TD><B>Old</TD><TD><B>New</TD></TR>\n";

open (IOUT, '>/srv/www/htdocs/cimage/cimage_data/index.tmp') or die "cannot open temp index";

foreach (@ind) {
    if ($_ =~ /^$filename\t/) {
	@match = split(/\t/, $_);
	print "<TR><TD>$match[1]</TD><TD>$organism</TD></TR>\n";
	print "<TR><TD>$match[2]</TD><TD>$type</TD></TR>\n";
	print "<TR><TD>$match[3]</TD><TD>$itype</TD></TR>\n";
	print "<TR><TD>$match[4]</TD><TD>$probe</TD></TR>\n";
	print "<TR><TD>$match[5]</TD><TD>$name</TD></TR>\n";
	print "<TR><TD>$match[7]</TD><TD>$description</TD></TR>\n";
	print IOUT "$filename\t$organism\t$type\t$itype\t$probe\t$name\t$match[6]\t$description\n";
	print "</TABLE><HR>\n";
    } else {
	print IOUT $_;
    }
}

close IOUT;

$savecommand = "cp /srv/www/htdocs/cimage/cimage_data/index.tmp /srv/www/htdocs/cimage/cimage_data/index.txt";

system ($savecommand);




