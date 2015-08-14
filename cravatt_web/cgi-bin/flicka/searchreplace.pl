#!/usr/local/bin/perl

#-------------------------------------
#	Search and Replace,
#	(C)1999 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 8/11/99 by Chris Wendl
# Last Modified: 8/11/99 by cmw
#
# This script searches through a Sequest directory for a specified string
# and replaces it with another specified string.  Just like a normal global search+replace
# routine, except that it also changes filenames where necessary.

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
&redirect("$ourname?") if ($FORM{"reset"});
&MS_pages_header("Dir de Dozen", "#871F78", "tabvalues=Search and Replace&Clone-A-Dir:\"/cgi-bin/cloneadir.pl\"&Delete-A-Dir:\"/cgi-bin/deleteadir.pl\"&Combine-A-Dir:\"/cgi-bin/combineadir.pl\"&Rename-A-Dir:\"/cgi-bin/renameadir.pl\"&Search and Replace:\"/cgi-bin/searchreplace.pl\"");
$dir = $FORM{"directory"};
$searchstring = $FORM{"searchstring"};
$replacestring = $FORM{"replacestring"};
$operator = $FORM{"operator"};

# define default $searchstring if $dir is specified
if (((!defined $searchstring) && (!$FORM{"do_search"})) || ($FORM{"get_default"})) {
	if (defined $dir) {
		opendir(DIR, "$seqdir/$dir") || &error("Directory $seqdir/$dir is inaccessible.");
		$file = "";
		while ($file !~ /\.dta$/) {
			$file = readdir(DIR);
		}
		($searchstring) = ($file =~ /^(.*?)\.\d{4}\.\d{4}\.\d\.dta$/);
	}
}

&output_form unless (defined $FORM{"do_search"});

	$now = &get_unique_timeID();
	#get unique file names for the two frames
	my $interface_file = "$ourshortname" . "_interface" . "_$now.html";
	my $results_file = "$ourshortname" . "_results" . "_$now.html";





######################################
# Main action
# error checking
	$bullet =  "\n&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;•&nbsp;&nbsp;&nbsp;&nbsp;";
    $space =  "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
&error("You must specify a search string!") unless ($searchstring);
&error("The replacement string may not contain any whitespace characters!") if ($replacestring =~ /\s/);
&error("You must type your initials in the <b>Operator</b> field if you want to make replacements!") if ($replacestring && !$operator);
$operator =~ tr/A-Z/a-z/;

	print<<EOF;

<div>
<br><span class=smallheading><image src="/images/circle_1.gif">&nbsp;Directory: </span><tt><a href="$viewinfo?directory=$dir">$dir</a></tt>
<br>$bullet<span class=smallheading>Search string: </span><tt style="color:#0000ff">$searchstring</tt>

EOF

if ($replacestring) {
	print qq(<br>$bullet<span class=smallheading>Replacement string: </span><tt style="color:#009900">$replacestring</tt>\n<br>);
	print qq(<br><span style="color:#ff0000">Remember to wait until this page is finished loading, and check the bottom for error messages.</span>\n);
	print "<br><br>\n";
}else {
	print qq(</ul>);
}

# modify search string so that it can't possibly contain any special regexp characters
# i.e. put a backslash before every non-alphanumeric character
$searchstring_orig = $searchstring;
$searchstring =~ s/(\W)/\\$1/g;
@immune_files = ("$dir.log", "$dir\_deletions_log.html");
# make a list of all files in the directory
opendir(DIR,"$seqdir/$dir") || &error("Cannot access directory $seqdir/$dir");
@allfiles = grep((-f "$seqdir/$dir/$_"), readdir DIR);
closedir DIR;
$changecount = $renamecount = 0;

# replace strings in contents of all files

print qq(<table> <tr><td valign=top><image src="/images/circle_2.gif"></td> <td>);
foreach $file (@allfiles) {

	next if (grep(($file eq $_), @immune_files));

	$replcount = 0;
	if (open(FILE,"<$seqdir/$dir/$file")) {
		@lines = ();
		while(<FILE>) {
			if ($replacestring) {
				$replcount += s/$searchstring/$replacestring/og;
				push(@lines,$_);
			} else {
				$replcount += scalar(@replcount = m/$searchstring/og);
			}
		}
		close FILE;
	} else {
		push(@errors,"Failed to read file $file");
	}
	# write out the modified version of the file
	if ($replcount) {
		if ($replacestring) {
			if (open(FILE,">$seqdir/$dir/$file")) {
				print FILE join("",@lines);
				close FILE;
				$instances = ($replcount == 1) ? "instance" : "instances";
				print "Replaced <b>$replcount</b> $instances of search string in <tt>$file</tt><br>\n";
				$changecount++;
			} else {
				push(@errors,"Failed to write modified version of file $file");
			}
		} else {
			$instances = ($replcount == 1) ? "instance" : "instances";
			print "Found <b>$replcount</b> $instances of search string in <tt>$file</tt><br>\n";
			$changecount++;
		}
	}
}
print qq(</td></tr></table>);
print "<br>\n";

