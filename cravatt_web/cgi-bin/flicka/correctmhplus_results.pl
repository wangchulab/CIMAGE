#!/usr/local/bin/perl

#-------------------------------------
#	View CSD results,
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
# Description: Displays the Charge State Determination logfile of a directory
#



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
	require "microchem_form_defaults.pl";
}



#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$dir = $FORM{"directory"};

&MS_pages_header("CorrectIon Results","#871F78");
print "<hr><p>";

if( not defined $dir){
	&choose_directory;
}else{
	&javastuff;
	&main;
}


sub main{
	
	if( -e "$seqdir/$dir/$MHPLUS_TABLE_FILE"){
		open OUTPUT, "$seqdir/$dir/$MHPLUS_TABLE_FILE" or die "Cannot open $seqdir/$dir/$MHPLUS_TABLE_FILE<br>";
		while (<OUTPUT>) {
			print "$_";
		}
		close OUTPUT;
	}else{
		print "<span class='smallheading'>CorrectIon has not been run on this directory<br><br><br>";
		print "<a href='$webcgi/correctmhplus.pl'>Would you like to run it?</a></span>";
	}
}



sub choose_directory {

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

<TR><TD>
	<TD><INPUT type="submit" class="button" value="Select">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"></span></TD>
</TR></Table>
</Form></Body></HTML>

DONE
}

sub javastuff{

	print <<EOF;
<SCRIPT LANGUAGE="Javascript">
<!--

function toggleGroupDisplay(toggleButton)
{
	var groupSpanId = toggleButton.id + "_";
	var groupSpan = document.getElementById(groupSpanId);

	if (groupSpan.style.display=="none") {
		toggleButton.src = "/images/tree_open.gif";
		groupSpan.style.display = "";
	} else {
		toggleButton.src = "/images/tree_closed.gif";
		groupSpan.style.display = "none";
	}
}


//-->
</SCRIPT>
EOF
}



