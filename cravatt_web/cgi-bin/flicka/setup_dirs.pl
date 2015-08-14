#!/usr/local/bin/perl
#-------------------------------------
#	Setup SEQUEST Directories (formerly ssdirs),
#	(C)1997-2000, 1998 Harvard University
#	
#	W. S. Lane/M. A. Baker/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


## This is a re-write of the setup directory script
## in Perl, for portability to NT and security.

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


require "seqcomm_include.pl" if ($multiple_sequest_hosts);


#$mycolor = "#5959AB";		#original blue-grey
$mycolor = "#236B8E";

&cgi_receive();

if ($FORM{"getsniff"}) {
	$selected_file = &RemoveExtension(&GetFilename($FORM{"sniff_file"}));
	$selected_file =~ tr/a-z/A-Z/;
	&sniff_lookup();
}
#if (defined $FORM{"selected_file"}) {
#	$selected_file = $FORM{"selected_file"};
#}

unless ($FORM{"running"}) {
	&output_form;
}



$first_initial = $FORM{"first_initial"};
$lastname = $FORM{"last_name"};
$samplename = $FORM{"sample_name"};
$sampleID = $FORM{"sample_id"};
$operator = $FORM{"operator"}; # operator initials stuff added 98/07/23 Martin
$comments = $FORM{"comments"}; # added by cmw 98/07/30
$runNumber = $FORM{"run_number"};	# added by dls 99/05/17
$instrument = $FORM{"instrument"};  # added by pm 06/28/00
chomp $comments;
$comments = &encode_comments($comments);

$express = $FORM{"EXPRESS"}; # this controls the level of automation
$LcqFile = $FORM{"LcqFile"};
$FORM{"run_ionquest"} = 0 if (!defined $FORM{"run_ionquest"});
$run_CSD = $FORM{"run_CSD"};

$datestamp = &get_datestamp();

if (((!defined $first_initial) || (!defined $lastname) || (!defined $samplename)
    || (!defined $sampleID) || (!defined $express)) && (!defined $FORM{"no_name"})) {
  &error ("not enough arguments!");
}

if (!defined $operator) {
  &error ("Remember to type your initials in the <b>operator</b> field!<br>\n");
}
$operator =~ tr/A-Z/a-z/;

$dir = $first_initial . $lastname . $samplename;
$dir =~ tr/A-Z/a-z/;
$dir =~ tr/a-z0-9_-//cd;

$dirname = "$seqdir/$dir";




if ($FORM{"WriteSniff"} eq "yes") {  # Create a Sniff File

$filename = $FORM{"filename"};
$ExtStart = index ($filename, ".");
if ($ExtStart > 0) {
	$filename = substr ($filename, 0, $ExtStart);
}



&MS_pages_header ("Directory Setup Results", "$mycolor");
print "<P><HR><P><div>\n";

if (-f "$lcqdir\\$filename.$sniff_extension" && !defined ($FORM{"Override"})) {
	$YesURL = "$ourname?" . &make_query_string(%FORM, "Override" => "yes");
	print ("$lcqdir/$filename.$sniff_extension already exists.  Overwrite? &nbsp;&nbsp;&nbsp;");
	print <<EOF;
<input value="Yes" type="button" class="button" onclick='javascript: location.replace("$YesURL")'>
&nbsp;&nbsp;&nbsp;&nbsp;
<input value="No" type="button" class="button" onClick="javascript: self.history.back()">
EOF
	exit;
}



if ($express eq "SEQUEST") {
	$WhatToDo = "RunSequest";
} elsif ($express eq "none" || $express eq "CREATEDTA") {
	$WhatToDo = "SetupDir";
} elsif ($express eq "run_CREATEDTA" || $express eq "IONQUEST") {
	$WhatToDo = "CreateDTA";
#} elsif ($express eq "run_CSD") {
#	$WhatToDo = "run_CSD";
} else {
	$WhatToDo = "IonQuest";
}

$StartScan = $FORM{"CREATEDTA:StartScan"};
$EndScan = $FORM{"CREATEDTA:EndScan"};
$MinIons = $FORM{"CREATEDTA:MinIons"};
$MinTIC = $FORM{"CREATEDTA:MinTIC"};
$percentage = $FORM{"IONQUEST:percentage"};

$refdir = $FORM{"refdir"};
$refdir =~ s/(^\S)*\s/$1/g; 



$Database = $FORM{"SEQLAUNCH:Database"};
$Enzyme = $FORM{"SEQLAUNCH:Enzyme"};
$runOnServer = $FORM{"SEQLAUNCH:runOnServer"};
$Q_immunity = $FORM{"SEQLAUNCH:Q_immunity"};
# SeqIndex no longer used, so set use_index to 0
$use_index = 0;
$DirExt = $FORM{"DirExt"};
$UseExisting = $FORM{"UseExisting"};


open (RAW_HEADER, ">$lcqdir\\$filename.$sniff_extension") || &error("Could not create file");

print RAW_HEADER <<EOF;
Initial:$first_initial
LastName:$lastname
Sample:$samplename
SampleID:$sampleID
operator:$operator
Comments:$comments
RunNumber:$runNumber
CREATEDTAStartScan:$StartScan
CREATEDTAEndScan:$EndScan
CREATEDTAMinIons:$MinIons
CREATEDTAMinTIC:$MinTIC
percentage:$percentage
refdir:$refdir
SEQLAUNCHrunOnServer:$runOnServer
SEQLAUNCHDatabase:$Database
SEQLAUNCHEnzyme:$Enzyme
SEQLAUNCHQ_immunity:$Q_immunity
SEQLAUNCHuse_index:$use_index
WhatToDo:$WhatToDo
DirExt:$DirExt
UseExisting:$UseExisting
EOF

close RAW_HEADER;



open (WRITTEN, "$lcqdir/$filename.$sniff_extension") || &error("Could not complete Sniff File");

print "Successfully created Sniff file <a href=\"\\\\$ENV{\"COMPUTERNAME\"}\\Lcq\\$filename.$sniff_extension\">$lcqdir/$filename.$sniff_extension</a><br>Contents of Sniff File:<br><br>";
while (<WRITTEN>) {
	chomp;
	print ("$_ <br>\n");
}

exit 0;






}



