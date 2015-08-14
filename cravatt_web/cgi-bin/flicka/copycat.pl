#!/usr/local/bin/perl

#-------------------------------------
#	Fasta CopyCat & FastaRemova,
#	(C)2000 Harvard University
#	
#	W. S. Lane / Tim Vasil
#
#	
#	11/01/01 A. Chang - Added embedded autoindexing option, modified WhatDoYou menu, new output format 
#
#	licensed to Finnigan
#-------------------------------------


################################################
# Created:			May, 2000 by Tim Vasil
# Last Modified:	June, 2000 by Tim Vasil
#
# CopyCat - Mirrors FASTA databases to Sequest hosts
# Remova - Deletes FASTA databases from Sequest hosts and/or the server (use remova=<boolean_true> param)
#


#####################################
# Require'd and use'd files
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
### Additional includes (if any) go here
require "fasta_include.pl";

$|=1;

#######################################
# Fetching data
&cgi_receive;

$db = $FORM{"db"};
$hosts = $FORM{"hosts"};
$run = $FORM{"run"};
$overwriteok = $FORM{"overwrite"};
$cancel = $FORM{"cancel"};
$use_remova = $FORM{"remova"};
$removahhelp = ".remova" if ($use_remova);
$include_server = $FORM{"include_server"};
$autocheck = $FORM{"autoindex"};

$date = $starttime = localtime(time);
#######################################
# Initial output
# this may or may not be appropriate; you might prefer to put a separate call to the header
# subroutine in each control branch of your program (e.g. in &output_form)
if ($use_remova) {
	&MS_pages_header("FastaRemova","#993300");
} else {
	&MS_pages_header("Fasta CopyCat","#FF3300");
}
print "<HR><BR>\n";


#######################################
# Fetching defaults values
#
$hosts = (($use_remova) ? &GetStringList(\@seqservers) : $DEFAULT_COPY_HOSTS) unless (defined $hosts || $run);
$db = $DEFS_COPYCAT{"Database"} unless (defined $db);

#######################################
# Flow control
#
# Here is where the program decides, on the basis of whatever input it's been given,
# what it should do

&output_form unless ($db && ($hosts || ($include_server && $use_remova)) && $run && !(defined $cancel));



######################################
# Main action
#
# This is where the program does what it's really been conceived to do.

$hosts = &AddToStringList($MAIN_SERVER, $hosts) if ($include_server);

if (!$overwriteok) {
	if ($use_remova) {
		print "<p>Looking for $db on Sequest hosts";
	} else {
		print "<p>Checking for pre-existing copies";
	}
	@overwrites = &DbExistsOnHosts("$dbdir/$db", $hosts, 1);
	if ($overwrites[0]) {
		$Overwrite = (!$use_remova) ? 'Overwrite' : 'Yes -- Delete from host(s)';
		$Already = ' already' if (!$use_remova);
		$Warning = "\n<p>$ICONS{'warning'}Are you <b>sure</b> you want to delete $db from these host(s)?" if ($use_remova);
		$hosts = $overwrites[0] if ($use_remova);
		print <<EOF
<form method=post name="confirmform">
<p><font color=red><a href=\"$webdbdir/$db\">$db</a>$Already exists on @overwrites[1].</font>$Warning &nbsp;
<p><input type=submit class="button" name="overwrite" value="$Overwrite">&nbsp;
   <input type=submit class="button" name="cancel" value="Cancel">
<input type=hidden name="hosts" value="$hosts">
<input type=hidden name="db" value="$db">
<input type=hidden name="run" value="yes">
<input type=hidden name="overwrite" value="ok">
<input type=hidden name="include_server" value="$include_server">
<input type=hidden name="remova" value="$use_remova">
<input type=hidden name="autoindex" value="$autocheck">
</form>
EOF
	} elsif ($use_remova) {
		@host_list = &GetListFromString($hosts);
		$hosts = &GetStringList(\@host_list, 'or');
		print "<p><font color=red>$ICONS{'error'}<a href=\"$webdbdir/$db\">$db</a> does not exist on $hosts.</font>";
	}
}
if ($overwriteok || (!$overwrites[0] && !$use_remova)) {
	@dests = &MirrorDb("$dbdir/$db", $hosts, 1, $use_remova);

	$phrase = (!$use_remova) ? 'copied to' : 'deleted from';
	$phrase2 = (!$use_remova) ? 'copying' : 'deleting';
	$phrase2asst = (!$use_remova) ? 'to' : 'from';
	$dbprint = (!$use_remova) ? "<a href=\"$webdbdir/$db\">$db</a>" : $db;

	# autoindexing
	$results = AutoIndexDb($db) if ($autocheck);
	$resultmsg = ($results || $autocheck) ? "started" : "<font color=red><b>Cannot auto-index</b>:  database exceeds $MAX_AUTOINDEX_SIZE bytes</font><br>Index this database manually using an option below";
	

	print "<br><img src=\"/images/circle_1.gif\"> $dbprint $phrase @dests[0]." if (@dests[0]);

	# modified autoindex output
	if ($autocheck) {
		print "<br><br><img src=\"/images/circle_2.gif\"> Indexing, $resultmsg on $ENV{'COMPUTERNAME'}.";
	} elsif (!$use_remova) {
		print "<br><br><img src=\"/images/circle_2.gif\"> No indexing performed on $ENV{'COMPUTERNAME'}.";
	}
    print "<br><br><font color=red>$ICONS{'error'}Error $phrase2 $dbprint $phrase2asst @dests[1].</font>" if (@dests[1]);
}

