#!/usr/local/bin/perl

#-------------------------------------
#	Run Summary JavaScript Extension,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#       C. M. Wendl/T. Kim
#			Tim Vasil
#
#	v3.1a
#	
#	licensed to Finnigan
#
#	Based on Original Concept by J.Yates/J.Eng	
#
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
require "fasta_include.pl";

&cgi_receive();
$window = $FORM{'window'};
$op = $FORM{'op'};

print "Content-type: text/html\n\n";
&ShowTsunamiWindow if ($window eq 'Tsunami');
&ShowFileWindow('Clone') if ($window eq 'Clone');
&ShowFileWindow('Delete') if ($window eq 'Delete');
&ShowFileWindow('Copy') if ($window eq 'Copy');

&ShowFileWindow('Clone');

&PrintTitle('Run Summary JavaScript extension');
print "<body><p>$ICONS{'error'}This script should only be used via <a href=\"$createsummary\">Run Summary</a>";

sub PrintTitle {
	print<<EOF;
<html>
<head>
  <title>$_[0]</title>
  <script language="JavaScript">
    var isNN = (navigator.appName.indexOf("Netscape") >= 0);
    var isIE = (navigator.appName.indexOf("Microsoft") >= 0);
    if (isNN) document.write('<LINK REL="stylesheet" TYPE="text/css" HREF="/incdir/intrachem_NN.css">');
    else if (isIE) document.write('<LINK REL="stylesheet" TYPE="text/css" HREF="/incdir/intrachem_IE.css">');
  </script>
  <link rel="stylesheet" type="text/css" href="/incdir/intrachem.css">
</head>
EOF
}

sub PrintCorrectUsageChecker {
	print <<EOF;
	if (!window.opener) {
		alert("This script should only be used via Run Summary.\\n\\nClose this window.");
		window.location.href = "$createsummary";
	}
EOF
}

