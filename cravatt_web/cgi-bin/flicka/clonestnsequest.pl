#!/usr/local/bin/perl

#-------------------------------------
#	Clone Cloner Clonest
#	(C)1999 Harvard University
#	
#	 W. S. Lane/P. McDonald
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------




################################################
# Created: 09/01/00 by Paul McDonald
# Last Modified: mm/dd/yy by Name of Modifier
#
# Description: What does this script do?  Briefly, how does it work?
#  Given a directory this script clones the directory and launches sequest with 
#  certain default arguments.  Used by runsummary.pl (could be used by other programs
#  in the future).
#



################################################
# find and read in standard include file
{
	$0 =~ m!(.*)\\([^\\]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}

require "stringlist_include.pl";   # For converting list of dtas to an array
require "clone_code.pl";           # For cloning the directory
require "seqstatus_include.pl";

###################################
##     These are the defaults    ##
###################################
$CloneExtension = "_est";   # &clonedir() will strip the _ for us, and it is useful here (for output and -d testing)
$Initials = "aut";          # Use these initials to indicate the sequest was launched automatically by this script
$SequestDatabase = "est.fasta.hdr";   # The database we want to run sequest with

&cgi_receive;
&MS_pages_header("Clone Cloner ClonEST","ff00ff");
$| = 1; # Kludge: Problem with clonedir printing copy file status into the header's javascript code
$| = 0; # Endo of kludge

print "<hr><p><div>";
$dir = $FORM{"directory"};        # Directory we are cloning and launching sequest on
$continue = $FORM{"continue"};    # Indicates if we've already asked about using an alternate dirname (with edition as suffix)
$edition = $FORM{"edition"};      # Append this to the directory name if one already exists
@dtafiles = map { $_ . ".dta" } ( split (", ", $FORM{"selected"}) );	# This line borrowed from Tim's code found elsewhere in the 
																		# runsummary family

if ($dir ne "") {  # Must have some input 
#	print "Directory is <b>$dir</b><br>";
#	if (-d "$seqdir/$dir") {
#		print "directory located <br>";
#	} else {
#		print "directory not found <br>";
#	}
	if (-d "$seqdir/$dir$CloneExtension" && !$continue) {
		print "Clone target $seqdir/$dir$CloneExtension already exists.<br>";
		&ask_about_name("$dir$CloneExtension");
	} else {
		if ($continue) {
			$CloneExtension .= $edition;
		}
		#print "Clone target is $seqdir/$dir$CloneExtension<br>";
	}
#	print "No functionality is available yet";
} else {
	print "This program is only for use in conjunction with <a href=$webcgi/runsummary.pl> Sequest Summary </a> <br>";
	exit;
}

### Clone Dir Code ####
$| = 1;

print qq(<p><img src="$webimagedir/circle_1.gif"> Cloning directory <b>$dir</b>.  Clone target is <b>$dir$CloneExtension</b>...);

($newdir, @retval) = &clonedir ($dir, $CloneExtension, \@dtafiles, 0, $Initials, $Comments);

if ((shift @retval) != 0) { # error
	&error (@retval);
}

print qq(<b>done</b>.</p>);
print qq(<p><img src="$webimagedir/circle_2.gif"> Launching Sequest on $clonest_server);

$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("runOnServer" => "$clonest_server", "Database" => "est.fasta.hdr", "Enzyme" => "1", "Q_immunity" => "1", "directory" => $newdir, "running" => 1, "default" => "$seqdir/$newdir/sequest.params", "operator" => $Initials);
$procobj = &run_in_background("$seqlaunch_cmdline USE_QUERY_STRING_INTRACHEM");

if (!$procobj) {
	print "...failed to launch Sequest.";
	exit;
}

my $dir_encoded = &url_encode("$newdir");

sleep 2;

my $foundrunning=0,$numdots=0,$iterations=0,$distribute_using_defaults=1;
my @seqs;
do {
	print ".";
	if (++$numdots > 80) {
		print "<br>";
		$numdots=0;
	}
	@seqs = &read_status;
	foreach my $proc (@seqs) {
		if ($dirpath{$proc} eq $newdir) {
			$foundrunning=1;
		}
	}
	sleep 1;
	$iterations++;
} until ($foundrunning or $iterations > 120);

print qq(</p>);

if ($iterations > 90) {
	print "<p>Sequest run on $clonest_server not detected after two minutes, will not auto-distribute.</p>";
	$distribute_using_defaults = 0;
} else {
	print qq(<p><img src="$webimagedir/circle_3.gif"> Distributing Sequest run...</p>);
}

print <<REDIRECT;
</div>
<script language="Javascript">
<!--
	function goto_distributor()
	{
		location.replace("$seqdistributor?run_dir=$dir_encoded&distribute_using_defaults=$distribute_using_defaults");
	}
	onload=goto_distributor;
//-->
</script>
</body></html>
REDIRECT
exit 0;



#######################################
# subroutines (other than &output_form and &error, see below)

sub ask_about_name {
	my $dirname = shift;
	my $edition = "2";

	while (-d "$seqdir/$dirname$edition") {
		$edition++;
	}

	print <<ASK;
	The directory <b>$dirname</b> <span style="color:red">already exists</span>, Do you want to create <b>$dirname$edition</b> and continue? <br>
	<form action=$ourname method=get>
	<input type=hidden name=directory value="$dir">
	<input type=hidden name=continue value="yes">
	<input type=hidden name=edition value="$edition">
	<input type=submit class=button style="background:ff00ff" value="Yes, please continue">&nbsp;&nbsp;&nbsp;&nbsp;<input type=button class=button value="No, cancel" onClick="javascript:window.close()">
	</form>
	
ASK
	exit;
}



#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {

	$msg = join "<br>", @_;

	print "Error: $msg";
	exit 1;
}
