#!/usr/local/bin/perl
#-------------------------------------
#	Sequence Dir Backup,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#       C. M. Wendl/T. Kim
#
#	v3.1a
#	
#	
#
#	licensed to Finnigan
#
#       2/27/98 T.Kim added database descriptor line
#		9/26/99 W.Lane changed to alternative archiving path
#		4/10/00 D.Sagalovskiy cleaned up a bit and added flatfile updating
#		6/23/00	G.Matev added lines for proper refreshing of Lcq Tracker window after unzipping from there
#		11/06/01 A. Chang - modified the output to include WhatDoYou menu
#-------------------------------------


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
################################################

require "dirzip_include.pl";
require "flatfile_lib.pl";

$SelectionBound = 30;		## upper bound on how many dirs can be selected and unzipped at one time

&cgi_receive();


$sorttype = $FORM{"sorttype"};
my $zipfiles = $FORM{"zipfiles"};
my @zipFileArr = split(',\s*', $zipfiles);

my @existdirs;
my @nonexistdirs;

foreach $file (@zipFileArr) {
	($dir = $file) =~ s/\.zip$//;
	if (-d "$seqdir/$dir") {
		push @existdirs, $file;
	}
	else {
		push @nonexistdirs, $file;
	}
}

if ($FORM{"zipfiles"} eq "") {
	&output_form();
}
else {
	if (!defined @existdirs) {
		&unzip(@zipFileArr);
	}
	else {
		if ($FORM{"confirmed"} && $FORM{"unzipexist"}) {
			&unzip(@zipFileArr);
		} elsif ($FORM{"confirmed"} && !$FORM{"unzipexist"}) {
			&unzip(@nonexistdirs);
		} else {
			&confirm();
		}
	}
}


#if($FORM{"zipfiles"} ne "" && $FORM{"confirmed"}) {
#	if ($FORM{"nonexistdir"}) {
#		&unzip(@zipFileArr);
#	}
#	else {
#		&unzip(@existdirs);
#	}
#} elsif($FORM{"zipfiles"} ne "") {
#	&confirm();
#} else {
#	&output_form();
#}
exit;



sub output_form {

	my (@alldirzips, $zip);
	&MS_pages_header ("Unzipadee-Do-Dir", "#6A5026", "tabvalues=Unzip&Zip:\"/cgi-bin/dir_zip.pl\"&Unzip:\"/cgi-bin/dir_unzip.pl\"");
	
	if(! defined $sorttype){
		$sorttype=1;
	}
	
	$name = "CHECKED" if ($sorttype == 1);
	$date =  "CHECKED" if ($sorttype == 0);
	print <<EOM;

<SCRIPT language="JavaScript">
function checkSelectionBound()
{
	var i, count = 0;
	var options = document.forms[0].zipfiles.options;

	// count up selected options
	for(i = 0; i < options.length; i++) {
		if(options[i].selected) {
			count++;
			if(count > $SelectionBound) {
				alert("Maximum of $SelectionBound directories may be selected.");
				return false;
			}
		}
	}
	return true;
}

function onsort(){

	document.all.unzipform.submit();
}
</SCRIPT>

EOM

	print <<EOM;

<FORM name=unzipform ACTION="$ourname" METHOD=GET onSubmit="javascript: return checkSelectionBound();">
<span class=smallheading>Select archived directory(ies) to restore:</span>
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<span class=smallheading>Sort:</span>
<input type=radio name=sorttype value=1 $name onClick="javascript:onsort()" ><span class=smallheading>By Name</span>&nbsp;&nbsp;
<input type=radio name=sorttype value=0 $date onClick="javascript:onsort()"><span class=smallheading>By Date</span><br>

<span class=dropbox>
<SELECT name="zipfiles" multiple size=20>
EOM
 
    opendir (SEQDIR, "$seqdir/$seqzip") || die ("can't open $seqdir/$seqzip: $!");
    @alldirzips = grep /\.zip$/, readdir (SEQDIR);
    closedir SEQDIR;
	$total = 30;
	
	
	foreach $zip (@alldirzips) {
		$moddate{$zip} = ((stat ("$seqdir/$seqzip/$zip"))[9]); 
	}
	if ($sorttype == 0){
	# make dropbox:
	foreach $zip ( sort { $moddate{$b} <=> $moddate{$a} } keys %moddate ) {
		$newdate = substr(&get_datestamp($moddate{$zip},"/"),2,8);
		$space="&nbsp;";
		print qq(<OPTION VALUE = "$zip"><div>$zip ($newdate) </div> \n);
	}
	}
	if ($sorttype == 1){
	# make dropbox:
	foreach $zip (@alldirzips) {
		$newdate = substr(&get_datestamp($moddate{$zip},"/"),2,8);
		$space="&nbsp;";
		print qq(<OPTION VALUE = "$zip"><div>$zip ($newdate) </div> \n);	
	}
	}
print qq(</SELECT></span>);
print <<EOM;
&nbsp;&nbsp;&nbsp;<INPUT TYPE="SUBMIT" CLASS=button VALUE="Unzip">
</FORM>
</body></html>
EOM


}

