#!/usr/local/bin/perl

#-------------------------------------
#	View GBU Stats
#	(C)2001 Harvard University
#	
#	W. S. Lane/E. Perez
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



################################################
# Created: 2/20/01 by Edward Perez
# most recent update: 2/26/01
#
# Description: Calculates and displays stats on GBU summary
#



################################################
# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
	require "microchem_form_defaults.pl";
	require "goodbadugly_include.pl";
}



#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$dir = $FORM{"directory"};
$percentType = ( defined($FORM{"percent"}) ? $FORM{"percent"} : $DEFS_VIEW_GBU_STATS{"percent"} );
$content = ( defined($FORM{"content"}) ? $FORM{"content"} : $DEFS_VIEW_GBU_STATS{"content"} );
$use_selected = $FORM{"use_selected"};
$selected = $FORM{"selected"};
$use_selected = $selected ? "yes" : "";


if($percentType eq "total"){
	$checked_total = "checked";
}elsif($percentType eq "row"){
	$checked_row = "checked";
}elsif($percentType eq "column"){
	$checked_column = "checked";
}elsif($percentType eq "cell"){
	$checked_cell = "checked";
}

if($content eq "TIC"){
	$checked_TIC = "checked";
}elsif($content eq "count"){
	$checked_count = "checked";
}


#######################################
# Initial output
#&MS_pages_header("View GBU Stats","#871F78");
print <<EOHEAD;
Content-type: text/html
<html>
<head>
<META HTTP-EQUIV="Expires" CONTENT="Tue, 01 Jan 1980 1:00:00 GMT">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<title>GBU Summary Stats</title>
$stylesheet_html
$header_tags
</head>

<body>
EOHEAD

#print "Che, voludo!<br>";
#foreach (keys %FORM) {
#	print "$_ $FORM{$_}<br>";
#}

##########################################
#
#		 Main Action
#


# load up the GBU stuff or produce an error
open GBUFILE, "$seqdir/$dir/goodbadugly.txt" or &error("Directory does not contain GBU information yet");
my($gbukey,$gbuvalue,$gbucolor,$gburating,$score);
while( <GBUFILE>){
		($gbukey,$gbuvalue) = split / /;
		$gbuvalue =~ s/\s//;			#chop off any whitespace
		$gbuscores{$gbukey} = $gbuvalue;
}
close GBUFILE;

@dtas = &get_DTA_file_list();

if($selected){
	&make_selected_hash();
}

$rate_func = sub { return($gbuscores{$_[0]}); };


sub get_DTA_file_list{
	my(@list,@DTAlist,$name);
	opendir DIR , "$seqdir/$dir";
	@list = readdir DIR;
	foreach $name (@list) {
		if ($name =~ /\.dta$/) {
			push @DTAlist, $name;
		}
	}
	return(@DTAlist);
}

sub make_selected_hash{
	my(@selected)  = split /,/, $selected;
	foreach(@selected){
		$_ =~ s/\s+//g;
		$selected{"$_.dta"} = 1;
	}
}


