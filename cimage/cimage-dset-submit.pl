#!/usr/bin/perl
use CGI;
$q = new CGI;

my $time = localtime;
my $remote_addr = $ENV{'REMOTE_ADDR'};
my $curbrowser = $ENV{HTTP_USER_AGENT};

#--- Get values from form-input for dataset and search term
#$dataset = $q->param('dset');
$org = $q->param('organism');
$stype = $q->param('type');
$itype = $q->param('itype');
$probe = $q->param('probe');
$username = $q->param('name');
$zipname = $q->param('zip');
$zipname =~ s/\.zip$//g;
$desc = $q->param('description');
$location = "/srv/www/htdocs/cimage/tempul/temp.zip";##$q->param('location');




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
ENDOFHTML
print "organism: $org<BR>\n";
print "sample-type: $stype<BR>\n";
print "labeling-type: $itype<BR>\n";
print "probe: $probe<BR>\n";
print "username: $username<BR>\n";
print "description: $desc<BR>\n";
print "file location: $location<BR>\n";

if ( ! -s "$location" ) {
    print "<P><FONT COLOR=FF0000><B>file $location does not exist! </FONT></B>you must run zip_cimage.bash to transfer data to the server first!</B>";
    print "</body></html>";
    exit;
}

@locarray = split(/\//, $location);
$filename = $locarray[scalar @locarray - 1];

$filesavename = $zipname;
$filesavename =~ s/\s/_/g;
$filesavename =~ s/\.zip$//g;

print "file name: $filename<BR>\n";

if (-d "/srv/www/htdocs/cimage/cimage_data/$filesavename")
{
    print "<P><FONT COLOR=FF0000><B>file already exists! </FONT></B>you must <A HREF=\"cimage-dset-remove.pl?function=del&set2del=$filesavename\" onClick=\"javascript:return confirm(\'Are you sure you want to remove data $filesavename?\')\">remove</A> the existing dataset named $filesavename or <A HREF=\"javascript:history.go(-1)\">change </A> the filename of this submssion.</B>";
} else {
    $copycommand = "mkdir -p /srv/www/htdocs/cimage/cimage_data/$filesavename";
    system($copycommand);
    $copycommand = "unzip $location -d /srv/www/htdocs/cimage/cimage_data/$filesavename > /dev/null";
#    print "<P><P>copycommand: $copycommand";
    system ($copycommand);
    open (INDIN, ">>/srv/www/htdocs/cimage/cimage_data/index.txt") or die "cannot open index.txt!";
    print INDIN "$filesavename\t$org\t$stype\t$itype\t$probe\t$username\t$time\t$desc\n";
    close INDIN;

    print "<P><FONT COLOR=009900><B>$filesavename successfully added!</B></FONT>";

    system('echo "' . $filesavename  . ' uploaded by ' . $remote_addr . '"|mail -s "CIMAGE dataset upload" chuwang@scripps.edu');
    system("rm -f $location");

}


print "<P><P><A HREF=\"cimage-dset-add.pl?function=list\">Upload another file</A>.\n";
print "<P><P><A HREF=\"cimage-dset-remove.pl?function=list\">Remove another file</A>.\n";


print "</body></html>";
