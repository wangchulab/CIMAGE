#!/usr/local/bin/perl
#-------------------------------------
#	View Info (formerly View Header),
#	(C)1998 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# find and read in standard include file
{
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
#########################################################################
## originally a short script to read/parse Header.txt for a certain directory,
## but it's become more than that since then

&cgi_receive();
$dir = $FORM{"directory"};
$refresh = $FORM{"refresh"};
$refresh_tag = ($refresh) ? &refresh_page($refresh): "";


#&MS_pages_header("View Info", "888888", $nocache, $refresh_tag);
#print "<P><HR>";

&output_form unless (defined $dir);
$delloglink = "$webseqdir/$dir/$dir" . "_deletions_log.html"  if (-e ("$seqdir/$dir/$dir" . "_deletions_log.html"));

	&MS_pages_header ("View Info", "#888888","tabvalues = View Info&View Info:\"/cgi-bin/view_info.pl\"&Edit Comments:\"$webcgi/edit_seqcomments.pl?directory=$dir\"&Sequest Summary:\"$createsummary?directory=$dir\"&Sequest Params:\"$webseqdir/$dir/sequest.params\"&Inspector:\"$inspector?directory=$dir\"&View Directory:\"$webseqdir/$dir\"&Deletions Log:\"$delloglink\"&ZSA:\"$webcgi/chargestate_results.pl?directory=$dir\"");

print "<div>\n";
print "This page will refresh every $refresh seconds.<p>\n" if ($refresh);

unless (%entry = &get_dir_attribs($dir)) {
	print <<EOF;
	<H4 style="color:#800000">Unable to find directory information in either Header.txt or $SAMPLELIST.</H4>
	</div></body></html>
EOF
	exit;
}

#########################################################################
# Prepares array @liner to contain formatted header

@lineb = @liner = ();
@names = split /:/, $samplelist_firstline;
foreach $name (@names)
{
	unless ((lc($name) eq "comments") || (lc($name) eq "directory"))
	{
		if ($entry{$name} ne "") {
			push(@liner,"$entry{$name}");
		}
	}
}


@liner[1]=$liner[1]. ", " . $liner[0] . ".";
@lineb = ($liner[1], $liner[2]);
shift (@liner); 
shift (@liner); 
shift (@liner);
$liner[1] =~ s/_/-/g;

print "<br><span class=\"smallheading\">Sequest: &nbsp &nbsp</span><span style=\"color:#FF0000\"><b>" . join(" &nbsp; &nbsp; &nbsp; ", @lineb ) . "</b></span> &nbsp; &nbsp; &nbsp;" . join(" &nbsp; &nbsp; &nbsp; ", @liner ) . "\n";


#########################################################################
# Print Comments 

$comments = $entry{"Comments"};
$comments = &unencode_comments($comments);

if ($comments) {
	$comments =~ s/cloned<\/I><BR>/<span style="color:#0000ff">cloned: <\/span><\/I>/g;
	$comments =~ s/renamed<\/I><BR>/<span style="color:#00aa00">renamed: <\/span><\/I>/g;
	$comments =~ s/Directory1/<span style="color:#00aa00"><BR>Directory1 <\/span><\/I>/g;
	$comments =~ s/Directory2/<span style="color:#00aa00">Directory2 <\/span><\/I>/g;
	$comments =~ s/New Directory/<span style="color:#00aa00">New Directory <\/span><\/I>/g;
	print "<div><p><span class=\"smallheading\">Comments: &nbsp</span>\n$comments\n</div>";
} else {
	print "<H5>No comments.</H5>\n";
}

#########################################################################
# Prints Links

#$delloglink = "<A HREF=\"$webseqdir/$dir/$dir" . "_deletions_log.html\"><img border=0  align=top src=\"$webimagedir/p_deletions_log.gif\"></a> &nbsp &nbsp &nbsp" if (-e ("$seqdir/$dir/$dir" . "_deletions_log.html"));

#print <<EOF;
	#<p>
	#<A HREF="$webseqdir/$dir" SIZE=+1><img border=0  align=top src="$webimagedir/p_view_directory.gif"></A> &nbsp &nbsp &nbsp
	#<A HREF="$webseqdir/$dir/sequest.params"><img border=0  align=top src="$webimagedir/p_sequest_params.gif"></A> &nbsp &nbsp &nbsp 
	#<A HREF="$inspector?directory=$dir"><img border=0  align=top src="$webimagedir/p_inspector.gif"></A> &nbsp &nbsp &nbsp
	#<A HREF="$webcgi/edit_seqcomments.pl?directory=$dir"><img border=0  align=top src="$webimagedir/p_edit_comments.gif"></A> &nbsp &nbsp &nbsp
	#$delloglink
	#<A HREF="$createsummary?directory=$dir&sort=consensus"><img border=0 align=top src="$webimagedir/p_sequest_summary.gif"></A>
	#</p>
#EOF


#########################################################################
# Prints Reports: link to all Folgesucheberichte

opendir(OURDIR,"$seqdir/$dir");

my @listfiles = readdir(OURDIR);
@xmlreport = grep /report_.*\.xml/i, @listfiles;  # Relies that XML Reports have the _, and Protein Reports do not
@berichte = grep /bericht.*\.html/i, @listfiles;
push @berichte, @xmlreport;

closedir OURDIR;

if (@berichte[0] ne "") {print "<br><span class=\"smallheading\">Reports: </span><br>"};
foreach $bericht (@berichte) {
	print "<A HREF=\"$webseqdir/$dir/$bericht\">$bericht</A>\n";
	if ($bericht =~ m/(.*)\.xml$/) {
		print "&nbsp;&nbsp;&nbsp;<A HREF=\"$webcgi/convertXML.pl?xmlbericht=$bericht&seqdir=$dir\" target=\"_blank\">Convert to CSV</A>";
		my $csvname = "$1.csv";
		print "&nbsp;&nbsp;&nbsp;<A HREF=\"mailto:?Subject=\\\\$webserver\\sequest\\$dir\\$csvname\" target=\"_blank\">Email Report</a>";
	}
	print "<BR>";
}


open(LOG,"<$seqdir/$dir/$dir.log");
@loglines = <LOG>;
close(LOG);

my $loglines = join("<br>",@loglines);

my $deletionlink = qq(<a href="$webseqdir/$dir/${dir}_deletions_log.html" target="_blank" title="View log">);
$loglines =~ s#(deletion\d)#$deletionlink\1</a>#gi;
my $csdlink = qq(<a href="$webcgi/chargestate_results.pl?directory=$dir" target="_blank" title="View results">);
$loglines =~ s#(charge state determination)#$csdlink\1</a>#gi;
my $dtacombinerlink = qq(<a href="$webseqdir/$dir/dtacombiner.txt" target="_blank" title="View results">);
$loglines =~ s#(dta combiner)#$dtacombinerlink\1</a>#gi;
$loglines =~ s#(CombIon)#$dtacombinerlink\1</a>#gi;
my $mhpluslink = qq(<a href="$webcgi/correctmhplus_results.pl?directory=$dir" target="_blank" title="View results">);
$loglines =~ s#(mh\+ correction)#$mhpluslink\1</a>#gi;
$loglines =~ s#(CorrectIon)#$mhpluslink\1</a>#gi;
my $finalscorelink = qq(<a href="$webseqdir/$dir/seq_score_combiner.txt" target="_blank" title="View results">);
$loglines =~ s#(final score)#$finalscorelink\1</a>#gi;
my $sigcallink = qq(<a href="$webseqdir/$dir/probability.txt" target="_blank" title="View results">);
$loglines =~ s#(significance calculation)#$sigcallink\1</a>#gi;

print <<EOF;
<br><span class="smallheading">
Log File:
</span><br>
<span class="smalltext">
<nobr>
$loglines
</nobr>
</span>
</body>
</html>


EOF

#print "<span class=\"smallheading\"><br>Log File:</span><BR><div class=smalltext>" . join("<br>",@loglines) . "</div>\n";
#print "</div></BODY></HTML>\n";

exit;

sub output_form {
    
	&MS_pages_header("View Info", "888888", $nocache, $refresh_tag);
	print "<HR><div>\n";
	print "<FORM ACTION=\"$ourname\" METHOD=get>";

	&get_alldirs;
	print qq(<span class="smallheading">Choose a directory:</span><br>);
	print "<span class=dropbox><SELECT name=\"directory\">\n";
	foreach $dir (@ordered_names) {
		print qq(<option value="$dir">$fancyname{$dir}\n);
	}
	print "</select></span>\n";

	print '<input type=submit class=button value="View">';

	print "</form></body></html>\n";
	exit 0;
}