sub ShowTsunamiWindow {

	&PrintTitle('Tsunami Database');

	$dir = $FORM{'dir'};
	$append_file = $FORM{'append'};
	$host_list = &GetStringList(\@seqservers);

print <<EOF;
<body bgcolor=white leftmargin=0 topmargin=0>
<form name="form" onSubmit="if (CheckValues()) { SaveValues(); self.close(); pControls['execute.x'].value = 'ON'; pControls.submit(); } return false; ">
<table bgcolor="#c0c0c0" width=100% cellpadding=3>
  <tr>
    <td align=center>
	  <table><tr><td>
  	    <span class="smallheading">Operator initials:</span>
	  </td><td><input name="op" size=3 value="$op"></td></tr></table>
    </td> 
  </tr>
</table>

<center>
<table align=center border=0 cellspacing=0 cellpadding=3>
  <tr>
    <td colspan=4>&nbsp;</td>
  </tr><tr bgcolor="#e0e0e0">
    <td bgcolor="#c0c0c0" valign=center>&nbsp;<img src="$webimagedir/circle_1.gif">&nbsp;</td>
	<td><input type="checkbox" name="make" CHECKED onClick="controls.make.checked=true; alert('You must create a Fasta database to either clone a directory or run Sequest.')"></td>
	<td><span class="smalltext"><b>Make Fasta:</b></span></td>
	<td>&nbsp;<input type="name" size=30 name="makefasta" value="${dir}_tsun.fasta"></td>
  </tr><tr bgcolor="#e0e0e0">
    <td bgcolor="#c0c0c0">&nbsp;</td>
	<td colspan=2>&nbsp;</td>
	<td>
	  <table border=0 cellspacing=0 cellpadding=0>
		<tr>
		  <td><input type=checkbox name="includecontam" value="$append_file"></td>
		  <td colspan=2><span class="smalltext">Include $append_file</span></td>
		</tr><tr>
		  <td><input type=checkbox name="autoindex" checked></td>
		  <td colspan=2><span class="smalltext">Autoindex</span></td>
		</tr>
EOF

	if ($multiple_sequest_hosts) {
		print <<EOF;
		<tr>
		  <td><input type=checkbox name="copyto"></td>
		  <td><span class="smalltext">Copy to:&nbsp;</span></td>
		  <td>
EOF

	&ListHosts("copyhosts", 1, '', 1, "controls.copyto.checked=true");

	print <<EOF;
		  </td>
		</tr>
EOF
	
	} # end multiple_sequest_hosts

	print <<EOF;
	  </table>
	</td>
  </tr><tr bgcolor=white height=10>
    <td colspan=4 height=10></td>
  </tr><tr bgcolor="#e0e0e0">
    <td bgcolor="#c0c0c0" valign=center>&nbsp;<img src="$webimagedir/circle_2.gif">&nbsp;</td>
	<td><input type="checkbox" name="clone" onClick="if (controls.clone.checked) { controls.alldtas[0].checked = !controls.alldtas[1].checked; } else { controls.alldtas[0].checked = controls.alldtas[1].checked = false; }"></td>
	<td><span class="smalltext"><b>Clone directory:</b></span></td>
	<td><tt>${dir}_</tt><input type=text name="clonedir" size=7 onChange="controls.clone.checked=true;" value=""></td>
  </tr><tr bgcolor="#e0e0e0">
    <td bgcolor="#c0c0c0">&nbsp;</td>
	<td>&nbsp;</td>
	<td><span class="smalltext"><b>Comments:</b></span></td>
	<td>
	  <table border=0 cellspacing=0 cellpadding=0>
		<tr>
		  <td><span class="smalltext"><b>DTAs:</b></span></td>
		  <td><input type=radio name="alldtas" value="1" onClick="controls.clone.checked=true"></td>
		  <td><span class="smalltext">All</span></td>
		  <td><input type=radio name="alldtas" value="0" onClick="controls.clone.checked=true" ></td>
		  <td><span class="smalltext">Selected&nbsp;&nbsp;&nbsp;</span></td>
		  <td><input type=checkbox name="includeouts" onClick="controls.clone.checked=true"></td>
		  <td><span class="smalltext">Include .OUTs</span></td>
		</tr>
	  </table>
	</td>
  </tr><tr bgcolor="#e0e0e0">
    <td bgcolor="#c0c0c0">&nbsp;</td>
	<td>&nbsp;</td>
	<td colspan=2><tt><textarea name="comments" cols=40 rows=5></textarea></tt></td>
  </tr><tr bgcolor=white height=10>
    <td colspan=4 height=10></td>
  </tr><tr bgcolor="#e0e0e0">
    <td bgcolor="#c0c0c0" valign=center>&nbsp;<img src="$webimagedir/circle_3.gif">&nbsp;</td>
	<td><input type="checkbox" name="run" onClick="if (controls.run.checked) { controls.runon[0].checked = !controls.runon[1].checked } else { controls.runon[0].checked = controls.runon[1].checked = false; }"></td>
	<td><span class="smalltext"><b>Run Sequest</b></span></td>
	<td>
EOF

	if ($multiple_sequest_hosts) {
		print <<EOF;
	  <table border=0 cellspacing=0 cellpadding=0>
		<tr>
		  <td><input type=radio name="runon" onClick="controls.run.checked=true"></td>
		  <td><span class="smalltext">On server (<font color="$SERVER_COLOR"><b>$MAIN_SERVER</b></font>)</span></td>
		</tr>
	  </table>
	</td>
  </tr><tr bgcolor="#e0e0e0">
    <td bgcolor="#c0c0c0">&nbsp;</td>
	<td colspan=2>&nbsp;</td>
	<td>
	  <table border=0 cellspacing=0 cellpadding=0>
		<tr>
		  <td><input type=radio name="runon" onClick="controls.run.checked=true"></td>
		  <td><span class="smalltext">On host:&nbsp;</span></td>
		  <td>
EOF

	&ListHosts("runhost", 1, '', '', "controls.runon[1].checked = controls.run.checked = true");
	print <<EOF;
		  </td>
		</tr>
	  </table>
EOF

	} # end multiple_seuqest_hosts

	print <<EOF;
	</td>
  </tr>
</table>
<p><input type="submit" class="button" value="&nbsp;&nbsp;&nbsp;Go&nbsp;&nbsp;&nbsp;"> &nbsp; <input type="submit" class="button" value="Cancel" onClick="self.close();  return false;">
</center>

<script language="JavaScript">
EOF

&PrintCorrectUsageChecker();

print <<EOF;
var controls = document.form;
var pControls = opener.mainform;

function CheckValues() {
	if (controls.makefasta.value == '') {
		controls.makefasta.focus();
		alert("You must specify the name of the Fasta database.");
		return false;
	}
	if (controls.clone.checked || controls.run.checked) {
		if (controls.op.value == '') {
			controls.op.focus();
			alert("You must specify operator initials to clone a directory and/or run Sequest.");
			return false;
		}
	}
	if (controls.clone.checked && controls.clonedir.value == '') {
		controls.clonedir.focus();
		alert("You must specify the tag name to the cloned directory.");
		return false;
	}
	return true;
}

function SaveValues() {
	//# save general values
	pControls.op.value = controls.op.value;
	pControls.comments.value = controls.comments.value;

	//# save Make Fasta values
	pControls.makefasta.value = controls.makefasta.value;
	pControls.includecontam.value = (controls.includecontam.checked ? controls.includecontam.value : '');
	pControls.autoindex.value = (controls.autoindex.checked ? 'yes' : '');
	pControls.copyhosts.value = (controls.copyto.checked ? GetHost(controls.copyhosts) : '');
	
	//# save Clone directory values
	pControls.clonedir.value = (controls.clone.checked ? controls.clonedir.value : '');
	pControls.includeouts.value = (controls.includeouts.checked ? 'yes' : '');
	pControls.alldtas.value = (controls.alldtas[0].checked ? 'yes' : '');

	//# save Run Sequest values
	pControls.run.value = (controls.run.checked ? 'yes' : '');
	if ($multiple_sequest_hosts) { pControls.runhost.value = (controls.runon[1].checked ? GetHost(controls.runhost) : ''); }
}

function GetHost(iControl) {
	var iHost = iControl.options[iControl.selectedIndex].text;
	if (iHost == 'All hosts') {
		iHost = '$host_list';
	}
	return iHost;
}

</script>
</form>
</body>
</html>
EOF

	exit;
}