print "</body></html>";


#######################################
# Main form subroutine
# this may or may not actually printout a form, and in a few (very few) programs it may be unnecessary
# it should output the default page that a user will see when calling this program (without any particular CGI input)
sub output_form {
	$IncludeServerCheck = " CHECKED" if (defined $include_server) ? $include_server : $DEFS_REMOVA{"Include server"} eq 'yes';

	print <<EOF;
<form method=post name="form" onSubmit="return CheckForm()">
<input type=hidden name="run" value="yes">
<input type=hidden name="remova" value="$use_remova">
<table cellspacing=0 cellpadding=0 border=0><tr>
  <td valign=top align=right><b><span class="smalltext">Database:&nbsp;</span></b></td>
  <td valign=top>  
EOF

&ListDatabases("db", $db, '', $multiselect);

# "checked" hash table for autoindexing - AARON 
	$checked{"autoindex"} = ($DEFS_FASTAMAKA{"Auto-index headers"} eq "yes") ? " checked" : "";

# include autoindex checkbox beneath database menu - AARON

    print <<EOF if (!$use_remova);
  <br>
    <INPUT TYPE=CHECKBOX NAME="autoindex" $checked{"autoindex"}>
    <b><span class=smalltext> Auto-index FASTA headers</b></span>
  <br>
EOF

	$CopyMsg = (!$use_remova) ? 'Copy to' : 'Delete from';
	$Copy = (!$use_remova) ? 'Copy' : 'Delete';
	print <<EOF;
  &nbsp;&nbsp;
  <br>
    <input type=submit class="button" value="$Copy database">&nbsp;&nbsp;
    <input type=reset class="button" value="Clear">
    &nbsp;&nbsp;&nbsp;&nbsp;

    <a href="$webhelpdir/help_$ourshortname$removahelp.html">Help</a>
  </td>
  <td valign=top><span class="smalltext"><b>$CopyMsg Sequest host(s):</b>&nbsp;<br>&nbsp;<br>&nbsp;&nbsp;Hold <tt>Ctrl</tt> key while<br>&nbsp;&nbsp;clicking to select<br>&nbsp;&nbsp;multiple hosts</span></td>
  <td valign=top>	
EOF


&ListHosts("hosts", (($#seqservers + 1 > 7) ? 7 : $#seqservers + 1), $hosts);

	print <<EOF;
  &nbsp;&nbsp;
  </td>
  <td valign=top>
EOF

print "<input type=\"checkbox\" name=\"include_server\"$IncludeServerCheck><span class=\"smalltext\"><b> Also remove from server ($MAIN_SERVER)</b></span></td>" if ($use_remova);

$JScriptUseRemova = ($use_remova) ? '1' : '0';
print <<EOF;
</tr></table></form>
<script>
function CheckForm() {
	if (GetSelectedIndex(document.form.hosts) == -1) {
		if ($JScriptUseRemova && document.form.include_server.checked) {
			return true;
		}
		document.form.hosts.focus();
		alert("Please select one or more destination hosts before proceeding.");
		return false;
	}
	return true;
}
function GetSelectedIndex(list) {
	for (var i = 0; i < list.options.length; i++)
		if (list.options[i].selected)
			return i;
	return -1;
}
</script>
</body></html>
EOF

	exit 0;
}



#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {

	print "<p>@_";

	exit 1;
}
