#!/usr/local/bin/perl

#-------------------------------------
#	PepFind,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
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
&get_dbases;

# make dropbox:

&MS_pages_header ("PepFind", "#0080C0");
print"<hr>\n";

print <<EOF;
<br>
<TABLE WIDTH=100%>
<TR VALIGN=TOP>
<TD>
<FORM ACTION="$retrieve" METHOD=GET>
<!INPUT TYPE=HIDDEN NAME="program" VALUE="$retrieve">
<center><h3 style="color:#0000FF">Retrieve a Protein</h3></center>
<br>
<table><tr><td align=right>
Database: </td><td><span class=dropbox><SELECT name="db">
EOF

foreach $db (@ordered_db_names) {
	print qq(<OPTION VALUE = "$dbdir/$db");
	print " SELECTED" if ($db eq $DEFAULT_DB);
	print (">$db\n");
}
print <<FIRSTFORMEND;
</SELECT></span></td></tr>

<tr><td align=right>
Header info: </td>
<td><INPUT NAME="ref">&nbsp;
<INPUT TYPE=SUBMIT CLASS=button VALUE="Retrieve">&nbsp;
<INPUT TYPE=RESET CLASS=button VALUE="Clear"></td></tr>

<tr><td align=right>Peptide to search for: </td>
<td><INPUT NAME="pep"> <i>(optional)</i></td>
</tr></table>

</FORM>

</TD>

<TD>
<FORM ACTION="$localblast" METHOD=GET>
<!INPUT TYPE=HIDDEN NAME="program" VALUE="$localblast">
<center><h3 style="color:#8000FF">Find a Sequence</h3></center>
<br>
<table><tr>
<td align=right>Database: </td>
<td><span class=dropbox><SELECT name="db">
FIRSTFORMEND

foreach $db (@ordered_db_names) {
	print qq(<OPTION VALUE = "$dbdir/$db");
	print " SELECTED" if ($db eq $DEFAULT_DB);
	print (">$db\n");
}
print <<SECONDFORMEND;
</SELECT></span></td></tr>

<tr><td align=right valign=top>Peptide to search for: </td>
<td valign=top><INPUT NAME="pep">&nbsp;
<INPUT TYPE=SUBMIT CLASS=button VALUE="Search">&nbsp;
<INPUT TYPE=RESET CLASS=button VALUE="Clear"><P>

Note: this program can be very slow, and should<BR>be used only with small databases.

</td>
</tr></table>
<p>


</FORM>

</TD>
</TR>
</TABLE>

</BODY>
</HTML>
SECONDFORMEND