sub ShowFileWindow {

	$view = @_[0];
	$dir = $FORM{'dir'};

	&PrintTitle("$view - File Operations");

	$select = "<b><img src=\"$webimagedir/downtriangle.gif\"> $view</b>";
	$select_color = ' bgcolor="#ffffff"';

    $clone_color = $select_color if ($view eq 'Clone');
	$clone_link = ($view eq 'Clone') ? $select : "<a href=\"$ourname?window=Clone&dir=$dir&op=$op\"><b>Clone</b></a>";

	$delete_color = $select_color if ($view eq 'Delete');
	$delete_link = ($view eq 'Delete') ? $select : "<a href=\"$ourname?window=Delete&dir=$dir&op=$op\"><b>Delete</b></a>";
    
	$copy_color = $select_color if ($view eq 'Copy');
	$copy_link = ($view eq 'Copy') ? $select : "<a href=\"$ourname?window=Copy&dir=$dir&op=$op\"><b>Copy</b></a>";

print <<EOF;
<body leftmargin=0 topmargin=0 bgcolor="#ffffff">

<form name="form" onSubmit="if (CheckValues()) { SaveValues(); self.close(); pControls['execute.x'].value = 'ON'; pControls.submit(); } return false; ">

<table border=0 cellspacing=0 cellpadding=5 width=100%>
  <tr bgcolor="#c0c0c0">
    <td>&nbsp;&nbsp;&nbsp;</td>
	<td align=center$clone_color>$clone_link</td>
	<td>&nbsp;&nbsp;&nbsp;</td>
	<td align=center$delete_color>$delete_link</td>
	<td>&nbsp;&nbsp;&nbsp;</td>
	<td align=center$copy_color>$copy_link</td>
	<td>&nbsp;&nbsp;&nbsp;</td>
  </tr>
  <tr>
    <td colspan=7>
	  <table width=100%>
	    <tr><td align=center>
		  <table>
EOF
	&ShowCloneContent() if ($view eq 'Clone');
	&ShowDeleteContent() if ($view eq 'Delete');
	&ShowCopyContent() if ($view eq 'Copy');
print <<EOF;
          </table>
          <p><input type="submit" class="button" value="&nbsp;&nbsp;$view&nbsp;&nbsp;"> &nbsp; <input type="submit" class="button" value="Cancel" onClick="self.close(); return false;">
		</td></tr>
      </table>
	</td>
  </tr>
</table>
<script language="JavaScript">
EOF

&PrintCorrectUsageChecker();

print <<EOF;
var controls = document.form;
var pControls = opener.mainform;

</script>
</form>
</body>
</html>
EOF
	exit;
}

