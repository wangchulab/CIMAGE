#!/usr/bin/perl
use CGI;
$q = new CGI;

my $time = localtime;
my $remote_addr = $ENV{'REMOTE_ADDR'};
my $curbrowser = $ENV{HTTP_USER_AGENT};

#--- Get values from form-input for dataset and search term
#$dataset = $q->param('dset');
$filetype = 'zip'; ##$q->param('filetype');


print <<ENDOFHTML;
Content-type: text/html\n\n
<html>
<head>
    <title>Dataset submission</title>
    <style type=text/css>a:hover{color:red; text-decoration:underline;}</style>
    <SCRIPT>
    function clearDefault(el){
        if(el.defaultValue==el.value) el.value=""
        }
</SCRIPT>
<style>
    ul{list-style: none}
    a{text-decoration:none}
    a:hover{color:orange; /*text-decoration:underline; font-style: italic;*/}
</style>
<style type="text/css">
#container {
    padding-top:15px;
padding-left:5px;
padding-right:30px;
padding-bottom:40px;
 border: 1px solid 000000;
}
</style>
</HEAD>
<BODY>
<FONT FACE="Arial" SIZE=-1>
<H2>Dataset submission</H2>
This page is for submission of cimage datasets into the general Cravatt-lab CIMAGE database.<P>
<HR>

<P>You are trying to submit a compressed cimage data file to the database

ENDOFHTML

#    @temp = split(/\//, $dataset);
#$filename = @temp[scalar @temp -1];


#print "<B>$filename</B> to the database.  ";

if ($filetype eq "zip") {
    print "Please provide the following information:<P>";
    print "<FORM METHOD=\"post\" ACTION=\"cimage-dset-submit.pl\" ENCTYPE=\"multipart/form-data\">\n";
    print "<div style=\"background-color: #DCDCDC; width: 500px; padding: 30px; border: grey 1px dashed;\">";
    print "Organism: <SELECT NAME=\"organism\">";
    print "<OPTION VALUE=\"human\">Human</OPTION><OPTION VALUE=\"mouse\">Mouse</OPTION><OPTION VALUE=\"yeast\">Yeast</OPTION><OPTION VALUE=\"other\">Other</OPTION></SELECT>";
    print "<P>Sample type: <SELECT NAME=\"type\">\n";
    print "<OPTION VALUE=\"cells\">Cells</OPTION><OPTION VALUE=\"tissue\">Tissue</OPTION><OPTION VALUE=\"other\">Other</OPTION></SELECT>\n";
    print "<P>Isotope type: <SELECT NAME=\"itype\">\n";
    print "<OPTION VALUE=\"isoTOP-ABPP\">isoTOP-ABPP</OPTION><OPTION VALUE=\"silac\">SILAC</OPTION><OPTION VALUE=\"N15\">N15</OPTION><OPTION VALUE=\"other\">Other</OPTION></SELECT>\n";
    print "<P>Probe: <SELECT NAME=\"probe\">\n";
    print "<OPTION VALUE=\"IA\">IA</OPTION><OPTION VALUE=\"FP\">FP</OPTION><OPTION VALUE=\"SU\">SU</OPTION><OPTION VALUE=\"other\">Other</OPTION></SELECT>\n";
    print "<P>Your user name: \n";
    print "<INPUT TYPE=\"text\" NAME=\"name\" SIZE=\"20\" VALUE=\"Your user name here\" onfocus=\"clearDefault(this)\">\n";
    print "<P>Data name: \n";
    print "<INPUT TYPE=\"text\" NAME=\"zip\" SIZE=\"20\" VALUE=\"Data name\" onfocus=\"clearDefault(this)\">\n";
    print "<P>Description (e.g. silac/isoTOP-ABPP, inhibitor treatment, etc):<BR> <INPUT TYPE=\"text\" NAME=\"description\" SIZE=\"80\" VALUE=\"Enter description here\" onfocus=\"clearDefault(this)\">\n";
    ##print "<INPUT TYPE=\"hidden\" NAME=\"location\" VALUE=\"$dataset\">\n";
    print "<P><INPUT TYPE=\"submit\" VALUE=\"Submit\">\n";
    print "</DIV>";
}


print "</body></html>";