sub makeTable {

	my( $dtaListRef, $filename, $horizontalCategoriesref, $horizontalDistinguishingFunction, $verticalCategoriesref, $verticalDistinguishingFunction) = @_;
	my(@DTAfilenames) = @$dtaListRef;
	my(@horizontalCategories) = @$horizontalCategoriesref;
	my(@verticalCategories) = @$verticalCategoriesref;

	%intensity = &get_name_intensity_pairs if($content eq "TIC");

	# make a hash that tells you which column each horizontal category corresponds to. Index starting with zero.
	for($i=0; $i<scalar(@horizontalCategories); $i++){
		$column{$horizontalCategories[$i]} =  $i;
	}

	# do the same for the rows
	for($i=0; $i<scalar(@verticalCategories); $i++){
		$row{$verticalCategories[$i]} =  $i;
	}

	# now make a big tally, and put it in a big two dimensional array
	my($count,$total, $totalIntensity, $rowTotal, @RowTotals, @ColumnTotals, @intenRowTotals, @intenColumnTotals, $percent2);
	foreach(@DTAfilenames){
		if( $content eq "count"){
			unless( $use_selected and not exists($selected{$_}) ){
				$entry[$row{&$verticalDistinguishingFunction($_)}][$column{&$horizontalDistinguishingFunction($_)}] += 1;
			}
			$CellTotals[$row{&$verticalDistinguishingFunction($_)}][$column{&$horizontalDistinguishingFunction($_)}] += 1;
			$total++;
			$RowTotals[$row{&$verticalDistinguishingFunction($_)}] += 1;
			$ColumnTotals[$column{&$horizontalDistinguishingFunction($_)}] += 1;
		} elsif( $content eq "TIC"){
			unless( $use_selected and not exists($selected{$_}) ){
				$entry[$row{&$verticalDistinguishingFunction($_)}][$column{&$horizontalDistinguishingFunction($_)}] += $intensity{$_};
			}
			$CellTotals[$row{&$verticalDistinguishingFunction($_)}][$column{&$horizontalDistinguishingFunction($_)}] += $intensity{$_};
			$total += $intensity{$_};
			$RowTotals[$row{&$verticalDistinguishingFunction($_)}] += $intensity{$_};
			$ColumnTotals[$column{&$horizontalDistinguishingFunction($_)}] += $intensity{$_};
		}
	}

	print "<table cellspacing=0 cellpadding=9 border=1>";

	# print the top line of the summary stats grid
	print  "<tr><td><bold><span class=\"smallheading\">$content</span></bold></td>";	
	print "<td><span class=\"smallheading\" style=\"color:#FF0000\">Good (1)</span></td>";
	print "<td><span class=\"smallheading\" style=\"color:#00D0D0\">Medium (0)</span></td>";
	print "<td><span class=\"smallheading\" style=\"color:#0300DD\">Bad (-1)</span></td>";
	print "<td><span class=\"smallheading\">Total</span></td></tr>";


	for($i=0; $i<scalar(@verticalCategories); $i++){
		print "<tr><td><bold><span class=\"smallheading\">$verticalCategories[$i]+</span></bold></td>";
		$rowTotal = 0;
		$bgcolor = ( ($i == 0 or $i == 1) ? "" : "bgcolor = \"#e8e8e8\" ");
		for($j=0; $j<scalar(@horizontalCategories); $j++){
			
			#display the value
			unless ($entry[$i][$j]) {
				$entry[$i][$j] = 0;
			}
			$readable_data = ($content eq "TIC") ? &sci_notation($entry[$i][$j]) : $entry[$i][$j] ;
			print "<td $bgcolor><span class=\"smallheading\">$readable_data &nbsp&nbsp";
			$rowTotal += $entry[$i][$j];

			#now display the percent
			if($percentType eq "total"){
				$relevantTot = $total;
			}elsif($percentType eq "row"){
				$relevantTot = $RowTotals[$i];
			}elsif($percentType eq "column"){
				$relevantTot = $ColumnTotals[$j];
			}elsif($percentType eq "cell"){
				$relevantTot = $CellTotals[$i][$j];
			}
		
			$percent = $relevantTot ? &precision($entry[$i][$j]/$relevantTot,2) : 0;	#avoid division by zero
			$percent *= 100;
			print "($percent%)</span></td>";

		}
		$readable_rowTotal = ($content eq "TIC") ? &sci_notation($rowTotal) : $rowTotal ;
		print "<td><span class=\"smallheading\">$readable_rowTotal &nbsp&nbsp";
		$percent = $total ? &precision($rowTotal/$total,2) : 0;
		$percent *= 100;
		print "($percent%)</span></td></tr>";
	}

	print "</table>";
}

print <<EOFORM;	
<FORM NAME="Directory Select" ACTION="$ourname" METHOD="post">

<table>

<tr>
 <td align = "right"><span class="smallheading">Percent:&nbsp;&nbsp;</span>
 <td><input type=radio name="percent" value="total" $checked_total onClick="document.forms[0].submit()">total
 <td><input type=radio name="percent" value="row" $checked_row onClick="document.forms[0].submit()">row
 <td><input type=radio name="percent" value="column" $checked_column onClick="document.forms[0].submit()">column
 <td><input type=radio name="percent" value="cell" $checked_cell onClick="document.forms[0].submit()">cell

<tr> 
<td align = "right"><span class="smallheading">Show:&nbsp;&nbsp;</span>
<td><input type=radio name="content" value="count" $checked_count onClick="document.forms[0].submit()">count
<td><input type=radio name="content" value="TIC" $checked_TIC onClick="document.forms[0].submit()">TIC

</table>

<input type="hidden" name="directory" value="$dir">
<input type="hidden" name="selected" value="$selected">
<input type="hidden" name="content">
<input type="hidden" name="percent">
</FORM>
EOFORM


&makeTable(\@dtas,"gbu_summary.txt", [1, 0, -1], $rate_func, [1, 2, 3, 4, 5], \&get_charge_state);


#######################################
# Main form subroutines

# note that we're going to take the defaults from GBU, since these two scripts are so closely tied in to one another
sub choose_directory {
	print "<HR>\n";

	&get_alldirs;

	print <<EOFORM;

<FORM NAME="Directory Select" ACTION="$ourname" METHOD=get>
<TABLE BORDER=0 CELLSPACING=6 CELLPADDING=0>
<TR>
	<TD align=right><span class="smallheading">Directory:&nbsp;</span></TD>
	<TD>
	<span class=dropbox><SELECT NAME="directory">
EOFORM

	foreach $dir (@ordered_names) {
	      print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
	}

print <<DONE;

<TR><TD align=right><span class="smallheading">Cutoff for upper half:&nbsp;</span></TD>
	<TD>
	<input type="text" name="weakUpperHalfIonCountCutoff" size=3 maxlength=3 value=$DEFS_GOODBADUGLY{"Weak Upper Half Ion-Count"}>
	</TD>
<TR><TD>
	<TD><INPUT type="submit" class="button" value="Select">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/goodbadugly2.pl.html">Help</A></span></TD>
</TR></Table>


</Form></Body></HTML>

DONE
}


#######################################
# Error subroutine
# Informs user of various errors, mainly I/O

sub error {

	if($WEB_MODE){
		print <<ERRMESG;
	<HR><p>
	<H3>Error:</H3>
	<div>
	@_
	</div>
	</body></html>
ERRMESG
	}

	exit 1;
}


# End of view_gbu_stats