# rename all strings whose names contain the search string
print qq(<table> <tr><td valign=top><image src="/images/circle_3.gif"></td> <td>);
print qq(<TEXTAREA rows=13 cols=80 STYLE="color: #000000;">);
foreach $file (@allfiles) {
	if ($file =~ /$searchstring/) {
		if ($replacestring) {
			($newfilename = $file) =~ s/$searchstring/$replacestring/og;
			if (rename("$seqdir/$dir/$file", "$seqdir/$dir/$newfilename")) {
				print qq(Renamed $file to $newfilename\n);
				$renamecount++;
			} else {
				push(@errors,"Failed to rename $file to $newfilename");
			}
		} else {
			$renamecount++;
			print qq(The file $file must be renamed\n);
		}
	}
}
print qq(</TEXTAREA></td></TR></table>);

$files_change = ($changecount == 1) ? "file" : "files";
$files_rename = ($renamecount == 1) ? "file" : "files";
if ($replacestring) {
	print "<span class=smalltext>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$changecount $files_change modified, $renamecount $files_rename renamed.</span>";
} else {
	print "<span class=smalltext>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Matches were found in $changecount $files_change, and $renamecount $files_rename must be renamed.</span>";
}

if (@errors) {
	print qq(<br><br><span style="color:#ff0000"><h3>The following errors occurred:</h3>\n);
	print join("<br>\n",@errors);
	print "</span>\n";
}
print <<EOF;
</div>
</body></html>
EOF
@text = ("View DTA Chromatogram", "Run Sequest", "Run Summary");
@links = ("dta_chromatogram.pl","sequest_launcher.pl" , "runsummary.pl");
&WhatDoYouWantToDoNow(\@text, \@links);
# write to directory log
&write_log($dir,qq(Replaced all instances of "$searchstring_orig" with "$replacestring"   ) . localtime() . "  $operator") if ($replacestring);

exit 0;


#######################################
# subroutines (other than &output_form and &error, see below)

#######################################
# Main form subroutine
# this may or may not actually printout a form, and in a few (very few) programs it may be unnecessary
# it should output the default page that a user will see when calling this program (without any particular CGI input)
sub output_form {
	$searchstring = &HTML_encode($searchstring);
	$replacestring = &HTML_encode($replacestring);
	&get_alldirs;
	print <<EOF;
<script language="Javascript">
<!--
	function confirmation()
	{
		if (document.forms[0].replacestring.value == "")
			return true;
		return confirm("Are you sure you want to replace all instances of " + document.forms[0].searchstring.value + " with " + document.forms[0].replacestring.value + "?");
	}
//-->
</script>
<div>
<form action="$ourname" method=post>
<table cellpadding=4 cellspacing=0 border=0>
<tr>
	<th align=right><span class=smallheading>Directory:</span></th>
	<td>
<span class=dropbox><SELECT name="directory">
EOF
	foreach $directory (@ordered_names) {
		$selected = ($dir eq $directory) ? " selected" : "";
		print qq(<option value="$directory"$selected>$fancyname{$directory}\n);
	}
	print <<EOF;
</select></span>
</td>
<tr>
<tr>
	<th align=right><span class=smallheading>Search for:</span></th>
	<td><input size=40 name="searchstring" value="$searchstring">&nbsp;<input type=submit class=button name="get_default" value="Get Default"></td>
<tr>
	<th align=right><span class=smallheading>Replace with:</span></th>
	<td><input size=40 name="replacestring" value="$replacestring"></td>
</tr>
<tr>
	<th align=right><span class=smallheading>Operator:</span></th>
	<td><input size=3 maxlength=3 name="operator" value="$operator">&nbsp;&nbsp;<input type=submit class=button name="do_search" value="Proceed" onClick="return confirmation()">&nbsp;&nbsp;<input type=submit class=button name="reset" value="Reset">&nbsp;&nbsp;<span class="smalltext"><a href="$webhelpdir/help_$ourshortname.html" target=_blank>Help</a></span></td>
</tr>
</table>
</form>
</div>
</body></html>

EOF
	exit 0;
}

#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {
	print "<h3>Error:</h3><div>";
	print join("<br>\n",@_);
	print "</div></body></html>\n";
	exit 1;
}