sub ShowCloneContent {
	print <<EOF;
	<tr>
		<td><nobr><span class="smalltext"><b>Operator's initials:&nbsp;</b></span></nobr></td>
		<td><input type=text name="op" value="$op" size=3></td>
	</tr><tr>
		<td><span class="smalltext"><b>Clone directory:</b></span></td>
		<td><tt>${dir}_</tt><input type=text name="clonedir" size=7 value=""></td>
	</tr><tr>
		<td><span class="smalltext"><b>Comments:</b></span></td>
		<td>
		  <table border=0 cellspacing=0 cellpadding=0>
			<tr>
			  <td><span class="smalltext"><b>DTAs:</b></span></td>
			  <td><input type=radio name="alldtas" value="1"></td>
			  <td><span class="smalltext">All</span></td>
			  <td><input type=radio name="alldtas" value="0" checked></td>
			  <td><span class="smalltext">Selected&nbsp;&nbsp;&nbsp;</span></td>
			  <td><input type=checkbox name="includeouts"></td>
			  <td><span class="smalltext">Include .OUTs</span></td>
			</tr>
		  </table>
		</td>
    </tr><tr>
 	  <td colspan=2><tt><textarea name="comments" cols=44 rows=5></textarea></tt></td>
	</tr>

<script>
function CheckValues() {
	if (controls.op.value == '') {
		controls.op.focus();
		alert("You must specify operator initials.");
		return false;
	}
	return true;
}
function SaveValues() {
	pControls.op.value = controls.op.value;
	pControls.comments.value = controls.comments.value;
	pControls.clonedir.value = controls.clonedir.value;
	pControls.includeouts.value = (controls.includeouts.checked ? 'yes' : '');
	pControls.alldtas.value = (controls.alldtas[0].checked ? 'yes' : '');
}
</script>
EOF
}

sub ShowDeleteContent {
	print <<EOF;
	        <tr>
			  <td colspan=3 align=center>
				  <table><tr><td>
					<span class="smallheading">Operator initials:</span>
				  </td><td><input name="op" size=3 value="$op"></td></tr></table>
			  </td>
		    </tr><tr>
			  <td><input type=checkbox name="alldtas" onClick="if (controls.alldtas.checked) controls.includeouts.checked = true" checked></td>
			  <td><span class="smalltext">Selected .DTAs</span></td>
			</tr>
		    </tr><tr>
			  <td><input type=checkbox name="includeouts" checked onClick="if (controls.includeouts.checked) controls.alldtas.checked = true"></td>
			  <td><span class="smalltext">Selected .OUTs</span></td>
			</tr>
<script>
function CheckValues() {
	if (controls.op.value == '') {
		controls.op.focus();
		alert("You must specify operator initials.");
		return false;
	}
	return true;
}
function SaveValues() {
	pControls.op.value = controls.op.value;
	pControls.alldtas.value = (controls.alldtas.checked ? 'yes' : '');
	pControls.includeouts.value = (controls.includeouts.checked ? 'yes' : '');
}
</script>
EOF
}

sub ShowCopyContent {
	print <<EOF;
			<tr>
			  <td><span class="smalltext"><b>Destination: </b></span></td>
			  <td colspan=2>
EOF
	&get_alldirs();		#by GMM 07/03/2001 to allow copying stuff to any dir. To revert remove this line and @alldirs below 
	print '&nbsp;<select name="refdir" size=1>';
	foreach $item (@ordered_names) {
		my $selected = ($item eq $DEFAULT_REFDIR)?"SELECTED":"";
		print qq|<option value="$item" $selected>$fancyname{$item}|;
	}
	print '</select></td>';
	print <<EOF;
		    </tr><tr>
			  <td></td>
			  <td><input type=checkbox name="alldtas" checked></td>
			  <td><span class="smalltext">Selected .DTA-sets</span></td>
			</tr>
		    </tr><tr>
			  <td></td>
			  <td><input type=checkbox name="includeouts" checked></td>
			  <td><span class="smalltext">Selected .OUTs</span></td>
			</tr>
<script>
function CheckValues() {
	return true;
}
function SaveValues() {
	pControls.refdir.value = controls.refdir.options[controls.refdir.selectedIndex].value;
	pControls.alldtas.value = (controls.alldtas.checked ? 'yes' : '');
	pControls.includeouts.value = (controls.includeouts.checked ? 'yes' : '');
}
</script>
EOF
}
