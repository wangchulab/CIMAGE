#!/usr/local/bin/perl
#-------------------------------------
#	Rename-A-Dir,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker/C. M. Wendl
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
&cgi_receive();

&MS_pages_header("Dir de Dozen", "#871F78", "tabvalues=Rename-A-Dir&Clone-A-Dir:\"/cgi-bin/cloneadir.pl\"&Delete-A-Dir:\"/cgi-bin/deleteadir.pl\"&Combine-A-Dir:\"/cgi-bin/combineadir.pl\"&Rename-A-Dir:\"/cgi-bin/renameadir.pl\"&Search and Replace:\"/cgi-bin/searchreplace.pl\"");

$directory = $FORM{"directory"};
$sampleID = $FORM{"sample_id"};
$first_initial = $FORM{"first_initial"};
$lastname = $FORM{"last_name"};
$samplename = $FORM{"sample_name"};
$operator = $FORM{"operator"};

$comments = $FORM{"comments"};
$comments = &encode_comments($comments);

unless ($FORM{"rename"}) {
  &get_alldirs;
  &output_form;
  exit;
}


if (!defined $operator) {
	&error("You must type your initials in the Operator field.");
}
$operator =~ tr/A-Z/a-z/;


%attribs = &get_dir_attribs($directory);
($prev_first_initial,$prev_lastname,$prev_samplename,$prev_sampleID,$datestamp,$oldcomments,$runNumber) = 
	($attribs{"Initial"},$attribs{"LastName"},$attribs{"Sample"},$attribs{"SampleID"},$attribs{"Datestamp"},$attribs{"Comments"},$attribs{"RunNumber"});


chomp($oldcomments);
$comments = "$oldcomments<BR>renamed<BR>$comments" if ($oldcomments ne "");

# carry over previous values if not supplied by user
$first_initial = $prev_first_initial unless ($first_initial =~ /\S/);
$lastname = $prev_lastname unless ($lastname =~ /\S/);
$samplename = $prev_samplename unless ($samplename =~ /\S/);
$sampleID = $prev_sampleID unless ($sampleID =~ /\S/);


$newdir = $first_initial . $lastname . $samplename;
$newdir =~ tr/A-Z/a-z/;
$newdir =~ tr/a-z0-9_-//cd;

&error("The new directory name is the same as the old name.") if ($newdir eq $directory) && ($sampleID eq $prev_sampleID);

if (-d "$seqdir/$newdir") {
	# make sure that the existing dir and the selected dir are not the same directory
	%attribs =  &get_dir_attribs("$newdir");
	my $myID = $attribs{"SampleID"};
	if ($myID ne $prev_sampleID) {
		&error("The directory $newdir already exists.");
	}
}
	
# rename the actual directory
if ($newdir ne $directory) {
	rename("$seqdir/$directory", "$seqdir/$newdir") || &error("Cannot rename $seqdir/$directory: permission denied!");

	chdir("$seqdir/$newdir") || &error("Cannot access new directory $seqdir/$newdir!");

	# rename the log files
	rename("$directory.log", "$newdir.log");
	rename("$directory\_deletions_log.html", "$newdir\_deletions_log.html");
	&write_log($newdir,"Directory $directory renamed to $newdir   " . localtime() . "  $operator");
}


# Munge the variables for the header
$first_initial =~ tr/a-z/A-Z/;
$samplename =~ tr/a-z/A-Z/;
$sampleID =~ tr/a-z/A-Z/;
$lastname =~ tr/A-Z/a-z/;
$lastname =~ tr/a-z//cd;
$temp = substr ($lastname, 0, 1);
$temp =~ tr/a-z/A-Z/;
$lastname = $temp . substr ($lastname, 1);


## remove old version from flatfile
@retval = &removefrom_flatfile($directory);
push(@errors,"Failed removing old directory info from flatfile: $retval[1]") if ($retval[0]);

## add to flatfile and write new Header.txt
&save_dir_attribs($newdir, "Initial"=>$first_initial, "LastName"=>$lastname, "Sample"=>$samplename, "Directory"=>$newdir,
	"SampleID"=>$sampleID, "Datestamp"=>$datestamp, "Operator"=>$operator, "Comments"=>$comments, "RunNumber"=>$runNumber) || push(@errors,"Failed writing modified directory into flatfile or Header.txt");

&rename_success;

print "</body></html>\n";
exit;



