#!/usr/local/bin/perl

#-------------------------------------
#	View Support Files (viewsupportfiles.pl)
#	(C)1999 Harvard University
#	
#	Vanko Vankov/W. S. Lane/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
#########################################################################

&MS_pages_header("View Support Files", "BB8888");
print "<HR><P>\n";

&cgi_receive();
$dir = $FORM{"directory"};
$rfile = $FORM{"reqfile"};
if (!(defined $dir)) {
	&output_form;
	# end of file and exit:
	print "</FORM></BODY></HTML>\n";
	exit;
}

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
foreach $name (@names) {
	unless ((lc($name) eq "comments") || (lc($name) eq "directory")) {
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

print "<span class=\"smallheading\">Sequest: &nbsp &nbsp</span><span style=\"color:#FF0000\"><b>" . join(" &nbsp; &nbsp; &nbsp; ", @lineb ) . "</b></span> &nbsp; &nbsp; &nbsp;" . join(" &nbsp; &nbsp; &nbsp; ", @liner ) . "\n";

#########################################################################
# Prints Links
$delloglink = "<A HREF=\"$webseqdir/$dir/$dir" . "_deletions_log.html\"><img border=0  align=top src=\"$webimagedir/p_deletions_log.gif\"></a><p>" if (-e ("$seqdir/$dir/$dir" . "_deletions_log.html"));
print <<EOF;
	<p><A HREF="$webseqdir/$dir" SIZE=+1><img border=0  align=top src="$webimagedir/p_view_directory.gif"></A> &nbsp &nbsp &nbsp
	<A HREF="$webseqdir/$dir/sequest.params"><img border=0  align=top src="$webimagedir/p_sequest_params.gif"></A> &nbsp &nbsp &nbsp 
	<A HREF="$inspector?directory=$dir"><img border=0  align=top src="$webimagedir/p_inspector.gif"></A> &nbsp &nbsp &nbsp
	<A HREF="$webcgi/edit_seqcomments.pl?directory=$dir"><img border=0  align=top src="$webimagedir/p_edit_comments.gif"></A> &nbsp &nbsp &nbsp
	$delloglink
EOF

if ($rfile eq "lcq_profile.txt") {&view_lcq_profile;}
if ($rfile ne "lcq_profile.txt") {&view_file ($rfile);}

print "</BODY></HTML>\n";
exit;

###########################################################################
# Loads and displays file specified in the argument.
# Called to display all files except lcq_profile.txt 
#
sub view_file {
	my $loadfile = $_[0];
	my $nxtline;
	my @file_contents;

	# load requested file: 
	if (!open(RFILE, "<$seqdir/$dir/$loadfile")) {
		print "<H4 style=\"color:#800000\">The file $seqdir/$dir/$loadfile is either inaccessible or does not exist.</H4>";
		return;
	}
	@file_contents = <RFILE>;
	close(RFILE);
	
	#print "<BR>\n";
	print "<P><b>Contents of $loadfile:</b></P>\n";
	foreach $nxtline (@file_contents) {
		print "<TT>$nxtline<\TT><BR>";
	}
}

###################################################################################
# Called without arguments to display lcq_profile.txt
# To display any other file, call &view_file 
#

sub view_lcq_profile {
	# load file lcq_profile.txt.  If it can't be opened, display error message and return.
	if (!open(LCQ_PROFILE, "<$seqdir/$dir/lcq_profile.txt")) {
		print "<H4 style=\"color:#800000\">The file $seqdir/$dir/lcq_profile.txt is either inaccessible or does not exist.</H4>";
		return;		
	}
	my @lcq_profile_lines = <LCQ_PROFILE>;
	close(LCQ_PROFILE);

	print "<P><b>Contents of lcq profile:</b></P>\n";

	print "<TABLE WIDTH=80% BORDER=0 CELLSPACING=0 CELLPADDING=0>\n";
	my $line;
	my $lcount = 0;
	foreach $line (@lcq_profile_lines) {
		chop $line;
		my @words_in_line = split(/ +/, $line);
		my $word;
		my $wcount = 0;
		print "<TR ALIGN=LEFT>\n";
		foreach $word (@words_in_line) {
			if ($lcount == 0) {
				print "<TD><TT><B>$word&nbsp;&nbsp;</B></TT></TD>\n";
			} else {
				if ($wcount == 0) {
					print "<TD><TT>$word&nbsp;&nbsp;</TT></TD>\n";
				} else {
					my $sci_nttn = &sci_notation($word);
					print "<TD><TT>$sci_nttn&nbsp;&nbsp;</TT></TD>\n";
				}
			}
			$wcount++;
		}
		print "</TR>\n";
		$lcount++;
	}
	print "</TABLE>\n";
}


##########################################################################
# outputs_form displayes the pulldown directory menu and the radio
# buttons that let you specify which file you want to view in the given
# sequest directory

sub output_form {

# output pulldown form on the left side:
print <<EOF;
<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
<TR VALIGN=TOP><TD>
EOF

	print "<FORM ACTION=\"$ourname\" METHOD=get>";
	&get_alldirs;

	print "<span class=dropbox><SELECT name=\"directory\">\n";
	foreach $dir (@ordered_names) {
		print qq(<option value="$dir">$fancyname{$dir}\n);
	}
	print "</SELECT></span>\n";

	print '<INPUT TYPE=SUBMIT CLASS=button VALUE="View">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
	print "</TD>\n";	
	# display radio buttons:

print <<EOF;

<TD>
	<B> Select file to view: </B><BR>
	<INPUT TYPE=RADIO NAME="reqfile" VALUE="lcq_profile.txt" CHECKED>lcq_profile.txt<BR>
	<INPUT TYPE=RADIO NAME="reqfile" VALUE="lcq_dta.exclude">lcq_dta.exclude<BR>		
	<INPUT TYPE=RADIO NAME="reqfile" VALUE="lcq_dta.txt">lcq_dta.txt<BR>
	<INPUT TYPE=RADIO NAME="reqfile" VALUE="lcq_zta_list.txt">lcq_zta_list.txt<BR>		
</TD>
</TR>
</TABLE>
EOF
}