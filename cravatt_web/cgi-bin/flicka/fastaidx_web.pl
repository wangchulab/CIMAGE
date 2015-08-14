#!/usr/local/bin/perl

#-------------------------------------
#	FastaIdx_Web,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# web interface for database indexing


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

$DEFAULT_PRIORITY = "low";


$priority_table = (
	"low"       =>  "IDLE_PRIORITY_CLASS",
	"normal"    =>  "NORMAL_PRIORITY_CLASS",
	"high"      =>  "HIGH_PRIORITY_CLASS",
	"realtime"  =>  "REALTIME_PRIORITY_CLASS"
);
$priority_checked{$DEFAULT_PRIORITY} = " checked";


$idxprogram="$cgidir/fastaidx.pl";
require "fastaidx_lib.pl";

&cgi_receive();


unless ($FORM{"running"}) {
	&output_form;
	exit 0;
}

$priority_class = ($FORM{"priority_class"} || $DEFAULT_PRIORITY);
$priority_class = $priority_table{$priority_class};


&MS_pages_header ("DB Indexer", "8800FF", "tabvalues=FastaIdx&MakeDB4:\"/cgi-bin/makedb4.pl\"&FastaIdx:\"/cgi-bin/fastaidx_web.pl\"");

$database = defined($FORM{'Database'}) ? $FORM{'Database'} : '';

if ($database eq "") {
	print qq(<span class="smalltext">Undefined database.  To go back, click <a href="history.back()">here</a>.</span>);
	exit 1;
}

chdir($dbdir);

($mydbdir) = $dbdir =~ m/\w\:(.*)/;

if (openidx("$dbdir/$database")) {
    closeidx();
    ($dbname) = $database =~ m/(\w+)\.fasta/;
    unlink("$dbdir/$dbname.pag");
    unlink("$dbdir/$dbname.dir");
}

select(STDOUT);
$|=1;

#FORK: {
#    if ($pid = fork) {
	# exit, or wait briefly for quick-terminating runs
#    } elsif (defined $pid) {
#	createidx("$dbdir/$database");
$procobj = &run_in_background("$perl $idxprogram $dbdir/$database");
$procobj->SetPriorityClass(IDLE_PRIORITY_CLASS);

print "<div><p>Indexing has started on database file $database.</body></html>";

#    } elsif ($! =~/No more process/) {
#	sleep 5;
#	redo FORK;
#    } else {
#	print "Unable to start indexing process.</body></html>";
#    }
#}



sub output_form
{

$selected_db = defined($FORM{'selected'}) ? $FORM{'selected'} : '';

&MS_pages_header("DB Indexer", "8800FF", "tabvalues=FastaIdx&MakeDB4:\"/cgi-bin/makedb4.pl\"&FastaIdx:\"/cgi-bin/fastaidx_web.pl\"");

print <<EOF;

<P>

<H1><FORM method="GET" action="$ourname"></H1>
<INPUT TYPE=hidden NAME="running" VALUE="ja">

<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=2>
<TR>
<td><b>Database:</b></td>
<td>
EOF

&get_dbases;

# make dropbox:
print ("<span class=\"dropbox\"><SELECT name=\"Database\">\n");

foreach $db (@ordered_db_names){
	$idx=$db; $idx=~s/\.fasta//;
	if (!(&openidx("$dbdir/$idx"))) {
	&closeidx();
	print qq(<OPTION VALUE = "$db");
	print " SELECTED" if ($db eq $selected_db);
	print (">$db");
	} else {
	print qq(<OPTION VALUE = "$db");
	print " SELECTED" if ($db eq $selected_db);
	print (">$db*\n");
	}
}

#-------- This used to make a dropbox with indexed dbs divided
#--------  from non indexed dbs.  now the above dropbox displays all 
#---------  databases - L.Sullivan 11/18/99

print ("</SELECT></span>");

print <<EOF;
</td>
</tr>
<tr><td></td><td><span class="smalltext">*Databases marked with a star are already indexed.</span></td><tr>

<!--
<tr>
	<td height=5>&nbsp;</td>
</tr>
<tr>
	<td>
		<b>	Priority:</b>
	</td>
	<td>
		<input type=radio name="priority_class" value="low"$priority_checked{"low"}>low <input type=radio name="priority_class" value="normal"$priority_checked{"normal"}>normal <input type=radio name="priority_class" value="high"$priority_checked{"high"}>high
	</td>
</tr>
//-->
<tr>
	<td></td><td><br><input type="submit" class=button value="Index">&nbsp;&nbsp;<a class="smallheading" href="/help/help_$ourshortname.html" target="new">Help</a></td>
</tr>
</table>
<br>
<br>

<UL>
<P></FORM></P>
</UL>

</BODY>
</HTML>

EOF

}