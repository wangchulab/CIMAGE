#!/usr/bin/perl

use CGI;

$q = new CGI;

$filename = $q->param('filename');
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


print "<H3>Dataset $filename: $description</H3>\n";

$fullpath='/srv/www/htdocs/cimage/cimage_data/'.$filename.'/';
$readme=$fullpath.'readme.txt';

$findcmd="find $fullpath -name \"combined_*.html\" > $fullpath/list.tmp";
system($findcmd);
open (IN, "$fullpath/list.tmp") or die "cannot open temp list";
@list = <IN>;
$count = 0;
$newpath="http://bfclabcomp3.scripps.edu/cimage/cimage_data/$filename/";
foreach (@list) {
    $count++;
    $newfile = $_;
    $newfile =~ s/$fullpath//g;
    print "Result $count: <A HREF=\"$newpath$newfile\">$newfile</A>.<BR>\n";
}
close(IN);
print "<BR><BR>\n";

if ( -e $readme ) {
    print "Detailed description[<A HREF=\"http://bfclabcomp3.scripps.edu/cimage/upload_readme.php?filename=$filename\">update</A>]:<BR><BR>\n";
    open (IN, "$readme");
    @file = <IN>;

    foreach (@file) {
	print "&nbsp&nbsp&nbsp&nbsp<I>$_</I><BR>\n";
    }
    close(IN);
} else {
   print "Detailed description[<A HREF=\"http://bfclabcomp3.scripps.edu/cimage/upload_readme.php?filename=$filename\">add</A>]:<BR><BR>\n";
}
