#!/usr/bin/perl

use CGI;

$q = new CGI;

$pdfname = $q->param('pdfname');
$pagenum = $q->param('pagenum');

system("pdftk A=$pdfname cat $pagenum-$pagenum output /srv/www/htdocs/tmp/cimage_tmp.pdf")
system("convert /srv/www/htdocs/tmp/cimage_tmp.pdf /srv/www/htdocs/tmp/cimage_tmp.png")

#&makepng if ($mode eq "png");
#&makehtml if ($mode eq "html");


print "Content-type: text/html\n\n";

print "<h3>hello: $pagenum</h3>\n";

#print "<IMG SRC=\"/srv/www/htdocs/tmp/cimage_tmp.png\">";

##### begin graph ######
sub makepng {

    binmode STDOUT;

    print STDOUT "Content-type: image/png\n\n";
    print STDOUT $gd->png;
}

sub makehtml {


open (LOGOUT, ">>/home/gabriels/public_html/mpdlog.txt");
print LOGOUT "CHQ_Xplot: $remote_addr plotted ($sterm) $filename1 v $filename2 on $time with $curbrowser\n";
close LOGOUT;



    print "Content-type: text/html\n\n";
    print "<HTML><HEAD><TITLE>plot</TITLE></HEAD><BODY>\n";


    $url1 = $filename1;
    $url2 = $filename2;
    $url1 =~ s/\.txt/\.html/g;
    $url2 =~ s/\.txt/\.html/g;
    $url1 =~ s/\/home\//\/~/g;
    $url2 =~ s/\/home\//\/~/g;
    $url1 =~ s/\/public_html//g;
    $url2 =~ s/\/public_html//g;

    print "link to: <A HREF=\"$url1\" TARGET=\"_blank\">dataset 1 ($desc1)</A> <A HREF=\"$url2\" TARGET=\"_Blank\">dataset 2 ($desc2)</A><P>\n";

    print "<H3>mouse-over spots to see the protein-names</H3>\n";

    print "<IMG SRC=\"xplot.pl?filename1=$filename1&filename2=$filename2&mode=png&sterm=$sterm\" USEMAP=\"#map1\" BORDER=0><BR>\n";


    print "<FORM METHOD=\"GET\" ACTION=\"xplot.pl\">\n";
    print "File1: <INPUT TYPE=\"TEXT\" SIZE=80 NAME=\"filename1\" VALUE=\"$filename1\"><BR>\n";
    print "File2: <INPUT TYPE=\"TEXT\" SIZE=80 NAME=\"filename2\" VALUE=\"$filename2\"><BR>\n";
    print "Search-term (optional): <INPUT TYPE=\"TEXT\" SIZE=\"20\" NAME=\"sterm\" VALUE=\"$sterm\"><BR>\n";
    print "<INPUT TYPE=\"HIDDEN\" NAME=\"mode\" VALUE=\"html\">\n";
#    print "How many points: <INPUT TYPE=\"TEXT\" SIZE=\"5\" NAME=\"howmany\" VALUE=\"$howmany\">\n";
    print "<INPUT TYPE=\"submit\" VALUE=\"plot\"><P>\n";
    print "</FORM>\n";


}
