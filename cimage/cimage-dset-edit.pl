#!/usr/bin/perl

use CGI;

$q = new CGI;

$filename = $q->param('filename');

print <<ENDOFHTML;
Content-type: text/html

<html>
<head><title>CIMAGE Dataset Editor</title>
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

print "<H3>Description Editor</H3>\n";

print "Filename: <B>$filename</B><HR>\n";

open (IND, '/srv/www/htdocs/cimage/cimage_data/index.txt') or die "Cannot open index.txt";
@ind = <IND>;
close IND;

print "<FORM METHOD=\"get\" ACTION=\"/cgi-bin/cravatt/restricted/cimage-dset-makechanges.pl\" ENCTYPE=\"multipart/form-data\">\n";
print "<INPUT TYPE=\"hidden\" NAME=\"filename\" VALUE=\"$filename\">\n";


foreach (@ind) {
    if ($_ =~ /^$filename\t/) {
	#print $_;
	@match = split(/\t/, $_);
#	print "<INPUT TYPE=\"hidden\" NAME=\"submitdate\" VALUE=\"$match[4]\">\n";
	print "<P>Organism: \n";
	print "<SELECT NAME=\"organism\">\n";
	print "<OPTION ";
	print "SELECTED" if ($match[1] =~ /human/);
	print " VALUE=\"human\">human</OPTION>\n";
	print "<OPTION ";
	print "SELECTED" if ($match[1] =~ /mouse/);
	print " VALUE=\"mouse\">mouse</OPTION>\n";
	print "<OPTION ";
	print "SELECTED" if ($match[1] =~ /yeast/);
	print " VALUE=\"yeast\">yeast</OPTION>\n";
	print "<OPTION ";
	print "SELECTED" if ($match[1] =~ /other/);
	print " VALUE=\"other\">other</OPTION>\n";
	print "</SELECT><P>\n";
	print "Sample-type: <INPUT TYPE=\"text\" NAME=\"type\" VALUE=\"$match[2]\"><P>\n";
	print "Isotope-type: <INPUT TYPE=\"text\" NAME=\"itype\" VALUE=\"$match[3]\"><P>\n";
	print "Probe: <INPUT TYPE=\"text\" NAME=\"probe\" VALUE=\"$match[4]\"><P>\n";
	print "Submitter name: <INPUT TYPE=\"text\" NAME=\"name\" VALUE=\"$match[5]\"><P>\n";
	print "Description: <INPUT TYPE=\"text\" NAME=\"description\" VALUE=\"$match[7]\" SIZE=\"80\">\n";
	print "<HR>\n";
	print "<P><INPUT TYPE=\"submit\" VALUE=\"Submit Changes\">\n";
    }
}