if ( -d "$dirname" ) {
  &error ("$dirname already exists!", qq(Go to the <a href="$create_dta">Create_Dta</a> page.));
}

# Make directory
# full permissions, as modified by umask in microchem_include.pl
mkdir ($dirname, 0777);


# create log file
($logfiledir = $dirname) =~ s!$seqdir/!!;
&write_log($logfiledir,"Directory $dirname created  " . localtime() . "  $operator");

# Munge the variables for the header

$first_initial =~ tr/a-z/A-Z/;
$samplename =~ tr/a-z/A-Z/;
$sampleID =~ tr/a-z/A-Z/;

$lastname =~ tr/A-Z/a-z/;
$lastname =~ tr/a-z//cd;

$temp = substr ($lastname, 0, 1);
$temp =~ tr/a-z/A-Z/;

$lastname = $temp . substr ($lastname, 1);


## add to the flatfile and Header.txt
&save_dir_attribs($dir, "Initial" => $first_initial, "LastName" => $lastname, "Sample" => $samplename, "Directory" => $dir,
	"SampleID" => $sampleID, "Datestamp" => $datestamp, "Operator" => $operator, "Comments" => $comments, "RunNumber" => $runNumber) ||
	&error ("Could not write to flatfile and/or Header.txt");


# Copy default files
if (-f "$default_extract_msn_exclude") {
  &copyfiles($default_extract_msn_exclude, $dirname);
  &touch("$dirname/lcq_dta.exclude");
}
if (-f "$default_seqparams") {
  &copyfiles($default_seqparams, "$dirname/sequest.params");
  &touch("$dirname/sequest.params");
}


