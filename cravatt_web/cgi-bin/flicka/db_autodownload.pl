#!/usr/local/bin/perl

#-------------------------------------
#	Database Autodownload,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
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
	require "microchem_form_defaults.pl";
}
################################################
require "seqcomm_include.pl";

@ftp_dbs = (
	"nr",
	"est",
	"mito_aa"
);

# These names will show up on the web page.
# The three categories are TurboSequest Host, Sequest Host, and Webserver.
%machine_type_names = (
	"turbo"			=>		"TurboSequest Host",
	"regular"		=>		"Sequest Host",
	"webserver"		=>		"Webserver"
);

$temp_dist = $DEFS_DB_AUTODOWNLOAD{"Order of Distribution"};
# Get rid of all whitespace in the beginning and end before splitting on commas with any (or no) whitespace before and after
$temp_dist =~ s/^\s*//;
$temp_dist =~ s/\s*$//;
@order_of_distribution = split (/\s*,\s*/, $temp_dist);

&MS_pages_header("Database Autodownload", "8800FF");
print "<hr><br>\n";

&cgi_receive;
$db = ($FORM{"db"} || $DEFAULT_DB);
$db =~ s/\.fasta$//;

&run_ftp_script if ($FORM{"run"});


if ($FORM{"showlog"}) {

	print <<EOF;
<table width=100%><tr>
<td align=left>
<b>Contents of <a href="$webdbdir/$db.download.log">$dbdir/$db.download.log</a>:</b>
</td>
<td align=right>
<a href="#form">Skip to bottom (form)</a>
</td>
</tr></table>
<pre>
EOF
	open LOGFILE, "$dbdir/$db.download.log";
	while (<LOGFILE>) {
		s/&/&amp;/g;
		s/"/&quot;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		print;
	}
	close LOGFILE;
	print "</pre><hr>\n";
	print '<a name="form"></a>';
	exit;
}

&output_form;
exit;

