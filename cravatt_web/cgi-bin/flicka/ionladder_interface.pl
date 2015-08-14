#!/usr/local/bin/perl
#-------------------------------------
#	Ionladder Interface (copied from View Info)
#	(C)1999 Harvard University
#	
#	W. S. Lane/C. M. Wendl/M.S.C. Hemond
#
#	v3.1aa
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
# this section sets relevant program defaults
$default_filename = "ionladder.dta";
$default_charge_state = 1;
$program_name = "$cgidir/ionladder.pl";			# this is the filename that the interface calls

# this section reads user input data from the page and sets defaults if none is found
&cgi_receive();
$dir = $FORM{"directory"};

$charge_state = $FORM{"charge_state"};
$charge_state = $default_charge_state unless (defined $charge_state);

$MHplus = $FORM{"charge_state"};

$filename = $FORM{"filename"};
$filename = $default_filename unless (defined $filename);

$sequence = $FORM{"sequence"};

push @ion_series, 'a' if $FORM{'a_ions'};
push @ion_series, 'b' if $FORM{'b_ions'};
push @ion_series, 'y' if $FORM{'y_ions'};



# print the page header in microchem style
&MS_pages_header("Ionladder", "888888", $nocache, $refresh_tag);
print "<HR><div>\n";


# if there was no directory or no sequence defined, simply print out the interface page and exit
&output_form unless (defined $dir);


# check for a few common errors
if (not defined $sequence)
{
	print "<B>You must enter a sequence in the sequence field</B><BR><BR>\n";
	&output_form;
}

# call ionladder.pl with the user's information
$command_line .= " -S$sequence";

if (defined $filename) { $command_line .= " -F$seqdir/$dir/$filename" }
if (defined $charge_state ) { $command_line .= " -C$charge_state" }

# add the program name to the beginning of the command line
$command_line = "perl $program_name $command_line";

# filter the command line for security reasons, removing all non-alphanumeric characters
$command_line =~ s/[^A-Za-z0-9 \-\+\/\\:\._]//g;
# alternatively, $command_line =~ tr/[A-Za-z0-9 \-\+\/\\:\._]//cd;, right?

# print the command line for the user's knowledge
print "<B>Command line:</B><BR>\n$command_line<BR>\n";

# run the command line
print qx($command_line);

# create a link to the output file
print "Output file: <A HREF=\"$filename\">$filename</A> in directory $seqdir/$dir<BR>\n";

exit;


#########################################################################
# Prepares array @liner to contain formatted header

@lineb = @liner = ();
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

print "<span class=\"smallheading\">Sequest: &nbsp &nbsp</span><span style=\"color:#FF0000\"><b>" . join(" &nbsp; &nbsp; &nbsp; ", @lineb ) . "</b></span> &nbsp; &nbsp; &nbsp;" . join(" &nbsp; &nbsp; &nbsp; ", @liner ) . "\n";


#########################################################################
# Print Comments 

$comments = $entry{"comments"};
$comments =~ s/<COLON>/:/g;

if ($comments) {
	$comments =~ s/cloned<\/I><BR>/<span style="color:#0000ff">cloned: <\/span><\/I>/g;
	$comments =~ s/renamed<\/I><BR>/<span style="color:#00aa00">renamed: <\/span><\/I>/g;
	print "<p><span class=\"smallheading\">Comments: &nbsp</span>\n$comments\n";
} else {
	print "<H5>No comments.</H5>\n";
}

#########################################################################
# Prints Links

$delloglink = "<A HREF=\"$webseqdir/$dir/$dir" . "_deletions_log.html\"><img border=0  align=top src=\"$webimagedir/p_deletions_log.gif\"></a> &nbsp &nbsp &nbsp" if (-e ("$seqdir/$dir/$dir" . "_deletions_log.html"));

print <<EOF;
	<p>
	<A HREF="$webseqdir/$dir" SIZE=+1><img border=0  align=top src="$webimagedir/p_view_directory.gif"></A> &nbsp &nbsp &nbsp
	<A HREF="$webseqdir/$dir/sequest.params"><img border=0  align=top src="$webimagedir/p_sequest_params.gif"></A> &nbsp &nbsp &nbsp 
	<A HREF="$inspector?directory=$dir"><img border=0  align=top src="$webimagedir/p_inspector.gif"></A> &nbsp &nbsp &nbsp
	<A HREF="$webcgi/edit_seqcomments.pl?directory=$dir"><img border=0  align=top src="$webimagedir/p_edit_comments.gif"></A> &nbsp &nbsp &nbsp
	$delloglink
	<A HREF="$createsummary?directory=$dir&sort=consensus"><img border=0 align=top src="$webimagedir/p_sequest_summary.gif"></A>
	</p>
EOF


#########################################################################
# Prints Reports: link to all Folgesucheberichte

opendir(OURDIR,"$seqdir/$dir");
@berichte = grep /bericht.*\.html/i, readdir(OURDIR);
closedir OURDIR;

if (@berichte[0] ne "") {print "<br><br><span class=\"smallheading\">Reports: </span><br>"};
foreach $bericht (@berichte) {
	print "<A HREF=\"$webseqdir/$dir/$bericht\">$bericht</A><br>\n";
}


open(LOG,"<$seqdir/$dir/$dir.log");
@loglines = <LOG>;
close(LOG);

print "<span class=\"smallheading\">Log File:</span><BR><div class=smalltext>" . join("<br>",@loglines) . "</div>\n";
print "</div></BODY></HTML>\n";


exit;












###############################################################
# This sub prints the default page

sub output_form {
	print "<B>DO NOT USE THIS PAGE.  IT DOES NOT WORK.<BR>\n";

	print "<FORM ACTION=\"$ourname\" METHOD=get>";

	# get the directories to put in the dropdown
	&get_alldirs;

	# print the dropdown box
	print "<B>Write to directory:</B>&nbsp;\n";
	print "<span class=dropbox><SELECT name=\"directory\">\n";
	foreach $dir (@ordered_names) {
		print qq(<option value="$dir">$fancyname{$dir}\n);
	}
	print "</select></span><BR>\n";
	
	# print the sequence text box
	# this sends a {name, value} pair with name="sequence" and value equal to whatever the user types in
	print "Sequence:&nbsp;<input type=text width=10 maxlength=30 name=\"sequence\" value=\"\"><BR>\n";

	# print the charge state dropdown
	# this sends a {name, value} pair with name="charge_state" and value = 1, 2, 3, 4, or 5
	print "Charge&nbsp;state:";
	print "<span class=dropbox><SELECT name=\"charge_state\">\n";
	foreach(1..5) { print "<option value=\"$_\">$_\n" }
	print "</select></span><BR>\n";

	# print the MH+ input text box
	print "MH+:&nbsp;<input type=text width=7 maxlength=10 name=\"MHplus\"><BR>\n";

	# print the filename text box
	print "Filename:&nbsp;<input type=text width=20 maxlength=40 name=\"filename\"><BR>\n";

	# print the ion series checkboxes
	print "Ion&nbsp;series:&nbsp;\n";
	print "<B>a</B><input type=checkbox name=\"a_ions\" value=\"true\" $checked{'a_ions'}>\n";
	print "<B>b</B><input type=checkbox name=\"b_ions\" value=\"true\" $checked{'b_ions'}>\n";
	print "<B>y</B><input type=checkbox name=\"y_ions\" value=\"true\" $checked{'y_ions'}>\n";

	# print the submit button
	print '<input type=submit class=button value="Create"><BR>';

	print "</form></body></html>\n";
	exit 0;
}



