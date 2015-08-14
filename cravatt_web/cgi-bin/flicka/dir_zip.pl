#!/usr/local/bin/perl

#-------------------------------------
#	Dir Zip,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
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

# define zip subdir
require "dirzip_include.pl";
$program = "$cgidir/dircycle_zipbak_one.pl";  

&MS_pages_header ("Zipadee-Do-Dir", "#6A5026", "tabvalues = Zip&Zip:\"/cgi-bin/dir_zip.pl\"&Unzip:\"/cgi-bin/dir_unzip.pl\"");
&cgi_receive();

$sorttype = $FORM{"sorttype"};
if(!defined $sorttype){
	$sorttype=0;
}

$name = ($sorttype == 0) ? "CHECKED" : "";
$date = ($sorttype == 1) ? "CHECKED" : "";
$reversesort = ($sorttype == 1 && $FORM{"revsort"} == 0) ? "document.zipform.revsort.value=1;" : "";


&output_form unless ($FORM{"execute"} && !$FORM{"sortchange"});

$dirs = $FORM{"directory"};
$dirs =~ s/\s*,\s*/ /g;

$action=$FORM{"onselect"}; 

$args = "";
if ($action == 0) {
	$args .= "-da " 
}elsif ($action == 2){
	$args .= "-d " 
}elsif  ($action == 1){
	$args .= "-a " 
}
$args .= $dirs;
&run_in_background("$perl $program $args"); 

print "<br><div class=normaltext>The selected directories are now being archived on $ENV{'COMPUTERNAME'}; command line was:<p><span style=\"color:#000088\">$program $args</span>" if (($action == 0)||($action==1));
print "<br><div class=normaltext>The selected directories are now being deleted on $ENV{'COMPUTERNAME'}; command line was:<p><span style=\"color:#000088\">$program $args</span>" if ($action==2);
print "<p>Directories will be deleted if zip is successful." if ($action==0);
print "</div></body></html>";

exit;

sub output_form {
	print <<EOF;
<form name=zipform action="$ourname" method="post"  onSubmit="javascript: return checkSelect();">
<span class=smallheading>Select directory\(ies\) to archive:</span>
EOF

	&get_alldirs(1);

	foreach $dir (keys %fancyname) {
		$fancyname{$dir} .= "*" if (-e "$seqdir/$seqzip/$dir.zip");   #if zip file exists append a "*" to name
	}

	if ($sorttype == 1) {
	    my @new_ordered_names = ();
		my %included = ();

		foreach $name (@ordered_names) {
			next if ($name eq "placeholderline" || $included{$name} == 1 );

			$included{$name} = 1;
			push (@new_ordered_names, $name);
		}

		if ($FORM{"revsort"} == 1) {
			@ordered_names = sort {$mtime{$a} <=> $mtime{$b}; } @new_ordered_names;  # sort by mod date, ascending
		} else {
			@ordered_names = sort {$mtime{$b} <=> $mtime{$a}; } @new_ordered_names;  # sort by mod date, descending
		}
	}

	
print <<EOF;
<input type="hidden" name="execute" value=1>
<input type="hidden" name="sortchange" value=0>
<input type="hidden" name="revsort" value=0>
<TABLE BORDER=0 width=700><TR><TD width=45%>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<span class=smallheading>Sort:</span>
<input type=radio name=sorttype value=0 $name onClick="document.zipform.sortchange.value=1; document.zipform.submit();"><span class=smallheading>By Name</span>&nbsp;&nbsp;
<input type=radio name=sorttype value=1 $date onClick="$reversesort document.zipform.sortchange.value=1; document.zipform.submit();"><span class=smallheading>By Date</span><br>
<span class=dropbox>
<SELECT NAME="directory" multiple size=25>
EOF
	foreach $dir (@ordered_names) {
		print "<OPTION VALUE = \"$dir\" $selected>$fancyname{$dir} - $mymoddate{$dir}\n";
	}

	print <<EOF;
</SELECT></span>&nbsp;&nbsp;&nbsp;&nbsp;</TD><TD valign=top>
<TABLE border=0 cellpadding=2 cellspacing=2><tr ><td width=300>
<br><span class="smalltext" style="color:#FF0000">
Each selected Sequest directory will be archived to a
zip file of the same name. An archived directory can
be restored with <a href="/cgi-bin/dir_unzip.pl">Sequest Dir-Unzip</a>. *Asterisked Sequest
runs have a zip archive. Select to update.</span><p></td><td></td></tr>

<tr><td><DIV><span style="color:black" class=smallheading>On Selected:</span></DIV></td><td></td></tr>
<tr><td>&nbsp;&nbsp;&nbsp;<input type=radio name="onselect" value="0" CHECKED>
<span style="color:teal" class=smallheading>Archive, Then Delete</span></td><td></td></tr>  
<tr><td>&nbsp;&nbsp;&nbsp;<input type=radio name="onselect" value="1">
<span style="color:teal" class=smallheading> Archive</span>&nbsp;</td><td></td></tr> 
<tr><td>&nbsp;&nbsp;&nbsp;<input type=radio name="onselect" value="2" onclick="javascript:areyousure()">
<span style="color:teal" class=smallheading> Delete</span> </td><td></td></tr>

<tr><td><br><input type=submit class=button value="Go">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="$webhelpdir/help_$ourshortname.html">Help</a></td><td></td></tr>
</TD><td></td></TR></TABLE></TD></TR></TABLE></form>
</body></html>

<SCRIPT language="JavaScript">
function checkSelect()
{
	var i, count = 0;
	var options = document.zipform.directory.options;
	for(i = 0; i < options.length; i++) {
		if(options[i].selected) {
			count++;
		}
	}
	if(count == 0) {
		alert("Please Select Directory(ies) to archive.");
		return false;
	}
	return true;
}
function areyousure()
{
	alert ("Are you sure you want to delete the selected Directories without archiving them first?");
}

</SCRIPT>
EOF

	exit;

}
