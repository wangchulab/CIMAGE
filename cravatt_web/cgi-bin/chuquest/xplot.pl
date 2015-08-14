#!/usr/bin/perl

use CGI;
use GD;
use GD::Graph;
use GD::Graph::points;
use GD::Graph::axestype;
use xypoints;


$q = new CGI;

$filename1 = $q->param('filename1');
$filename2 = $q->param('filename2');
$sterm = $q->param('sterm');
$mode = $q->param('mode');


my $time = localtime;
my $remote_addr = $ENV{'REMOTE_ADDR'};
my $curbrowser = $ENV{HTTP_USER_AGENT};

$filename1 =~ /from_DTASelect\/([^\/]*)/g;
$desc1 = $1;
$filename2 =~ /from_DTASelect\/([^\/]*)/g;
$desc2 = $1;



open (F1, $filename1) or die "Er";
@f1 = <F1>;
close F1;

open (F2, $filename2) or die "Er";
@f2 = <F2>;
close F2;



for ($i = 0; $i < scalar @f1; ++$i) {
    if ($f1[$i] =~ /^\s/) {
    } elsif ($f1[$i] =~ /^\d+/) {
#	print "$tin[$i]<BR>\n";
	@currow = split(/\t/,$f1[$i]);
	@nextrow = split(/\t/,$f1[$i+1]);
	$curdesc = "$nextrow[1] - $nextrow[3] - $currow[4]";
	$r1holder{$curdesc}[0] = $currow[6];
	$r1holder{$curdesc}[1] = $currow[7];
	$r1holder{$curdesc}[2] = $currow[8];
	
    }
}

for ($i = 0; $i < scalar @f2; ++$i) {
    if ($f2[$i] =~ /^\s/) {
    } elsif ($f2[$i] =~ /^\d+/) {
#	print "$tin[$i]<BR>\n";
	@currow = split(/\t/,$f2[$i]);
	@nextrow = split(/\t/,$f2[$i+1]);
	$curdesc = "$nextrow[1] - $nextrow[3] - $currow[4]";
	$r2holder{$curdesc}[0] = $currow[6];
	$r2holder{$curdesc}[1] = $currow[7];
	$r2holder{$curdesc}[2] = $currow[8];
	
    }
}





my $my_graph = GD::Graph::xypoints->new(640,480);




foreach (keys %r1holder) {
    if (exists $r1holder{$_}[2]) {
        $usedkeys{$_} = 1;
	push (@x10, $r1holder{$_}[2]);
	push (@names, $_);
	if (exists $r2holder{$_}[2]) {
	    push (@y10, $r2holder{$_}[2]);
	} else {
	    push (@y10, 0);
	}
    } 
}

foreach (keys %r2holder) {
    if ((exists $r2holder{$_}[2]) && !(exists $usedkeys{$_})) {
	push (@names, $_);
	push (@y10, $r2holder{$_}[2]);

	if (exists $r1holder{@_}[2]) {
	    push (@x10, $r1holder{$_}[2]);
	} else {
	    push (@x10, 0);
	}
    }
}



@data = (\@x10, \@y10);




$my_graph->set(
	       t_margin          => 10,
	       b_margin          => 30,
	       r_margin          => 10,
	       l_margin          => 10,
	       x_label => "$desc1 - 1:10 ratio",
	       y_label => "$desc2 - 1:10 ratio",
	       title => "chuquest xplot",

	       fgclr => 'lgray',

#	       y_max_value=>$max10,
	       y_max_value=>14,
#	       y_min_value=>0,
	       x_max_value =>14,  #approx 3000 kDa
#	       x_min_value => 3.5, #approx 3 kDa
	       
#	       y_number_format => \&y_number_reverse,  #this function reverses the values on the x-axis
#	       x_number_format => \&x_number_exp,      #this function formats the values on the y-axis (takes numbers out of log-scale, adds 'kDa', etc)
	       
	       x_tick_number => 8,
#	       x_label_skip =>1,
	       y_tick_number => 7,
#	       x_ticks => 20,
	       x_long_ticks => 0,
	       y_long_ticks => 0,
#	       x_labels_vertical => 0,
	       marker_size => 1,
#	       markers => [3,2,8],
	       transparent => 0,
	       dclrs => [qw(blue), qw(green), qw(red)], 
);


my $gd = $my_graph->plot(\@data);


@xp10 = ();
@yp10 = ();


$red = $gd->colorAllocate(255,0,0);  #define colors
$blue = $gd->colorAllocate(0,0,255);
$black = $gd->colorAllocate(0,0,0);
$grey = $gd->colorAllocate(225,225,225);

for ($i = 0; $i < scalar @names; ++$i) {

    ( $xp10[$i], $yp10[$i] ) = $my_graph->val_to_pixel( $x10[$i], $y10[$i], 1 );
    if (($names[$i] =~ /$sterm/gi) && ($sterm ne "")) {
	push (@hlx, $xp10[$i]);
	push (@hly, $yp10[$i]);
	$gd->arc($xp10[$i], $yp10[$i], 15, 15, 0, 360, $red);
    }

}


&makepng if ($mode eq "png");
&makehtml if ($mode eq "html");



    print "<MAP NAME=\"map1\">\n";

    for ($i = 0; $i < scalar @names; ++$i) {
	print "<AREA HREF=\"\" TITLE=\"$names[$i]\" SHAPE=\"CIRCLE\" COORDS=\"$xp10[$i], $yp10[$i],3\">\n";
    }

    print "</MAP>\n";

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
