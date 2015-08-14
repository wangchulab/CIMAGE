#!/usr/bin/perl

use CGI;
use GD;
use GD::Graph;
use GD::Graph::points;


$q = new CGI;

$filename = $q->param('filename');
$mode = $q->param('mode');
$howmany = $q->param('howmany');




open (TIN, $filename) or die "Er";
@tin = <TIN>;
close TIN;

for ($i = 0; $i < scalar @tin; ++$i) {
    if ($tin[$i] =~ /^\s/) {
#	@currow = split(/\t/,$_);
	
    } elsif ($tin[$i] =~ /^\d+/) {
#	print "$tin[$i]<BR>\n";
	@currow = split(/\t/,$tin[$i]);
	@nextrow = split(/\t/,$tin[$i+1]);
	$curdesc = "$nextrow[1] - $nextrow[2]";
	$rholder{$curdesc}[0] = $currow[6];
	$rholder{$curdesc}[1] = $currow[7];
	$rholder{$curdesc}[2] = $currow[8];
	
    }
}


$my_graph = GD::Graph::points->new(1024,480);

@sortedrats = sort {$rholder{$a}[2] <=> $rholder{$b}[2]} keys %rholder;


$counter = 0;
$tempcounter = 0;
#foreach (keys %rholder) {
for ($i = 0; $i < scalar @sortedrats; ++$i) {
    if ($rholder{$sortedrats[$i]}[2] > 0) {
	++$tempcounter;
	$counter[$tempcounter] = $tempcounter;
	$ratio11[$tempcounter] = $rholder{$sortedrats[$i]}[0];
	$ratio15[$tempcounter] = $rholder{$sortedrats[$i]}[1];
	$ratio110[$tempcounter] = $rholder{$sortedrats[$i]}[2];
	$names[$tempcounter] = $sortedrats[$i];
	$max10 = $ratio110[$tempcounter] if ($ratio110[$tempcounter] > $max10);
    }
}

#@data = (\@ratio11, \@ratio15, \@ratio110);
@data = (\@counter, \@ratio11, \@ratio15, \@ratio110);

$howmany = scalar @counter if ($howmany < 1);

$my_graph->set(
	       t_margin          => 10,
	       b_margin          => 30,
	       r_margin          => 10,
	       l_margin          => 10,
	       x_label => "x",
	       y_label => 'y',
	       title => "chuquest",

	       fgclr => 'lgray',

#	       y_max_value=>$max10,
	       y_max_value=>14,
#	       y_min_value=>0,
	       x_max_value =>$howmany,  #approx 3000 kDa
#	       x_min_value => 3.5, #approx 3 kDa
	       
#	       y_number_format => \&y_number_reverse,  #this function reverses the values on the x-axis
#	       x_number_format => \&x_number_exp,      #this function formats the values on the y-axis (takes numbers out of log-scale, adds 'kDa', etc)
	       
	       x_tick_number => 20,
	       x_label_skip =>1,
	       y_tick_number => 4,
	       x_ticks => 20,
	       x_long_ticks => 0,
	       y_long_ticks => 1,
#	       x_labels_vertical => 0,
	       marker_size => 2,
	       markers => [3,2,8],
	       transparent => 0,
	       dclrs => [qw(blue), qw(green), qw(red)], 
);


my $gd = $my_graph->plot(\@data);

&makepng if ($mode eq "png");
&makehtml if ($mode eq "html");


@xp11 = ();
@yp11 = ();
@xp15 = ();
@yp15 = ();
@xp110 = ();
@yp110 = ();

for ($i = 0; $i < scalar @names; ++$i) {

    ( $xp11[$i], $yp11[$i] ) = $my_graph->val_to_pixel( $counter[$i], $ratio11[$i], 1 );
    ( $xp15[$i], $yp15[$i] ) = $my_graph->val_to_pixel( $counter[$i], $ratio15[$i], 1 );
    ( $xp110[$i], $yp110[$i] ) = $my_graph->val_to_pixel( $counter[$i], $ratio110[$i], 1 );
#    print "$names[$i] - $ratio11[$i], $ratio15[$i], $ratio110[$i] -- $yp11[$i], $yp15[$i], $yp110[$i]<BR>\n";
}


    print "<MAP NAME=\"map1\">\n";

    for ($i = 0; $i < scalar @names; ++$i) {
	print "<AREA HREF=\"\" TITLE=\"$names[$i]\" SHAPE=\"CIRCLE\" COORDS=\"" . ($xp11[$i]+ 6) . ", $yp11[$i],3\">\n";
	print "<AREA HREF=\"\" TITLE=\"$names[$i]\" SHAPE=\"CIRCLE\" COORDS=\"" . ($xp11[$i] + 6) . ", $yp15[$i],3\">\n";
	print "<AREA HREF=\"\" TITLE=\"$names[$i]\" SHAPE=\"CIRCLE\" COORDS=\"" . ($xp110[$i] + 6) . ", $yp110[$i],3\">\n";
    }

    print "</MAP>\n";

##### begin graph ######
sub makepng {

    binmode STDOUT;

    print STDOUT "Content-type: image/png\n\n";
    print STDOUT $gd->png;
}

sub makehtml {
    
    print "Content-type: text/html\n\n";
    print "<HTML><HEAD><TITLE>plot</TITLE></HEAD><BODY>\n";

    print "<H3>mouse-over spots to see the protein-names</H3>\n";

    print "<FORM METHOD=\"GET\" ACTION=\"plot.pl\">\n";
    print "<INPUT TYPE=\"HIDDEN\" NAME=\"filename\" VALUE=\"$filename\">\n";
    print "<INPUT TYPE=\"HIDDEN\" NAME=\"mode\" VALUE=\"html\">\n";
    print "How many points: <INPUT TYPE=\"TEXT\" SIZE=\"5\" NAME=\"howmany\" VALUE=\"$howmany\">\n";
    print "<INPUT TYPE=\"submit\" VALUE=\"re-plot\"><P>\n";

    print "<IMG SRC=\"plot.pl?filename=$filename&mode=png&howmany=$howmany\" USEMAP=\"#map1\" BORDER=0><BR>\n";

}