sub output_form {

	%machine_type = ();
	# Set up the types of machines based on the included variables
	# The machines getting the db index are okay for Turbo runs
	foreach $elt (@makedb_recipients) {
		$lc_elt = lc $elt;
		$machine_type{$lc_elt} = $machine_type_names{"turbo"};
	}
	$lc_elt = lc $webserver;
	$machine_type{$lc_elt} =  $machine_type_names{"webserver"};
	foreach $elt (@order_of_distribution) {
		# All remaining machines are just regular Sequest machines
		$lc_elt = lc $elt;
		if (!(defined $machine_type{$lc_elt})) {
			$machine_type{$lc_elt} = $machine_type_names{"regular"};
		}
	}

	# Get the log file names
	opendir(DBDIR,"$dbdir");
	@logs = sort { $a cmp $b} grep /\.download\.log$/, readdir(DBDIR);
	close DBDIR;

	print <<EOF;
<a name="form"></a>
<div>
<!--<form action="$ourname" method="post">-->
<b>View Autodownload Log: </b>&nbsp;&nbsp;
EOF
	foreach $log (@logs) {
		($dbname = $log) =~ s/\.download\.log$//;
		print qq(<a href="$ourname?db=$dbname&showlog=1">$dbname</a>&nbsp;&nbsp;);
	}

	print <<EOF;
<p>

<script language="Javascript">
<!--
function confirm_run()
{
	// debug: add other checks here

	var checked_name;
	for (var i = 0; i < document.forms[0].db.length; i++) {
		if (document.forms[0].db[i].checked) {
			checked_name = document.forms[0].db[i].value;
		}
	}

	if (confirm("Are you sure you want to run ftp_fastadb.pl on " + checked_name + ".fasta?")) {
		document.runscript.submit();
	}
}

function selectAll()
{
	for (i=0; i < document.forms[0].elements.length; i++)
	{
		var elt = document.forms[0].elements[i];
		if (elt.type == 'checkbox')
		{
			elt.checked = true;
		}
	}
}

function selectNone()
{
	for (i=0; i < document.forms[0].elements.length; i++)
	{
		var elt = document.forms[0].elements[i];
		if (elt.type == 'checkbox')
		{
			elt.checked = false;
		}
	}
}

function selectInv()
{
	for (i=0; i < document.forms[0].elements.length; i++)
	{
		var elt = document.forms[0].elements[i];
		if (elt.type == 'checkbox')
		{
			if (elt.checked == true) {
				elt.checked = false;
			} else {
				elt.checked = true;
			}
		}
	}
}

//-->
</script>


<form name="runscript" action="$ourname" method="post">
<b>Run Autodownload Script:</b><br>
<b>Database:</b>
EOF
	foreach $dbname (@ftp_dbs) {
		$selected = ($db eq $dbname) ? " checked" : "";
		print qq(<input type="radio" name="db" value="$dbname"$selected>$dbname.fasta&nbsp;&nbsp;);
	}
	print <<EOF;
<br><br>
<b>Select:</b>
<input type='button' class='button' value='&nbsp;&nbsp;All&nbsp;&nbsp;' onClick="selectAll()">&nbsp;&nbsp;
<input type='button' class='button' value='&nbsp;None&nbsp;' onClick="selectNone()">&nbsp;&nbsp;
<input type='button' class='button' value='&nbsp;&nbsp;Inv&nbsp;&nbsp;' onClick="selectInv()">&nbsp;&nbsp;
<input type='reset' class='button' value='Default'><span class="smalltext"style="color:#999999">&nbsp;&nbsp;(Default resets Database as well)</span>
<br><br>

<b>Processing (on Download Server $DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER):</b><br>
<table cellspacing=0 cellpadding=2 border=1 width=500>
<tr><td width=20>&nbsp;</td><td><center><span class="smallheading">Procedure</span><center></td></tr>
<tr><td><center><input type=checkbox name="-d" value=1 checked></center></td><td>&nbsp;&nbsp;Download</td></tr>
<tr><td><center><input type=checkbox name="-z" value=1 checked></center></td><td>&nbsp;&nbsp;Unzip</td></tr>
EOF


	print <<EOF;
<tr><td><center><input type=checkbox name="-i" value=1 checked></center></td><td>&nbsp;&nbsp;Run FastaIdx (creates an index for description lines)</td></tr>
<tr><td><center><input type=checkbox name="-m" value=1 checked></center></td><td>&nbsp;&nbsp;Run MakeDB4 (creates an index needed for TurboSequest runs)</td></tr>
</table>
<br>
<b>Distribution:</b><br>

<table cellspacing=0 cellpadding=2 border=1 width=500>
<tr>
<td width=20><span class="smallheading">&nbsp;</span></td>
<td><center><span class="smallheading">Name</span></center></td>
<td><center><span class="smallheading">Type</span></center></td>
<td><center><span class="smallheading">Fasta</span></center></td>
<td><center><span class="smallheading">Turbo</span></center></td>
<td><center><span class="smallheading">F.Idx</span></center></td>
</tr>
EOF

	$db_i = 1;
	foreach $cnt (0..$#order_of_distribution) {
		$remserver = $order_of_distribution[$cnt];
		next if ($remserver eq "");		# Just a little check in case the array (via form defaults) has a few blank entries
		$lc_elt = lc $remserver;
		# Based on what type of machine $remserver is, assign the checkboxes checked by default.
		# For a Webserver, send over the regular Fasta and the FastaIdx.
		# For a TurboSequest Host, send over the regular Fasta and the Turbo Index.
		# For a Sequest Host, send over the regular Fasta.
		if ($machine_type{"$lc_elt"} eq $machine_type_names{"webserver"}) {
			$def_r = " checked";
			$def_t = "";
			$def_f = " checked";
		} elsif ($machine_type{"$lc_elt"} eq $machine_type_names{"turbo"}) {
			$def_r = " checked";
			$def_t = " checked";
			$def_f = "";
		} elsif ($machine_type{"$lc_elt"} eq $machine_type_names{"regular"}) {
			$def_r = " checked";
			$def_t = "";
			$def_f = "";
		}
		print <<EOF;
<tr>
<td><center><span class="smallheading">$db_i</span></center></td>
<td>&nbsp;&nbsp;$remserver</td>
<td>&nbsp;&nbsp;$machine_type{$lc_elt}</td>
<td><center><input type=checkbox name="-r$remserver" value=1$def_r></center></td>
<td><center><input type=checkbox name="-t$remserver" value=1$def_t></center></td>
<td><center><input type=checkbox name="-f$remserver" value=1$def_f></center></td>
EOF
		$db_i++;
	}
	print <<EOF;
</td></tr>
</table>
<br>

<input type=hidden name="run" value=1>
<input type=button class=button value=" Run " onClick="confirm_run()">
&nbsp;&nbsp;&nbsp;&nbsp;<a href="$webhelpdir/help_$ourshortname.html" target="_blank">Help</a>
</form>
</div>
</body></html>
EOF

}