if ($express eq "none") {

	# do nothing

} elsif ($express eq "CREATEDTA") {

  # in this case, DON'T make dta files ...
  # just skip the intervening page
  @CREATEDTA_ARGS = grep /^CREATEDTA:/, keys %FORM;
  foreach (@CREATEDTA_ARGS,"run_ionquest","operator") {
	(my $key = $_) =~ s/^CREATEDTA://;
	$CREATEDTA_ARGS{$key} = $FORM{$_};
  }
  $url = "$create_dta?" . &make_query_string(%CREATEDTA_ARGS, "directory" => $dir, "LcqFile" => $FORM{"LcqFile"});
  &redirect($url);

  exit 0;

} else {

  # error if .RAW datafile not chosen
  if ($FORM{"LcqFile"} eq "none") {
	@CREATEDTA_ARGS = grep /^CREATEDTA:/, keys %FORM;
	foreach (@CREATEDTA_ARGS,"run_ionquest","operator") {
		(my $key = $_) =~ s/^CREATEDTA://;
		$CREATEDTA_ARGS{$key} = $FORM{$_};
	}
	$url = "$create_dta?" . &make_query_string(%CREATEDTA_ARGS, "directory" => $dir);
	&error(qq(The directory has been set up, but you didn't choose a Datafile!  Go to <a href="$url">Create DTA</a>));
  }

  $LcqFile = $FORM{"LcqFile"};
  if ($LcqFile eq "none") {
	&error ("No data file selected.",  qq(Please go to the <a href="$create_dta">Create_DTA</a> page),
	"and select an appropriate data file.");
  }

  # run through some portion of the "basic search"
  &bulldozer();
}



&MS_pages_header ("Directory Setup Results", "$mycolor");
print "<P><HR><P>\n";


print <<EOF;
<TABLE>
<TR>
  <TD><b>Username:</b></TD>
  <TD>$first_initial. $lastname</td>
</TR>
<TR>
	<TD><b>Sample Run Name:</b></TD>
	<TD>$samplename</TD>
</TR>
<TR>
	<TD><b>Sequest Directory:</b></TD> 
	<TD><a href="$webseqdir/$dir">$dir</a></TD>
</TR>
<TR>
	<TD><b>Sample ID:</b></TD> 
	<TD>$sampleID</TD>
</TR>
<TR>
	<TD><b>Operator:</b></TD> 
	<TD>$operator</TD>
</TR>
</TABLE>

<p>
<script>
<!--
var go = new Array;
addGoItem("$create_dta?directory=$dir");
addGoItem("$deleteadir?directory=$dir");
function addGoItem(text) {
	go[go.length] = text;
}
-->
</script>
<form name="what_to_do" method=get onSubmit="if (go[document.what_to_do.link.selectedIndex]=='history.back()') { history.back(); } else { window.location.href = go[document.what_to_do.link.selectedIndex] } return false;">
<p><img src="/images/icons/question.gif" align=middle> What do you want to do now? &nbsp;
<select name="link">
  <option>Goto Create DTA with the directory loaded</option>
  <option>Oops! Delete this directory with Delete-a-Dir</option>
</select>&nbsp;&nbsp;<input type=submit value="&nbsp;Go&nbsp;" class="button"></form></div>
EOF
  print "</body></html>\n";
  exit 0;




#######################
## Subroutines
##

sub add_JS 
{
	print <<EOF;
<script language="javascript">
<!---

function construct_filename ()
{
	if (document.forms[0].no_filename.value != "true") {
		document.forms[0].filename.value = document.forms[0].RAWfilename.value;
		return;
	}
	var instrument = document.forms[0].instrument.value;
	var myFileName = "";
	var initials = document.forms[0].first_initial.value;
	initials += document.forms[0].last_name.value.charAt(0);
	var today = new Date();
	var month = today.getMonth() + 1;  // Month returns 0..11
	var day = today.getDate();
	
	if (month < 10) {
		myFileName += "0";
	}
	myFileName += month;
	if (day < 10) {
		myFileName += "0";
	}
	myFileName += day;

	myFileName += instrument;
	myFileName += initials.charAt(0) + initials.charAt(initials.length - 1);
	myFileName += document.forms[0].sample_name.value;
	document.forms[0].filename.value = myFileName;
	
	
}

function sniff_submit()
{

	var myradio = document.forms[0].EXPRESS;
	for (i = 0; i < myradio.length; i++) {
		if (myradio[i].checked) {
			level = myradio[i].value;
			break;
		}
	}
	if (level == "run_VUDTA" && document.forms[0].comments.value == "game") {
		tgwin = open ("","TG_Win","height=280,width=250");
		tgwin.document.writeln ("<HTML><HEAD><TITLE>Java Tetris game</TITLE></HEAD><BASE HREF=www.stern.nyu.edu/~lc16/bin/tetris/><\!Usage:><Applet code=Tetris.class Width=220 Height=240><Param Name=Row Value=14>	<Param Name=Col Value=6>	<Param Name=Sound Value=TRUE>	<Param name=BackColor value=0>	<Param name=BorderColor value=25021>	<Param name=TextColor value=65535>	<Param name=BorderImg value=border.gif>	<Param name=BorderImgH value=10>	</Applet>");
		tgwin.focus();
		return;
	}
	if (level != "SEQUEST") {
		var run_sequest = confirm("Do you want sniffer to run Sequest?");
		if (run_sequest) {
			for (i = 0; i < myradio.length; i++) {
				if (myradio[i].value == "SEQUEST") {
					myradio[i].checked = "true";
					break;
				}
			}
		}
	}	
	document.forms[0].WriteSniff.value = "yes";
	document.forms[0].submit();
}

function toggle_display(src,target)
{
	if (src.checked) {
		target.innerHTML = "";
	} else {
		target.innerHTML = "Dir Extension: <input name=\\"DirExt\\" type=text size=10 value=\\"_\\">";
	}
}

onLoad=construct_filename();

-->
</script>
EOF
}


sub get_sniffs {
	my @rawlist;

	opendir (CURRENT, "$weblcqdir");
	my @allfiles = grep /$sniff_extension$/, readdir CURRENT;
	closedir CURRENT;
	foreach $file (@allfiles) {
		push (@rawlist, $weblcqdir . "/" . $file);
	}

	# Sort by the age of the file using a Schwartzian Transform... 
	@rawlist = 
		map { $_->[0] }
		sort { $a->[1] <=> $b->[1] or $a->[2] cmp $b->[2]}
		map { [ $_, -M, lc ] } @rawlist;

	return @rawlist 
}	

#Sort function from protocols.pl

sub byage {
#print "sorting function: comparing $a and $b<br>\n";
	-M("$a") <=> -M("$b")
		or
	lc($a) cmp lc($b);
}



sub output_form
{
	my ($sampleID, $firstInit, $lastName, $runName, $comments, $oper, $runNumber, $instrument) = @_;

## get default form values from microchem_var.pl
$checked{$DEFS_DIRSETUP{"After Setup"}} = " CHECKED";
$checked{"run_ionquest"} = ($DEFS_DIRSETUP{"Run IonQuest"} eq "yes") ? " checked" : "";

	my $SequestPagesLinksStr;

	
	$SequestPagesLinksStr .= "Clone-A-Dir:cloneadir.pl&Delete-A-Dir:deleteadir.pl&Rename-A-Dir:renameadir.pl&Sequest directories:/sequest/";		
	&MS_pages_header("Setup Sequest Directory", "$mycolor", "tabvalues=none&$SequestPagesLinksStr");


$downarrow = <<EOF;
<tr>
	<td></td>
	<td align=right height=9><img src="$webimagedir/downarrow.gif"><img src="$webimagedir/singpix.gif" width=17 height=9></td>
	<td colspan=3 height=9></td>
</tr>
EOF


print <<EOF;

<FORM method="GET" action="$ourname">
<INPUT TYPE=hidden NAME="running" VALUE="running">
<INPUT TYPE=hidden NAME="instrument" VALUE="$instrument">
<INPUT TYPE=hidden NAME="RAWfilename" VALUE="$FORM{"sample_name_new"}">
<INPUT TYPE=hidden NAME="no_filename" VALUE="$FORM{"no_name"}">
<INPUT TYPE=hidden NAME="WriteSniff" Value="">


<!-- Note: we are using nested, unbordered tables -->

<TABLE WIDTH=100%><TR><TD WIDTH=35% VALIGN=top>

<TABLE CELLSPACING=2 CELLPADDING=0 BORDER=0>
<tr>
<td align=right><span class="smallheading">Sample ID: </span></td>
EOF

	print <<EOF;
<td colspan=2><input name="sample_id" type="text" maxlength=25 value='$sampleID'>
EOF


print <<EOF;
</tr>
<TR>
<TD align=right nowrap><span class="smallheading">User First Initial: </span></TD>
<TD colspan=2><INPUT name="first_initial" type="text" maxlength=1 value='$firstInit'></TD>
</TR>

<TR>
<TD align=right nowrap><span class="smallheading">User Last Name: </span></TD>
<TD colspan=2><INPUT name="last_name" type="text" maxlength=50 value='$lastName'></TD>
</TR>

<TR>
<TD align=right nowrap><span class="smallheading">Sample (Run) Name: </span></TD>
<TD colspan=2><INPUT name="sample_name" type="text" maxlength=25 value='$runName'></TD>
</TR>
EOF



print <<EOF;
<TR><TD HEIGHT=10>&nbsp;</TD></TR>
<TR valign=middle>
<TD ALIGN=right nowrap valign=middle><span class="smallheading">Operator: </span></TD>
<TD valign=middle><input name="operator" type="text" maxlength=4 size=3 value='$oper'></td><td><a href="javascript:validate_setup(document.forms[0].LcqFile.value)"><image src="$webimagedir/SubmitButtonForSetup.gif" border=0 valign=bottom></a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
</TR>

</table>

</TD><TD WIDTH=65% VALIGN=top>

<table>
<tr>
	<td valign=top align=right><span class="smallheading">Comments:</span></td>
	<td valign=top><tt><TEXTAREA NAME="comments" COLS=55 ROWS=6 MAXSIZE=240 WRAP>$comments</TEXTAREA></tt></td>
</tr>
</table>

</TD></TR>

</TABLE>

<p>

<script language="Javascript">
<!--
	function check_csd_buttons() 
	{
		var express_route;
		var myradio = document.forms[0].EXPRESS;

		for (i = 0; i < myradio.length; i++) {
			if (myradio[i].checked) {
				express_route = myradio[i].value;
				break;
			}
		}
		if ((express_route == "none") || (express_route == "CREATEDTA") || (express_route == "run_CREATEDTA") || (express_route == "CSD") || (express_route == "run_CSD"))
			document.forms[0].run_CSD.checked = false;
		if (express_route == "run_CSD")
			document.forms[0].run_CSD.checked = true;
	}

	function check_ionquest_buttons() 
	{
		var express_route;
		var myradio = document.forms[0].EXPRESS;

		for (i = 0; i < myradio.length; i++) {
			if (myradio[i].checked) {
				express_route = myradio[i].value;
				break;
			}
		}
		if ((express_route == "none") || (express_route == "CREATEDTA") || (express_route == "run_CREATEDTA") || (express_route == "CSD") || (express_route == "run_CSD") || (express_route == "IONQUEST"))
			document.forms[0].run_ionquest.checked = false;
		if (express_route == "run_IONQUEST")
			document.forms[0].run_ionquest.checked = true;
	}
	function validate_setup(raw_file)
	{
		if (raw_file == "DoSniff") {
			alert ("Please select an appropriate RAW file from the list");
			return;
		}
		if (raw_file == "none") {
			var myradio = document.forms[0].EXPRESS;

			for (i = 0; i < myradio.length; i++) {
				if (myradio[i].checked) {
					level = myradio[i].value;
					break;
				}
			}
			if (level != "none" && level != "CREATEDTA") {
				alert ("Please select an appropriate RAW file from the list");
				return;
			}
		}
		document.forms[0].submit();
	}
//-->
</script>

<table cellpadding=0 cellspacing=0 border=0>
<tr>
	<td width=20>&nbsp;</td>
	<td></td>
	<td align=center><b><span style="color:$mycolor">&nbsp;Goto&nbsp;</span></b></td>
	<td align=center><b><span style="color:$mycolor">&nbsp;Run&nbsp;</span></b></td>
	<td></td>
</tr>
<tr><td><img src="$webimagedir/singpix.gif" height=8></td></tr>
<tr>
	<td width=10>&nbsp;</td>
	<td align=right><b><span style="color:$mycolor">Confirm Setup</span></b></td>
	<td align=center></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="none"$checked{'Setup Confirmation'} onClick="document.forms[0].run_ionquest.checked=false;document.forms[0].run_CSD.checked=false"></td>
	<td></td>
</tr>
$downarrow
<tr>
	<td></td>
	<td align=right><b><span style="color:$mycolor">Create DTA</span></b></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="CREATEDTA"$checked{"Goto Create Dta"} onClick="document.forms[0].run_ionquest.checked=false;document.forms[0].run_CSD.checked=false"></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="run_CREATEDTA"$checked{"Run Create Dta"} onClick="document.forms[0].run_ionquest.checked=false;document.forms[0].run_CSD.checked=false"></td>
	<td nowrap>
<span class="smallheading">
<span style="color:#000000">
EOF
# make datafile dropbox:
&get_lcqdat;
print ("Datafile: <span class=dropbox><SELECT name=\"LcqFile\">\n");
print qq(<OPTION VALUE="none"> \n);
if ($FORM{"no_name"} eq "true" && !defined $selected_file) {
	$doSniffChecked = " SELECTED";
}


foreach $lcq (@ordered_lcq_names) {
	print ("<OPTION ");
	print (" VALUE = \"$lcq\"");
	my $lcq_without_ext = &RemoveExtension($lcq);
	$lcq_without_ext =~ tr/a-z/A-Z/;
	if ($selected_file eq $lcq_without_ext) {
		print " SELECTED";
	}
	print (">");
	print ("$lcq</OPTION>");
	print ("\n");
}
print ("</SELECT></span>\n");
print <<EOF;
&nbsp;Start scan: <INPUT TYPE="text" NAME="CREATEDTA:StartScan" VALUE="$DEFS_CREATE_DTAS{'Start scan'}" SIZE=4 MAXLENGTH=4>
&nbsp;End scan: <INPUT TYPE="text" NAME="CREATEDTA:EndScan"	VALUE="$DEFS_CREATE_DTAS{'End scan'}" SIZE=4 MAXLENGTH=4>
&nbsp;Min Ions: <INPUT NAME="CREATEDTA:MinIons" VALUE="$DEFS_CREATE_DTAS{'Min. # Ions'}" SIZE=2>
&nbsp;Min TIC: <INPUT NAME="CREATEDTA:MinTIC" VALUE="$DEFS_CREATE_DTAS{'Minimum TIC'}" SIZE=6>
</span>
</span>
	</td>
</tr>
$downarrow
<tr>
	<td></td>
	<td align=right><b><span style="color:$mycolor">ZSA</span></b></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="CSD"$checked{"Goto CSD"} onClick="document.forms[0].run_ionquest.checked=false;document.forms[0].run_CSD.checked=false"></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="run_CSD"$checked{"Run CSD"} onClick="document.forms[0].run_ionquest.checked=false;document.forms[0].run_CSD.checked=true"></td>
	<td nowrap>
<span style="color:#000000">
<span class="smallheading">Run?</span> <INPUT TYPE=CHECKBOX NAME="run_CSD" VALUE="1" onClick="check_csd_buttons()" $checked{"IonQuest Run Button"}>&nbsp;&nbsp;
</tr>
$downarrow
<tr>
	<td></td>
	<td align=right><b><span style="color:$mycolor">IonQuest</span></b></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="IONQUEST"$checked{"Goto IonQuest"} onClick="document.forms[0].run_ionquest.checked=false;document.forms[0].run_CSD.checked=true"></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="run_IONQUEST"$checked{"Run IonQuest"} onClick="document.forms[0].run_ionquest.checked=true;document.forms[0].run_CSD.checked=true"></td>
	<td nowrap>
<span style="color:#000000">
<span class="smallheading">Run?</span> <INPUT TYPE=CHECKBOX NAME="run_ionquest" VALUE="1" onClick="check_ionquest_buttons()" $checked{"IonQuest Run Button"}>&nbsp;&nbsp;
<span class="smallheading">Delete</span>
EOF
# make checkboxes for references directories
if (@REFDIRS) {
	foreach $refdir (@REFDIRS) {
		print qq(<span class="smallheading">$REFDIR_LABELS{$refdir}?</span> <input type=checkbox name="refdir" value="$refdir" value=1 checked>&nbsp;);
	}
}
# make dropbox for match percentage:
print qq(&nbsp;&nbsp;&nbsp;&nbsp;<span class="smallheading">% match to delete:</span> <span class=dropbox><SELECT NAME="IONQUEST:percentage">);
foreach $i (0..100) {
	$selected = ($i eq $DEFS_IONQUEST{"Percent Match Threshold"}) ? " selected" : "";
	print qq(<option value="$i"$selected>$i%);
}
print "</SELECT></span>&nbsp;";
print <<EOF;
</span>
<span class="smallheading">Mark matches to previous run?</span><INPUT TYPE=CHECKBOX NAME="iq_prev_run" CHECKED></span>

	</td>
</tr>
$downarrow
<tr>
	<td></td>
	<td align=right><b><span style="color:$mycolor">VuDTA</span></b></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="VUDTA"$checked{"Goto VuDTA"} onClick="document.forms[0].run_ionquest.checked=true;document.forms[0].run_CSD.checked=true"></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="run_VUDTA"$checked{"Run VuDTA"} onClick="document.forms[0].run_ionquest.checked=true;document.forms[0].run_CSD.checked=true"></td>
<td align=right>
EOF

print <<EOF;
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
</tr>
$downarrow
<tr>
	<td></td>
	<td align=right><b><span style="color:$mycolor">RunSequest</span></b></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="SEQLAUNCH"$checked{"Goto RunSequest"} onClick="document.forms[0].run_ionquest.checked=true;document.forms[0].run_CSD.checked=true"></td>
	<td align=center><INPUT TYPE=RADIO NAME="EXPRESS" VALUE="SEQUEST"$checked{"Run Sequest"} onClick="document.forms[0].run_ionquest.checked=true;document.forms[0].run_CSD.checked=true"></td>
	<td nowrap>
<span style="color:#000000">
EOF
# make database dropbox:
&get_dbases;
opendir (DBDIR, $dbdir) || &error("can't open $dbdir");
@other_db_names = grep {/fasta.hdr$/} readdir (DBDIR);
closedir DBDIR;

@all_db_names = sort {lc($a) cmp lc($b)} (@ordered_db_names, @other_db_names);

print "<span class=\"smallheading\">Database:</span> ";
print qq(<span class=dropbox><SELECT NAME="SEQLAUNCH:Database">);
print qq(<OPTION VALUE="sequestparams">Use sequest.params default);
foreach $db (@all_db_names) {
	print qq(<OPTION VALUE="$db");
	print " SELECTED" if ($db eq $DEFAULT_DB);
	print ">$db\n";
}
print "</SELECT></span>\n";

# get enzyme info from default seqparam file
open (DEFPARAMS, "<$default_seqparams") || &error("cannot open default sequest.params file");
@lines = <DEFPARAMS>;
close (DEFPARAMS);
$whole = join ("", @lines);
($seq_info,$enz_info) = split(/\[SEQUEST_ENZYME_INFO\]*.\n/, $whole);
($def_enzyme) = ($seq_info =~ /^enzyme_number\s*=\s*(.*?)(\s*;|\s*$)/m);
$enz_sel[$def_enzyme] = " SELECTED";
@enz_lines = ($enz_info =~ /^\d.*$/mg);
foreach (@enz_lines)
{
	($num,$name,$offset,$sites,$no_sites) = split(/\s+/);
	chop($num);  # remove trailing dot
	$def_name[$num] = $name;
	$def_offset[$num] = $offset;
	$def_sites[$num] = $sites;
	$def_no_sites[$num] = $no_sites;
}
# make enzyme dropbox:
print "&nbsp;<span class=\"smallheading\">Enzyme:</span> ";
print qq(<span class=dropbox><SELECT NAME="SEQLAUNCH:Enzyme">);
print "<OPTION $enz_sel[0] VALUE=0>None";
foreach $num (1..$#def_name)
{
	$name = $def_name[$num];
	$name =~ s/_/ /g;
	print "<OPTION $enz_sel[$num] VALUE=$num>$name\n";
}
print "</SELECT></span>\n";
if ($multiple_sequest_hosts) {
	print "&nbsp;<span class=\"smallheading\">Server:</span> <span class=dropbox><SELECT NAME=\"SEQLAUNCH:runOnServer\">\n";
	print "<OPTION>$ENV{'COMPUTERNAME'}";
	foreach $seqserver (@seqservers) {
		print ("<OPTION" . (($seqserver eq $DEFAULT_SEQSERVER) ? " SELECTED" : "") . ">$seqserver");
	}
	print "</SELECT></span>\n";
	print qq(&nbsp;<input type=checkbox name="SEQLAUNCH:Q_immunity" value=1 checked><span class="smallheading">Q immunity</span>\n);
}


print <<EOF;
</span>

	</td>
</tr>
</table>
<BR><hr>
EOF


print <<EOF;
</FORM>
EOF



exit 0;

}




sub error {
  &MS_pages_header ("Directory Setup Results", "$mycolor"); 
  print "<br><hr><br>";
  print ("<h2>Error</h2><div>", join ("<br>", @_), "\n");
  print "</div></body></html>\n";
  exit 1;
}


## need to close database connection before exiting (just in case, anyway).
sub db_error {
  my $db = shift;
  &MS_pages_header ("Directory Setup Results", "$mycolor"); 
  print ("<h2>Error</h2><div>", join ("<BR>", @_), "<BR><BR>", $db->Error(), "<BR>");
  $db->Close();
  print "</div></body></html>\n";
  exit 1;
}



sub bulldozer {

	&MS_pages_header ("Directory Setup In Progress...", "$mycolor");
	print "<br><hr><br>\n";

	$level = $express;
	$run_ionquest = $FORM{"run_ionquest"};

	chdir ("$seqdir/$dir");

	select(STDOUT);
	$| = 1;
	print "<div>\n";

	# run create_dta.pl, without automatically running IonQuest (bulldozer does that manually later)

	@CREATEDTA_ARGS = grep /^CREATEDTA:/, keys %FORM;
	foreach (@CREATEDTA_ARGS,"operator") {
		(my $key = $_) =~ s/^CREATEDTA://;
		$CREATEDTA_ARGS{$key} = $FORM{$_};
	}
	$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string(%CREATEDTA_ARGS, "directory" => $dir, "LcqFile" => $FORM{"LcqFile"}, "create_datafiles" => 1, "run_ionquest" => 0);

	if ($level eq "run_CREATEDTA") {
		&bulldozer_redirect("$create_dta?" . $ENV{"QUERY_STRING_INTRACHEM"});
	}

	# run create_dta in background and wait for it to finish
	print "Running Create DTA...<br>\n";
	$procobj = &run_silently_in_background("$create_dta_cmdline USE_QUERY_STRING_INTRACHEM");
	until ($procobj->Wait(1000)) {
		print "." or &abort($procobj);
	}
	$num_dta_sets = &count_dta_sets($dir);
	print "Done.  $num_dta_sets DTA-sets created.<br>\n";

	# go to the csd page if requested
	$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("operator" => $operator);
	if ($level eq "CSD") {
		&bulldozer_redirect("$determine_charge?" . $ENV{"QUERY_STRING_INTRACHEM"});
	}


	### Run CombIon always for the time
	$old_num_dta_sets = $num_dta_sets;
	print "Running CombIon...<br>\n";
	$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string(directory => $dir,
														algorithm => "ionquest",
														ionquest_threshold => "42",
														precursor_tolerance => "4.0",
														combine => "combine_and_delete",
														check_with_muquest => "yes",
														ionquest_retest => "48",
														muquest_retest_threshold => "1.7");
	$procobj = &run_silently_in_background("$dta_combiner_cmdline USE_QUERY_STRING_INTRACHEM");
	until ($procobj->Wait(1000)) {
		print "." or &abort($procobj);
	}

	$num_dta_sets = &count_dta_sets($dir);
	$num_dta_sets_deleted = $old_num_dta_sets - $num_dta_sets;
	print "Done.  $num_dta_sets_deleted DTA-sets deleted.<br>\n";
	# End of CombIon


	# if called for, run charge state determination in the background
	if($run_CSD){
		print "Running ZSA...<br>\n";
		$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("directory" => $dir, "operator" => $operator);
		$procobj = &run_silently_in_background("$determine_charge_cmdline USE_QUERY_STRING_INTRACHEM");
		until ($procobj->Wait(1000)) {
			print "." or &abort($procobj);
		}
		print "Done.<BR>\n";
	}

	### Always run CorrectIon ###
	print "Running CorrectIon...<br>";
	$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("directory" => $dir, "MakeChanges" => "yes");
	
	$procobj = &run_silently_in_background("$correctmhplus_cmdline USE_QUERY_STRING_INTRACHEM");
	until ($procobj->Wait(1000)) {
		print "." or &abort($procobj);
	}
	print "Done.<BR>\n";

	# if called for, run IonQuest
	$refdirs = $FORM{"refdir"};
	@refdirs = ($refdirs =~ /,/) ? split(/,\s*/,$refdirs) : $refdirs;

	@IONQUEST_ARGS = grep /^IONQUEST:/, keys %FORM;
	foreach (@IONQUEST_ARGS) {
		(my $key = $_) =~ s/^IONQUEST://;
		$IONQUEST_ARGS{$key} = $FORM{$_};
	}

	if ($level eq "IONQUEST") {
		$url = "$webionquest?" . &make_query_string(%IONQUEST_ARGS, "directory" => $dir, "refdir" => $refdirs[0]);
		&bulldozer_redirect($url);
		exit;
	}


	if ($run_ionquest) {
		foreach $refdir (@refdirs) {
			$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string(%IONQUEST_ARGS,"directory"=>$dir,"refdir"=>$refdir,"compare"=>1,"delete_matches"=>1);

			# run ionquest in background and wait for it to finish
			$old_num_dta_sets = $num_dta_sets;
			print "Running IonQuest with refdir=$refdir...<br>\n";
			$procobj = &run_silently_in_background("$ionquest USE_QUERY_STRING_INTRACHEM");
			until ($procobj->Wait(1000)) {
				print "." or &abort($procobj);
			}
			$num_dta_sets = &count_dta_sets($dir);
			$num_dta_sets_deleted = $old_num_dta_sets - $num_dta_sets;
			print "Done.  $num_dta_sets_deleted DTA-sets deleted.<br>\n";
		}
	}


	if ($level eq "run_IONQUEST") {
		&bulldozer_redirect("$viewinfo?directory=$dir");
	} elsif ($level eq "VUDTA") {
		&bulldozer_redirect("$VuDTA?def_dir=$dir");
	} elsif ($level eq "run_VUDTA") {
		&bulldozer_redirect("$VuDTA?directory=$dir&labels=checked&show=show");
	}




	@SEQLAUNCH_ARGS = grep /^SEQLAUNCH:/, keys %FORM;
	foreach (@SEQLAUNCH_ARGS,"operator") {
		(my $key = $_) =~ s/^SEQLAUNCH://;
		$SEQLAUNCH_ARGS{$key} = $FORM{$_};
	}

	if ($level eq "SEQLAUNCH") {
		$url = "$seqlaunch?" . &make_query_string(%SEQLAUNCH_ARGS, "directory" => $dir);
		&bulldozer_redirect($url);
	} elsif ($level eq "SEQUEST") {

		## run sequest by running sequest_launcher.pl
		$url = "$seqlaunch?" . &make_query_string(%SEQLAUNCH_ARGS, "directory" => $dir, "running" => 1, "default" => "$dirname/sequest.params");
		&bulldozer_redirect($url);

		exit;

	}

}

sub bulldozer_redirect {
	print <<EOF;
One moment please...
</div>
<script language="Javascript">
<!--
	function goto_url()
	{
		location.replace("$_[0]");
	}
	onload=goto_url;
//-->
</script>
</body></html>
EOF
	exit;
}



sub bulldozer_error {

	print join("<br>",@_);
	print "</div></body></html>\n";

	exit 1;

}


sub abort {

	my $probobj = shift;
	$procobj->Kill(1);
	exit 1;

}


sub look_up {
  my $sampleID = $FORM{"sample_id"};
  my $runName = $FORM{"sample_name_new"};
  my $comments = $FORM{"comments_new"};
  my $oper = $FORM{"oper_new"};
  my $runNumber = $FORM{"run_number"};
  my $instrument = $FORM{"instrument"};   ## added 06/28/00 by pm
  # open the database UcBeDb.mdb, using the DSN we are going to set up.
  my $db = new Win32::ODBC("UcBeDb");
  my ($sql, $err, $firstName, $lastName);
  my (@runNames, @comments);

  if(!$db) {
	&error ("could not open connection to the database!");
  }


  $sql = "SELECT Users.FirstName, Users.LastName "
	   . "FROM Samples INNER JOIN Users On Samples.UserID=Users.UserID "
	   . "WHERE Samples.SampleID=$sampleID";

  if(($err = $db->Sql($sql))) { &db_error ($db, "$err"); }
	
  # this select should return at most one value.
  if(!$db->FetchRow()) 		{ &db_error ($db, "No records with that sample id exist"); }

  ($firstName, $lastName) = $db->Data("FirstName", "LastName");
  $firstName = substr($firstName, 0, 1);

  $db->Close();
  &output_form($sampleID, $firstName, $lastName, $runName, $comments, $oper, $runNumber, $instrument);
}

sub sniff_lookup {

  my (%data_hash);

  open (DATA, $FORM{"sniff_file"}) || error("Could not read sniff file"); 
  while (<DATA>) {
	  chomp;
	  if (/^([^:]*):(.*)$/) {
	 	  $data_hash{$1} = $2;
  	  }
  }

  close DATA;
  if ($data_hash{"WhatToDo"} eq "RunSequest") {
	$checked{"Run Sequest"} = " CHECKED";
	$checked{"IonQuest Run Button"} = " CHECKED";
  }

  my $sampleID = $data_hash{"SampleID"};
  my $runName = $data_hash{"Sample"};
  my $comments = $data_hash{"Comments"};
  my $oper = $data_hash{"operator"};
  my $runNumber = $data_hash{"RunNumber"};
  my $instrument = $data_hash{"instrument"};
  my $lastName = $data_hash{"LastName"};
  my $firstName = $data_hash{"Initial"};

  &output_form($sampleID, $firstName, $lastName, $runName, $comments, $oper, $runNumber, $instrument);
}