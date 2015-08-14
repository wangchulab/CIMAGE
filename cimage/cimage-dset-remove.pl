#!/usr/bin/perl
use CGI;
$q = new CGI;

$function = $q->param('function');
$set2del = $q->param('set2del');



print <<ENDOFHTML;
Content-type: text/html\n\n
<html>
<head>
    <title>Remove MudPIT dataset</title>
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

<font face="arial, helvetica">


ENDOFHTML

print "<H3>CIMAGE dataset file-handler</H3>";

print "<div style=\"background-color: #DCDCDC; width: 500px; padding: 30px; border: grey 1px dashed;\">\n";

&select if ($function =~ /list/);
&rmfile if ($function =~ /del/);

print "</div>\n";



print "</BODY></HTML>";



sub select {
    opendir(MYDIR, "/srv/www/htdocs/cimage/cimage_data/") or die("Cannot open directory");
    @mydir = readdir(MYDIR);
    close MYDIR;

    print "<H3>Select CIMAGE dataset to remove:</H3>\n";

    print "<FORM METHOD=get ACTION=\"cimage-dset-remove.pl\" ENCTYPE=\"multipart/form-data\" NAME=\"keywordsearch\">\n";
    print "<INPUT TYPE=\"hidden\" NAME=\"function\" VALUE=\"del\">\n";

    print "File to delete: <SELECT NAME=\"set2del\">\n";

    foreach (@mydir) {
	print "<OPTION VALUE=\"$_\">$_<\/OPTION><BR>\n" if (($_ =~ /\w+/) && ! ( $_ =~ /^index/));
    }

    print "<\/SELECT>\n";

#    print "<P>Keyword: <INPUT TYPE=\"text\" NAME=\"searchterm\" SIZE=20 VALUE=\"search term\" onfocus=\"clearDefault(this)\">\n";

    print "<INPUT TYPE=submit VALUE=\"DELETE\" onClick=\"javascript:return confirm('ARE YOU SURE?  Deleting this file is permanent and cannot be undone!!!!')\">\n";

}

sub rmfile {
#    print "file to delete: /home/gabriels/public_html/clmpd2/mpd_data/$set2del<P>\n";
#    print "index data: <BR>\n";

    open (INDIN, "/srv/www/htdocs/cimage/cimage_data/index.txt") or die "cannot open index.txt";
    @index = <INDIN>;
    close INDIN;

    open (INDOUT, ">/srv/www/htdocs/cimage/cimage_data/index.txt") or die "cannot open index.txt";

    print "<FONT SIZE=-1><UL>";

    print "<FONT COLOR=FF0000>$set2del DELETED!</FONT>\n";

    foreach (@index) {
	if ($_ =~ /^$set2del\t/) {
#	    print "<LI>$_</LI>\n";
	} else {
#	    print "<LI><B>$_</B><BR></LI>\n";
	    print INDOUT $_;
	}
    }
    print "<\UL>";
    $delcommand = "rm -r /srv/www/htdocs/cimage/cimage_data/$set2del";
#    print "delcommand: $delcommand<BR>";
    close INDOUT;
    system ($delcommand);
}