sub run_ftp_script {

	# ascertain whether the script is already running
	$stamp = "$dbdir/.ftp_fastadb_running";
	if (open(STAMP, ">$stamp")) {
		unless (flock STAMP, ($LOCK_EX | $LOCK_NB)) {
			print <<EOF;
<h3>Error:</h3>
<div>
An instance of Autodownload is already running.  Please wait until it is finished before running this program.
</div>
</body></html>
EOF
			exit 0;
		}
		close STAMP;
	}

	# If makedb4.pl is doing a big indexing, do not run db_autodownload, could conflict (8-24-00 P.Djeu)
	$stamp = "$dbdir/.runmakedb_running";
	if (open(STAMP, ">$stamp")) {
		unless (flock STAMP, ($LOCK_EX | $LOCK_NB)) {
			print <<EOF;
<h3>Error:</h3>
<div>
An instance of MakeDB4 is already running.  Please wait until it is finished before running this program.
</div>
</body></html>
EOF
			exit 0;
		}
		close STAMP;
	}

	# add each command line option that is specified in the form input
	# (these options direct the script to do these steps in the download process)
	# the following options follow this model: -d -z -p -i -m
	@possible_options = ("-d", "-z", "-p", "-i", "-m");
	@options = ();
	foreach $option (@possible_options) {
		push(@options,$option) if ($FORM{$option});
	}

	# These form elements will set the task list: -r$Machine -t$Machine -f$Machine.
	# Each of these options is read in and are put into the following format:
	# -u[MachineName]__[0|1]__[0|1]__[0|1]
	#                   -r     -t     -f
	# The order that the -u args will appear in the command line is determined by the order the Machines appear
	# in @order_of_distribution.
	#
	# Note that the order of the -u flags as they appear in the command line is very important because ftp_fastadb.pl
	# will process these in the order it sees them
	foreach $remserver (@order_of_distribution) {
		next if ($remserver eq "");		# In case of split errors
		$temp_str = "-u$remserver";
		$temp_flag = 0;
		if (defined $FORM{"-r$remserver"}) {
			$temp_flag = 1;
			$temp_str .= "__1";
		} else {
			$temp_str .= "__0";
		}
		if (defined $FORM{"-t$remserver"}) {
			$temp_flag = 1;
			$temp_str .= "__1";
		} else {
			$temp_str .= "__0";
		}
		if (defined $FORM{"-f$remserver"}) {
			$temp_flag = 1;
			$temp_str .= "__1";
		} else {
			$temp_str .= "__0";
		}

		# only add if we need to do something for this comp
		push(@options,$temp_str) if ($temp_flag);
	}
	

	$options = join(" ",@options);
	# Note: ftp_fastadb.pl is READ FROM the webserver NOT from the remote $dbdownload_server but IS RUN on the remote $dbdownload_server
	$cmdline = "\$perl \$cgidir/ftp_fastadb.pl $options $db";

	# run the script
	&seqcomm_send($DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER, "run_in_background&$cmdline");

	print <<EOF;
<div>
Command line <b>perl ftp_fastadb.pl $options $db</b> is being run on <b>$DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER</b>.<p>
<a href="$ourname?showlog=1&db=$db">View $db.download.log</a>
</div>
</body></html>
EOF

	exit;

}