sub confirm {
	my $zipfiles = $FORM{"zipfiles"};
	my @zipFileArr = split(',\s*', $zipfiles);
	my ($file, $dir, $comment);

	&MS_pages_header ("Unzipadee-Do-Dir", "#6A5026", "tabvalues=Unzip&Zip:\"/cgi-bin/dir_zip.pl\"&Unzip:\"/cgi-bin/dir_unzip.pl\"");

	print <<EOF;
<FORM ACTION="$ourname" METHOD=GET>
<input type=hidden name=zipfiles value="$zipfiles">
<input type=hidden name=confirmed value=1>
EOF
	# added by Georgi (06/23/2000) to properly refreresh LCQ tracker page after unzipping from there 
	print "<input type=hidden name=caller value=$FORM{'caller'}>" if (defined $FORM{'caller'});
	
	print <<EOF;
<p><span class=smallheading>Chosen directories:</span>
<table>
EOF

	foreach $file (@zipFileArr) {
		($dir = $file) =~ s/\.zip$//;
		$comment = ((-d "$seqdir/$dir") ? "<span style='color:Red'>already exists!</span>" : "(doesn't exist now)");
		print "<tr><td>$file</td><td>&nbsp;&nbsp;&nbsp;&nbsp;$comment</td></tr>\n";
	}
	print <<EOF;
<tr height=10><td colspan=2>&nbsp;</td></tr>
<tr><td colspan=2><i>If a diresctory exists, it will be <span style="color:#FF0000">OVERWRITTEN.</span></i></td></tr>
<tr><td colspan=2><input type=checkbox name="unzipexist">&nbsp;&nbsp;Do you want to unzip directories which<span style='color:Red'> already exist?</span></td></tr>

</table><hr>
<br><div class="HarvardMicrochem">Proceed with unzipping?</b> &nbsp;&nbsp;&nbsp;
<INPUT TYPE="SUBMIT" CLASS=button VALUE="Unzip">
</FORM>



</div></body></html>
EOF
}



sub unzip
{
	my @zipFileArr = @_;
	my ($file, $dir, $comment, $output, @err, @errorCodes, $error, @dirs);
	my $tempfile = "$tempdir/dir_unzip_stdout.txt";

	&MS_pages_header ("Sequest Dir-Unzip", 0 , 
		qq(heading=<span style="color:#0080C0">Sequest</span> <span style="color:#0000FF">Dir-Unzip</span>));
	

	print "<p><HR><div class='normaltext'><image src='/images/circle_1.gif'>\nUnzipping from archive...</div><br>";

	open SAVEOUT, ">&STDOUT";
	open SAVEERR, ">&STDERR";
	open STDOUT, ">$tempfile";
	open STDERR, ">&STDOUT";
	select STDOUT; $| = 1;
	select STDERR; $| = 1;

	foreach $file (@zipFileArr) {
		($dir = $file) =~ s/\.zip$//;

		print "<B>Unzipping $file...</B>";
		print "<P><B>Command line:</B>\<br>$zipexe -extract -over=all -directories=specify $seqdir/$seqzip/$file $seqdir\n";
		print "<P><B>Output:</B>\n<pre>";

		$exitCode = system("$zipexe -extract -over=all -directories=specify $seqdir/$seqzip/$file $seqdir");

		if($exitCode != 0) { print "</pre>\n<div class='normaltext'><span style='color:Red'>Unsuccessful</span></div>\n<hr>\n"; }
		else {
			&touch("$seqdir/$dir", (stat "$seqdir/$seqzip/$file")[9]);
			print "</pre><hr>\n";
		}
	}

	close STDOUT;
	close STDERR;
	open STDOUT, ">&SAVEOUT";
	open STDERR, ">&SAVEERR";

	## update samplelist file (aka flatfile)
	@dirs = grep {s/\.zip$//} @zipFileArr;
	@err = &update_dirs_in_flatfile(@dirs);
	if($err[0] != 0) { $error = 1; }
	$err[0] = ($err[0] == 0 ? "Successful" : "<div class='normaltext'><span style='color:Red'>Unsuccessful</span></div>");

	if($error) {
		print "<div class='normaltext'><image src='/images/circle_2.gif'><span style='color:Red'>&nbsp; There were errors.</span></div>\n<HR>\n";
	} else {
		print "<div class='normaltext'><image src='/images/circle_2.gif'>&nbsp;Seems to have gone OK.</div><br>\n";

		# WhatDoYou menu included here - AARON
		
		@text = ("Run Sequest", "View Summary", "VuDTA");
		@links = ("sequest_launcher.pl?directory=$dir", "runsummary.pl?directory=$dir&sort=consensus", "dta_chromatogram.pl?def_dir=$dir");
		&WhatDoYouWantToDoNow(\@text, \@links);

		print "<hr>";
	}

	open SAVEOUT, "$tempfile";
	while(<SAVEOUT>) { print; }
	close SAVEOUT;
	unlink "$tempfile";


	print <<EOF;
<p><B>Updating Flatfile:</B>
<p>$err[0]<br>
$err[1]
EOF

# added by Georgi (06/23/2000) to properly refreresh LCQ tracker page after unzipping from there 
if ($FORM{'caller'} eq 'lcq_tracker')
{
print <<EOF;
<script>
	opener.document.forms[0].submit();
</script>
EOF
}
	
print <<EOF;	
</body>
</html>
EOF

}
