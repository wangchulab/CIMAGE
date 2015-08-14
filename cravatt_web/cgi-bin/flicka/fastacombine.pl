#!/usr/local/bin/perl

#-------------------------------------
#	Fasta Combine
#	(C)2001 Harvard University
#	
#	W. S. Lane
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created:			April, 2001 by Abe Gurjal
#
# FastaCombine - Combines FASTA databases
#


################################################
# Require'd and use'd files
#

################################################
# find and read in standard include file
#
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
### Additional includes (if any) go here
#
require "fasta_include.pl";

$|=1;

#######################################
# Fetching data
#
&cgi_receive;

$db = $FORM{"db"};
$newfile = $FORM{"newfile"};
$autoindex = $FORM{"autoindex"};
$copyhosts = $FORM{"copyhosts"};

#######################################
# Initial output
#
&MS_pages_header("Fasta Combine","#993300");
print "<HR><BR>\n";

#######################################
# Fetching defaults values
#
$checked{"autoindex"} = ($DEFS_FASTA_COMBINE{"Auto-index headers"} eq "yes") ? " checked" : "";
$checked{"copyhosts"} = ($DEFS_FASTA_COMBINE{"Copy to hosts"} eq "yes") ? " checked" : "";
my $newname = $DEFS_FASTA_COMBINE{"new database name"};

#######################################
# Flow control
#
# Here is where the program decides, on the basis of whatever input it's been given,
# what it should do

&output_form unless ((defined $db) && (defined $newfile));

######################################
# Main action
#
# This is where the program does what it's really been conceived to do.
#

$starttime = localtime(time);

# get the files to combine and clip off the whitespace
@files = split(/\s*,\s*/, $db);

# concat all the contents of the files
$concat = "";
foreach(@files) {
	if (!open(CURRENT, "$dbdir/$_")) {
		&error ("Could not open file $_.\n");
	} else {
		@lines = <CURRENT>;
		$concat .= join "", @lines;
		close (CURRENT);
	}
}

# write it all out in the given filename
chomp $newfile;
if (!open (OUT, ">$dbdir/$newfile")) {
    &error ("Could not write to file $newfile.\n");
} else {
	print OUT $concat;
	close OUT;

	# print out a nice success page
	&success_page();

	print <<EOF;
</body>
</html>
EOF

}
exit 0;

#######################################
# Main form subroutine
sub output_form {

	# Print out the main page for Fasta Combine
	print <<EOF;
<form method=post name="form" OnLoad="CountSelected()" OnSubmit="FixInput()">
<table cellspacing=5 cellpadding=0 border=0>
<tr>
  <td valign=top align=left><b><span class="smalltext">Select Databases to Combine:&nbsp;</span></b></td>
</tr>
<tr>
  <td valign=top>
EOF

	# &ListDatabases($form_element_name, [$default_selection, [$an_additional_entry, [$multiselect_size, [$javascript_event_handler]]]])
	&ListDatabases_a("db", $db, '', 16, " OnChange=\"CountSelected()\"");

	print <<EOF;
  </td>
</tr>
<tr>
  <td>
     <span class="smalltext">
     Hold <tt>Ctrl</tt> key to select multiple databases.
	 </span>
  </td>
</tr>
<tr>
  <td valign=center>
	<b><span style="color:#FF0000" id="selected_dbs">0</span></b>
	<span class="smallheading" id="numsel">Databases selected for a total size of</span>
	<b><span style="color:#FF0000" id="total_bytes">0</span></b>
	<span class="smallheading" id="numsel">kb.</span>&nbsp;&nbsp;
	 <input type=button class="button" value="Clear" onClick="ClearForm()">
   </td>
</tr>

<tr>
	<td valign=top align=left><b><span class="smalltext">New file:&nbsp;</span>
	<input name="newfile" type=textbox size=29 value="$newname">&nbsp;&nbsp;
	</td>
</tr>

<tr>
   <TD valign=top align=left>
      <INPUT TYPE=CHECKBOX NAME="autoindex"$checked{"autoindex"}><b><span class=smalltext> Auto-index FASTA headers</span></b>
	  <br>
      <INPUT TYPE=CHECKBOX NAME="copyhosts"$checked{"copyhosts"}><b><span class=smalltext> Copy to hosts</span></b>
   </TD>
</tr>
<tr><td>&nbsp;</td></tr>
<tr>
	<td>
		<input type=submit class="button" value="Combine Databases">&nbsp;&nbsp;
		&nbsp;&nbsp;
		<a href="$webhelpdir/help_$ourshortname.html">Help</a>
	</td>
</tr>
</table></form>

<SCRIPT LANGUAGE=JAVASCRIPT>
<!--

 function ClearForm() {
    document.forms(0).reset();
	CountSelected();
 }	
 function CountSelected(){

        var coll = document.all.tags("SELECT");
        var strg = 0;
		var sum = 0;
        if (coll.length>0) {
                for (i=0; i< coll(0).options.length; i++)
                        if(coll(0).options(i).selected) {
                                strg++;
								sum += parseInt(coll(0).options(i).value);
						}
        }
        document.all.selected_dbs.innerText = strg;
        document.all.total_bytes.innerText = parseInt(sum/1000);
}
function FixInput(){
	    var coll = document.all.tags("SELECT");
        if (coll.length>0) {
                for (i=0; i< coll(0).options.length; i++)
                        if(coll(0).options(i).selected) {
								coll(0).options(i).value = coll(0).options(i).text;
						}
        }
}
//-->
</SCRIPT> 

</body></html>
EOF

	exit 0;
}


#######################################
# &ListDatabases($form_element_name, [$default_selection, [$an_additional_entry, [$multiselect_size, [$javascript_event_handler]]]])
#
# Prints a list of FASTA database files
# If $multiselect_size is true, multiselect is enabled
#
sub ListDatabases_a {
	my ($list_name, $default_file, $othertitle, $multiselect_size, $js_event) = @_;
	my $multiselect = " MULTIPLE SIZE=$multiselect_size" if ($multiselect_size);

	local *DBDIR;
    opendir (DBDIR, "$dbdir") || { print ("Could not open $dbdir!<p>\n") &&
				       return };
    @files = grep { /^[^\.].*\.fasta$/ } readdir (DBDIR);
    closedir DBDIR;

    @files = sort { lc($a) cmp lc($b) } @files;
	@files = ($othertitle, @files) if ($othertitle);

    print ("<span class=dropbox><SELECT NAME=\"$list_name\"$multiselect$js_event>\n");
    foreach $file (@files) {
		# get the file size in bytes
		@stats = stat "$dbdir/$file";
		print ("<OPTION");
		print " VALUE=$stats[7]";
		print (" SELECTED") if ($file eq $default_file);
		print (">$file\n");
    }
    print ("</SELECT></span>\n");
}

#######################################
# Success Page
# prints out a nice success page

sub success_page {
  PrintDbCreationResults(db			=> $newfile,
						 copyhosts	=> (($FORM{"copyhosts"}) ? $DEFAULT_COPY_HOSTS : ''),
						 autoindex	=> $FORM{"autoindex"});

$endtime = localtime(time);
print <<SUCCESS;
<p>
<span class="smalltext" style="color:#8E236B">Starting time: $starttime</span><br>
<span class="smalltext" style="color:#8E236B">Ending time: $endtime</span>
SUCCESS

}

#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {
	print "<p>@_";
	exit 1;
}
