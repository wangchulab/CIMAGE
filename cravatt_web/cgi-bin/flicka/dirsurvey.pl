#!/usr/local/bin/perl

#-------------------------------------
#	Dir Survey,
#	(C)1997-2000 Harvard University
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
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
&cgi_receive;

if ($FORM{"recent"}) {
	&dirsurvey;
} else {
	&output_form;
}

exit 0;



sub dirsurvey
{  

	## a script to survey all Sequest directories and find out which are not finished
	##

	# only look at directories modified within last $HOWRECENT days
	$HOWRECENT = $FORM{"recent"};
	&error("Dir Survey expects a number as input.") if ($HOWRECENT =~ /[^\d\. ]/);

	&MS_pages_header ("Sequest Dir Survey", "#156ACE");
	print "<P><HR><P>\n";

	print "<H4>Sequest directories modified within the last ".(($HOWRECENT==1) ? "day" : "$HOWRECENT days")."</H4>\n";

	&get_alldirs;
	@recentDirs = ();

	# produce list of all directories modified in last $HOWRECENT days
	foreach $dir (@alldirs)
	{
		$LastModified = -M "$seqdir/$dir";
		if ($LastModified < $HOWRECENT) {
			push(@recentDirs, $dir);
		}
	}

	# store vital info for each recent directory in hashes
	%outs = ();
	%dtas = ();
	%mostrecent = ();
	%onhost = ();

	foreach $dir (@recentDirs)
	{
		opendir (DIR, "$seqdir/$dir");
		@interesting = grep { /\.(dta|out)$/ } readdir(DIR);
		closedir DIR;

		@maybeouts = grep { /\.out$/ } @interesting;			# some of these may be 0-byte files

		# construct @outs, which is just @maybeouts, free of 0-byte files
		@outs = ();
		foreach (@maybeouts) {
			push(@outs,$_) if (-s "$seqdir/$dir/$_");
		}

		$outs{$dir} = @outs;
		$dtas{$dir} = $#interesting + 1 - $outs{$dir};

		# find time of most recent .outfile
		$mostrecent = 3650; # assume by default that nothing's over 10 years old
		foreach (@outs)
		{
			$recent = (-M "$seqdir/$dir/$_");
			if ($recent < $mostrecent)
			{
				$mostrecent = $recent;
				$mostrecentOut = $_;
			}
		}
		$mostrecent{$dir} = $mostrecent;

		# find host on which most recent Out was produced (and database)
		open (FILE, "$seqdir/$dir/$mostrecentOut");
		while (<FILE>) {
			# scan until we get a line of the appropriate format
			if (m!../../.., \d+:.. .., .* on (\S+)!) {		# SequestC1 format
				$onhost{$dir} = $1;
			}
			if (m!../../...., \d+:.. .., .* on (\S+)!) {
				$onhost{$dir} = $1;
			}
			next unless (/[\/\\]([^\s\/\\]+)\.fasta([^\w\-\.]|$)/i);
			$db{$dir} = $1;
			last;
		}
		close FILE;  

	}			

	print "<TABLE>\n";
	print "<TR><TH>Directory </TH><TH>DTAs </TH><TH>OUTs </TH><TH>Most Recent OutFile </TH><TH> Database </TH><TH> Host </TH><TH>Setup Date </TH></TR>\n";

	# output info on each recent directory, sorted by most recent .outFiles
	foreach $dir (sort { $mostrecent{$a} <=> $mostrecent{$b} } @recentDirs)
	{
		if ($outs{$dir} < $dtas{$dir}) {
			$bold = "";
			$endbold = "";
		}
		else {
			$bold = "<B>";
			$endbold = "</B>";
		}

		($yearstamp, $monstamp, $daystamp) = $datestamp{$dir} =~ /\d\d(\d\d)_(\d+)_(\d+)/;
		$SetupDate = sprintf("%2.2d/%2.2d/%2.2d", $monstamp, $daystamp, $yearstamp);

		$LastOut = &LastModTime($mostrecent{$dir});
		$LastOut = "-"x4 unless ($outs{$dir});

		print <<TABLEENTRY;
<TR>
<TD><A HREF="$inspector?directory=$dir">
$fancyname{$dir}</A></TD>
<TD ALIGN=center>$bold$dtas{$dir}$endbold</TD>
<TD ALIGN=center>$bold$outs{$dir}$endbold</TD>
<TD ALIGN=center>$LastOut</TD>
<TD ALIGN=center>$db{$dir}</TD>
<TD ALIGN=center>$onhost{$dir}</TD>
<TD ALIGN=center>$SetupDate</TD>
</TR>
TABLEENTRY
	}
	print "</TABLE>\n";
	print "</BODY></HTML>\n";
}


# returns date and time in form "mm/dd/yy, hh:mm [AP]M", given a decimal
# number of days before the script was started running
sub LastModTime
{
    $secsbefore = $_[0] * 24 * 60 * 60;
    $moment = $^T - $secsbefore;

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($moment);
    $mon += 1;
    if ($hour >= 12) {
	$hour -= 12;
	$APM = "PM"
	}
    else {
	$APM = "AM"
	}
    $hour =+ 12 if ($hour == 0);  # switch 0-11 scale to 1-12 scale
    $timestring = sprintf("%2.2d/%2.2d/%2.2d, %2.2d:%2.2d %s",$mon,$mday,$year,$hour,$min,$APM);
    return $timestring;
}



sub output_form
{
	&MS_pages_header ("Sequest Dir Survey", "#156ACE");
	print "<P><HR><P>\n";

	print <<EOFORM;

<div>
<FORM NAME="dirsurvey" ACTION="$ourname" METHOD="get">
<H4>Dir Survey:</H4>
Survey Sequest directories modified in the last <INPUT NAME="recent" SIZE=2 MAXLENGTH=3 VALUE="$DEFS_DIRSURVEY{'how recent'}"> days.&nbsp;
<INPUT TYPE=submit CLASS=button VALUE="Continue">
</FORM>
</div>

EOFORM

	print "</CENTER>\n";
	print "</body></html>";
}

sub error
{
	&MS_pages_header ("Sequest Dir Survey", "#156ACE");

    print "<p>Error: $_[0]<P>\n";
    print "</BODY></HTML>";
    exit 1;
}