sub rename_success {
  @msgs = @_;

  print <<EOM;
<p>
<div class="normaltext">

<image src="/images/circle_1.gif">&nbsp;Directory rename was successful.<br><BR>
<table cellspace=0 cellpadding=3>
	<th><td align="center" class="smallheading">Old</td><td align="center" class="smallheading">New</td></th>
	<tr><td><span class="smallheading">Directory:</span></td>
	    <td><span style="color:#0000ff">$directory</span></td>
		<td><a href="$viewinfo?directory=$newdir">$newdir</a></td>
	</tr>
	<tr><td><span class="smallheading">Sample ID:</span></td>
		<td><span style="color:#0000ff">$prev_sampleID</span></td>
EOM

if ($prev_sampleID eq $sampleID) {
	print ("<td><span style='color:#0000ff'>$sampleID</span></td>");
}
else {
	print("<td><span style='color:red'>$sampleID</span></td>");
}

  print <<EOM;

	</tr>
	<tr ><td><span class="smallheading">User First Initial:</span></td>
		<td><span style="color:#0000ff">$prev_first_initial</span></td>
EOM

if ($prev_first_initial eq $first_initial) {
	print ("<td><span style='color:#0000ff'>$first_initial</span></td>");
}
else {
	print("<td><span style='color:red'>$first_initial</span></td>");
}

  print <<EOM;

	</tr>
	<tr><td><span class="smallheading">User Last Name:</span></td>
		<td><span style="color:#0000ff">$prev_lastname</span></td>
EOM

if ($prev_lastname eq $lastname) {
	print ("<td><span style='color:#0000ff'>$lastname</span></td>");
}
else {
	print("<td><span style='color:red'>$lastname</span></td>");
}

  print <<EOM;

	</tr>
	<tr><td><span class="smallheading">Sample (Run) Name:</span></td>
		<td><span style="color:#0000ff">$prev_samplename</span></td>
EOM

if ($prev_samplename eq $samplename) {
	print ("<td><span style='color:#0000ff'>$samplename</span></td>");
}
else {
	print("<td><span style='color:red'>$samplename</span></td>");
}

  print <<EOM;

	</tr>
</table>

<br>
<table width="60%" cellspacing=0 cellpadding=4>
<tr bgcolor="#e2e2e2">
<td valign=top><image src="/images/circle_2.gif"></td>
<td valign=top class="smalltext">
If you merely needed to rename your directory, you can stop here. If you also need to rename the DTA files
in your directory to match a different .RAW filename, go to <a href="$webcgi/searchreplace.pl?directory=$newdir">Search and Replace</a> (and see
<a href="$webhelpdir/help_searchreplace.pl.html" target=_blank>Help</a> if you need more explanation).
</td>
</tr>
</table>
</div>
EOM

@text = ("Search and Replace","Create DTA", "Run Sequest", "Sequest Summary","View DTA Chromatogram");
@links = ("searchreplace.pl","create_dta.pl","sequest_launcher.pl" , "runsummary.pl?directory=$newdir","dta_chromatogram.pl");
&WhatDoYouWantToDoNow(\@text, \@links);
if (@errors) {
    print ("<p>The following non-fatal errors were reported:<br>\n");
    print join ("<br>\n", @errors);
	print "</p>\n";
  }
}



sub output_form {
	my $seqdropbox = &make_sequestdropbox("directory", "$directory", 'onChange="document.rename.submit();"');

  print <<EOFORM;

<FORM NAME="rename" ACTION="$ourname" METHOD=GET>
<input type="hidden" name="selectedindex" value=""/>
<TABLE>

<TR>
<TD>
<span class=smallheading>Directory to Rename:</span><br>
EOFORM

my %attribs;   
if (!$directory) {
	## pass over the latest directory values as the default values
	%attribs = &get_dir_attribs(@ordered_names[0]);
}
else {
	## pass over the selected directory values
	%attribs = &get_dir_attribs($directory);
}
  
($first_initial,$lastname,$samplename,$sampleID) = 
	($attribs{"Initial"},$attribs{"LastName"},$attribs{"Sample"},$attribs{"SampleID"});

print $seqdropbox;
#foreach $dir (@ordered_names) {
#	%attribs = &get_dir_attribs($dir);
#    $selected = ($dir eq $directory) ? " SELECTED" : "";
#	print qq(<OPTION VALUE = "$dir" $selected>$fancyname{$dir}\n);
#}
#  print <<EOFORM;
#</SELECT>
print <<EOFORM;
</SPAN></TD>

</TD>
<TR>
<TR>
<TD>

<br>
<span class=smallheading>Components of New Name</span><span style="color:0000ff">*</span><br>

<CENTER>
<TABLE CELLSPACING=2 CELLPADDING=0 BORDER=0>
<TR>
<td align=right><span class="smallheading">Sample ID: </span></td>
<td><input name="sample_id" type="text" maxlength=25 value='$sampleID'></TD>
</TR>

<TR>
<TD align=right nowrap><span class="smallheading">User First Initial: </span></TD>
<TD><INPUT name="first_initial" type="text" maxlength=1 value='$first_initial'></TD>
</TR>

<TR>
<TD align=right nowrap><span class="smallheading">User Last Name: </span></TD>
<TD><INPUT name="last_name" type="text" maxlength=50 value='$lastname'></TD>
</TR>

<TR>
<TD align=right nowrap><span class="smallheading">Sample (Run) Name: </span></TD>
<TD><INPUT name="sample_name" type="text" maxlength=25 value='$samplename'></TD>
</TR>
</TABLE>
</CENTER>

<span class="smalltext" style="color:0000ff">*fields left blank will carry over values from the old directory</span>
</TD></TR></TABLE>

<br>

<DIV>
<span class="smallheading">Comments</span><span class="smalltext"> (to append to old comments):</span><BR>
<tt><TEXTAREA NAME="comments" COLS=50 ROWS=5 MAXSIZE=240 WRAP></TEXTAREA></tt>

<br><br>

<span class="smallheading">Operator:</span> <INPUT NAME="operator" VALUE="$operator" SIZE=3 MAXLENGTH=3>&nbsp; <INPUT TYPE=SUBMIT NAME="rename" CLASS=button VALUE="Rename Me">
&nbsp;<a href="javascript:LinkTo('$webhelpdir/help_$ourshortname.html',1);">Help</a>
</DIV>

</FORM>

</div>

EOFORM

}


sub error {

	print <<EOF;

<H3>Error:</H3>
<div>
@_
</div>
</body></html>
EOF

	exit 0;

}
