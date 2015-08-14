#!/usr/local/bin/perl
#-------------------------------------
#	Ionladder
#	(C)1999 Harvard University
#	
#	W. S. Lane/C. M. Wendl/M.S.C. Hemond/G. M. Matev
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


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

#diminishing/accentuating factor for tryptic sequences (ending in K, R, H, N, or Q)
$dim_factor = $DEFS_IONLADDER{"Diminishing Factor For b-ions"};
$acc_factor = $DEFS_IONLADDER{"Accentuating Factor For y-ions"};

#a hash containing the default accentuating factors for some amino acids
%acc_some = (P => $DEFS_IONLADDER{"P"}, H => $DEFS_IONLADDER{"H"}, G => $DEFS_IONLADDER{"G"},
			 E => $DEFS_IONLADDER{"E"}, D => $DEFS_IONLADDER{"D"});

#loss of water intensity amplification for Nterm E, D
$water_amplify = $DEFS_IONLADDER{"Water Amplification"};

#loss of ammonia intensity amplification for Nterm Q, N
$ammonia_amplify = $DEFS_IONLADDER{"Ammonia Amplification"};

#neutral loss defaults hash
%default_NL_vals = (NL_val1 => "", NL_val2 => "", NL_val3 => "", NL_val4 => "", NL_val5 => "",
					NL_val6 => "", NL_val7 => "", NL_val8 => "", NL_val9 => "", NL_val10 => "");

#neutral loss default positions
%default_NL_res = (NL_res1 => "", NL_res2 => "", NL_res3 => "", NL_res4 => "", NL_res5 => "",
				   NL_res6 => "", NL_res7 => "", NL_res8 => "", NL_res9 => "", NL_res10 => "");

#have to do it the hard way since values() does not preserve the order
my @popup_def_array = ();
foreach (1..10)
{
	#enclose string in to avoid Javascript errors later
	push @popup_def_array, '"'.$default_NL_res{"NL_res$_"}.'"';
	push @popup_def_array, '"'.$default_NL_vals{"NL_val$_"}.'"';
}

push @popup_def_array, $acc_some{'D'}, $acc_some{'E'}, $acc_some{'G'}, $acc_some{'H'}, $acc_some{'P'};

#setup popup defaults string
$popup_defaults = join (', ', @popup_def_array);

$popup_defaults=~ s/\A, /"", /;
$popup_defaults=~ s/, ,/,"" ,/g;
$popup_defaults=~ s/, ,/,"" ,/g;

#########################################################################
# this section sets relevant program defaults
$default_file_ext = $DEFS_IONLADDER{"File Extension"};

# this section reads user input data from the page and sets defaults if none is found
&cgi_receive();

# The default directory is the temporary directory. 
$dir = $FORM{"directory"};


$DEF_CYS_ALKYL = $DEFS_IONLADDER{'Cys'};
$FORM{'cys_alkyl'} = $DEF_CYS_ALKYL if(!exists $FORM{'cys_alkyl'});
$sel{"cys_alkyl=$FORM{'cys_alkyl'}"} = ' SELECTED';

#take care of cystenes
$cys_alkyl = $FORM{"cys_alkyl"};
$cys_alkyl = $default_cys if ((!exists $cys_alkyl_add_mono{$cys_alkyl}) or (!exists $cys_alkyl_add_average{$cys_alkyl}));
$Mono_mass{"C"}+= $cys_alkyl_add_mono{$cys_alkyl};
$Average_mass{"C"}+= $cys_alkyl_add_average{$cys_alkyl};


$charge_state = $FORM{"charge_state"};
$charge_state = $DEFS_IONLADDER{"Charge State"} unless (defined $charge_state);
%charge_states = ();
foreach (1..10)
{
	$charge_states{"$_"} = 1 if $FORM{"box$_"};
}

$filename = $FORM{"filename"};

if (defined $filename and &GetExtension($filename) eq $default_file_ext)
{
	$filename = &RemoveExtension($filename);
}

$file_ext = $FORM{"extension"};
$file_ext = $default_file_ext unless (defined $file_ext);

#assemble complete filename(includes chargestate right before extension)
$filename .= '.'.$file_ext if (defined $filename);

$sequence = $FORM{"sequence"};
$sequence= uc($sequence) if (defined $sequence);

@add_mass = split(",", $FORM{"addmass"});
@mod_locations = split(",", $FORM{"modlocations"});

#if no mass addition specified do nothing even if modifications locations are specified
@mod_locations = () if (not defined $add_mass[0]);

#if no mod locations are specified do nothing even if mass addition(s) is specified
@add_mass = () if (not defined $mod_locations[0]);

my %additions = &setup_additions(\@add_mass, \@mod_locations);

my @loss_mass = ();
my @loss_locations = ();

foreach (1..10)
{
	my ($NL_val, $NL_res) = ($FORM{"NL_val$_"}, $FORM{"NL_res$_"});
	if (not ($NL_val == "" or $NL_res == ""))
	{
		push (@loss_mass, $NL_val);
		push (@loss_locations, $NL_res);
	}
}

my %losses = &setup_losses(\@loss_mass, \@loss_locations);

#compute actual masses of each aminoacid after additions
@aug_masses = &compute_aug_residues($sequence, \%additions, \%losses);


$MHplus = $FORM{"MHplus"};

#calculate the mass of the unknown part of the sequence (remainder) if appropriate
#this only happens when the user enters an experimental value for MH+
#then we have: remainder = Mexper. - [Msequence]+
$seq_MHplus = &mhplus($sequence, %additions);
$remainder = $MHplus - $seq_MHplus if (defined $MHplus);

#ion trap cut off computations
$low_cut_value = $FORM{"low_cut_value"};
$low_cut_value = 0 unless (defined $low_cut_value);
$high_cut_mass = $FORM{"high_cut_value"};

$precursor = &precursor($charge_state, $seq_MHplus);
#calculate cut-off mass
$low_cut_mass = $precursor * ($low_cut_value / 100);

#get which types of ions, including losses of H2O ans NH3
%ion_series = ();
$ion_series{"a"} = 1 if $FORM{'a_ions'};
$ion_series{"b"} = 1 if $FORM{'b_ions'};
$ion_series{"y"} = 1 if $FORM{'y_ions'};
$ion_series{"h2o"} = 1 if $FORM{'h2o'};
$ion_series{"nh3"} = 1 if $FORM{'nh3'};

#a useful variable
my $has_iontype = ($FORM{'a_ions'} or $FORM{'b_ions'} or $FORM{'y_ions'});

# print the page header in microchem style
&MS_pages_header("Ionladder", "888888","tabvalues=Ion-Ladder&Ion-Ladder:\"cgi-bin/ionladder.pl\"&Spectrum-Import:\"spectrum_import.pl\"");
#print "<P><HR><div>\n";

# if there was no directory or no sequence defined, simply print out the interface page and exit
if (!defined $dir) {
	&output_form;
}

###ERROR CHECKING SECTION
if (not defined $sequence)
{
	print "<B><span style=\"color:#FF0000\">You must enter a sequence in the sequence field!!!</span></B><BR><BR>\n";
	&output_form;
}

if (not ($#add_mass == $#mod_locations or $#add_mass == 0))
{
	print "<B><span style=\"color:#FF0000\">Multiple addmasses require equal number of Res#!!!</span></B>\n";
	print "<BR><BR>\n";
	&output_form;
}

if (not $has_iontype)
{
	print "<B><span style=\"color:#FF0000\">You must select an ion type!!!</span></B>\n";
	print "<BR><BR>\n";
	&output_form;
}


if (defined $MHplus and $MHplus < $seq_MHplus)
{
	print "<B><span style=\"color:#FF0000\">Invalid MH+!!!</span></B>\n";
	print "<BR><BR>\n";
	&output_form;
}

######################UGLY HACK###########################

#WILL NEED AUTOINDEXING MECHANISM TO ALLOW FOR MULTIPLE USERS
$default_filename  =  "ionladder_".&get_unique_timeID.".".($charge_state).".dta";


##################################################################
# Some final preprocessing (formating, small computations, etc.)
##################################################################

#build displayions link
#First create a hash with all relevant parameters

#create a map of the sequence. Each add mass is reflected as an integer coresponding to
#the order of the add mass. Otherwise (no mass addition) we just have a 0.
#NOTE: currently only two mass aditions suported. Might be changed lated
my $seq_map = &precision(0, 0, length($sequence), 0);
$seq_map.='0' if ($remainder);

#display ions currently supports ONLY 2 mass modifications
my $mass1 = 0;
my $mass2 = 0;

for ($i=1; $i <= length($sequence); $i++)
{
	my $diff = $additions{$i} - $losses{$i};

	if ($diff != 0)
	{
		if ($mass1 == 0)
		{
			$mass1 = $diff;
		}
		elsif ($mass2 == 0 && $diff != $mass1)
		{
			$mass2 = $diff;
		}

		if ($diff == $mass1)
		{
			substr($seq_map, $i - 1, 1) = 1;
			next;
		}

		if ($diff == $mass2)
		{
			substr($seq_map, $i - 1, 1) = 2;
			next;
		}
	}
}

my %pre_query = ();

$pre_query{"DSite"} = $seq_map;

#one or more addmasses
$pre_query{"DMass1"}=$mass1 if ($mass1 != 0);
$pre_query{"DMass1"}=0 if (not defined $add_mass[0]);

#two addmasses
$pre_query{"DMass2"}=$mass2 if ($mass2 != 0);


my $query_seq = $sequence;
$query_seq.='J' if ($remainder);
$pre_query{"Pep"} = "$query_seq";

$pre_query{"MassJ"} = $remainder if ($remainder);

#if specified filename, then set the path to this file; else specify the path to the default file
if (defined $filename) {
	$pre_query{"Dta"} = ($dir ne $tempdir) ? "$seqdir/$dir/$filename" : "$tempdir/$filename"; 
}
else {
	$pre_query{"Dta"} = ($dir ne $tempdir) ? "$seqdir/$dir/$default_filename" : "$tempdir/$default_filename";	
}

#setup ion series parameter
my $i_series = "000000000";
substr($i_series, 0, 1) = 1 if ($ion_series{"a"});
substr($i_series, 1, 1) = 1 if ($ion_series{"b"});
substr($i_series, 7, 1) = 1 if ($ion_series{"y"});

$pre_query{"ISeries"} = $i_series;
$pre_query{"numaxis"} = 1;
$pre_query{"MassType"} = 1;

#make the query string
my $displayions_params = make_query_string(%pre_query);

#set $view variable 
$view = (defined $filename) ? $filename : $default_filename;

#print the theoretical spectrum data 

#$view is the filename to be displayed
print "<BR>"; 
print "<div><span style='color:#8a2be2'><B>Theoretical spectrum:&nbsp;&nbsp;</B></span>";
print "<A HREF=\"$displayions?$displayions_params\" target=\"_blank\">$view</A><BR></div>\n";
	

#include full path in filenames
$filename = ($dir ne $tempdir) ? "$seqdir/$dir/$filename" : "$tempdir/$filename";
$default_filename =  "$tempdir/$default_filename";

# print the parameters  for the user's knowledge
#some basic statistics for the user's information
$add_mass_display = join(', ',@add_mass);
$mod_locations_display = join(', ',@mod_locations);
$loss_mass_display = join(', ', @loss_mass);
$loss_locations_display = join(', ',@loss_locations);

#update acc_some hash since might be changed by the user in the Advanced optons popup
foreach (keys %acc_some)
{
	my $temp = "$_"."_amp";
	$acc_some{$_} = $FORM{$temp};
}

print <<EOP;
	<HR>
	<TABLE WIDTH=600 CELLSPACING=0 CELLPADDING=0 NOWRAP>
	<TR>
		<TD COLSPAN=3 align=left><span style="color:#8a2be2"><B>Ion Ladder Parameters:</B></span></TD>
	</TR>
	<TR>
		<TD><span class="smallheading">Sequence:&nbsp;</span>$sequence</TD>
	</TR>
	<TR>
		<TD><span class="smallheading">Charge&nbsp;State:&nbsp;</span>$charge_state</TD>
		<TD><span class="smallheading">Cys:&nbsp;</span>$cys_alkyl</TD>
	</TR>
	<TR>
		<TD><span class="smallheading">Calculated&nbsp;MH+:&nbsp;</span>$seq_MHplus</TD>
EOP

print " 		<TD><span class=\"smallheading\">Experimental&nbsp;MH+:&nbsp;</span>$MHplus</TD>\n" if (defined $MHplus);

my $r_precursor = precision ($precursor, 5);

print <<EOP;
		<TD><span class="smallheading">Precursor:&nbsp;</span>$r_precursor</TD>
	</TR>
	<TR>
		<TD><span class="smallheading">Cutoff Percentage:&nbsp;</span>$low_cut_value%</TD>
		<TD><span class="smallheading">Low Cutoff Mass:&nbsp;</span>$low_cut_mass</TD>
		<TD><span class="smallheading">High Cutoff Mass:&nbsp;</span>$high_cut_mass</TD>
	</TR>
EOP

if (@add_mass)
{
	print <<EOP;
	<TR>
		<TD><span class="smallheading">Mass Addition(s):&nbsp;</span>$add_mass_display</TD>
		<TD><span class="smallheading">At Residue(s):&nbsp;</span>$mod_locations_display</TD>
	</TR>
EOP
}

if (@loss_mass)
{
	print <<EOP;
	<TR>
		<TD><span class="smallheading">Neutral Loss(es):&nbsp;</span>$loss_mass_display</TD>
		<TD><span class="smallheading">At Residue(s):&nbsp;</span>$loss_locations_display</TD>
	</TR>
EOP
}
print "</TABLE>\n";

my $delim_count = 0;
print "<div><span class=\"smallheading\">Iontypes:</span>" if (%ion_series);
if ($ion_series{"a"})
{
	print "&nbsp;a-ions";
	$delim_count++;
}
if ($ion_series{"b"})
{	
	print "," if ($delim_count > 0);
	print "&nbsp;b-ions";
	$delim_count++;
}
if ($ion_series{"y"})
{	
	print "," if ($delim_count > 0);
	print "&nbsp;y-ions";
	$delim_count++;
}
if ($ion_series{"h2o"})
{	
	print "," if ($delim_count > 0);
	print "&nbsp;loss of H<SUB>2</SUB>O";
	$delim_count++;
}
if ($ion_series{"nh3"})
{	
	print "," if ($delim_count > 0);
	print "&nbsp;loss of HN<SUB>3</SUB></div>";
	$delim_count++;
}

#pack parameters in a hash for convenience
%ladder_params = ();
$ladder_params{"sequence"} = $sequence;
$ladder_params{"charge_state"} = $charge_state;
$ladder_params{"low_cut_mass"} = $low_cut_mass;
$ladder_params{"high_cut_mass"} = $high_cut_mass;
$ladder_params{"write_file"} = $write_file;
$ladder_params{"tempfile"} = $default_filename;
$ladder_params{"filename"} = $filename;
$ladder_params{"remainder"} = $remainder;
$ladder_params{"mhplus"} = $seq_MHplus;

#write the appropriate files. Output as a webpage as well.
&make_ladder(\%ladder_params, \%ion_series,\%charge_states, \@aug_masses);
exit;

###############################################################
# This sub prints the default page
###############################################################
sub output_form {
	#arrange checkbox defaults
	$checked{"a_ions"} = ($DEFS_IONLADDER{"a-ions"} eq "yes") ? " checked" : "";
	$checked{"b_ions"} = ($DEFS_IONLADDER{"b-ions"} eq "yes") ? " checked" : "";
	$checked{"y_ions"} = ($DEFS_IONLADDER{"y-ions"} eq "yes") ? " checked" : "";
	$checked{"h2o"} = ($DEFS_IONLADDER{"H<SUB>2</SUB>O-ions"} eq "yes") ? " checked" : "";
	$checked{'nh3'} = ($DEFS_IONLADDER{"NH<SUB>3</SUB>-ions"} eq "yes") ? " checked" : "";
	$sel{"charge_state=$DEFS_IONLADDER{'Charge State'}"} = " SELECTED ";

	#other defaults
	my $l_cutoff = $DEFS_IONLADDER{'Low Mass Cutoff (percentage of precursor)'} if (!defined $l_cutoff);
	my $h_cutoff = $DEFS_IONLADDER{'High Mass Cutoff'} if (!defined $h_cutoff);
	
	print <<EOP;
	<script language="Javascript">
	<!--

	var NLconf;
	var am_height = (navigator.appName == "Microsoft Internet Explorer") ? 420 : 490;

	//default textbox values
	var defaults = new Array($popup_defaults);

	//The function below works only with IE4 and above
	function CreateFilename(){
		var sequence=document.forms[0].sequence.value;
		var charge=document.forms[0].charge_state.selectedIndex+1;
		var fName=sequence+"."+"0000.0000."+charge+".dta";
		document.forms[0].filename.value=fName;
		
		return false;
	}
	
	function DisableBoxes()
	{
		var charge_boxes = new Array(document.forms[0].box1,
				document.forms[0].box2, 
				document.forms[0].box3, 
				document.forms[0].box4, 
				document.forms[0].box5, 
				document.forms[0].box6, 
				document.forms[0].box7, 
				document.forms[0].box8, 
				document.forms[0].box9, 
				document.forms[0].box10);

		var max_val = document.forms[0].charge_state.selectedIndex + 1;

		for (var i = 1; i <=10; i++)
		{
			if (i > max_val)
			{
				if (isIE)
					charge_boxes[i - 1].disabled = true;
					
				charge_boxes[i - 1].checked = false;
			}
			else
			{
				if (isIE)
					charge_boxes[i - 1].disabled = false;
	
				charge_boxes[i - 1].checked = true;
			}			
		}						
	}
	
	//ClickBox is only needed for Netscape since in IE 
	//we can completely DISABLE of the checkboxes
	function ClickBox(name, box)
	{
		var max_val = document.forms[0].charge_state.selectedIndex + 1;

		if (isNN)
		{
			max_val = Math.abs(max_val);
		
			if (name.substr(3) > max_val)		
			{
				//alert ("Gotta be kidding me");
				box.checked = false;
			}
		}
	}

	// retrieve form values from hidden values in main window
	// and display in pop-up window
	//borrowed from SEQUEST_LAUNCHER.PL
	function getValues(popup)
	{
		 window.status = "Retrieving values, please wait...";

		for (i = 0; i < popup.document.forms[0].elements.length; i++)
		{
			if (popup.document.forms[0].elements[i]) {
				elt = popup.document.forms[0].elements[i];
				if (document.forms[0][elt.name]) {
					if (elt.type == "checkbox")
						elt.checked = (document.forms[0][elt.name].value == elt.value);
					else
						elt.value = document.forms[0][elt.name].value;
				}
			}
		}

		window.status = "Done";
	}

	// opposite of getValues(): save values from form elements in a pop-up window
	// as values of hidden elements in main window
	//borrowed from SEQUEST_LAUNCHER.PL
	function saveValues(popup)
	{
		window.status = "Saving values, please wait...";
		for (i = 0; i < popup.document.forms[0].elements.length; i++)
		{
			elt = popup.document.forms[0].elements[i];
			if (document.forms[0][elt.name]) 
			{
				if (elt.type == "checkbox")
					document.forms[0][elt.name].value = (elt.checked) ? elt.value : 0;
				else
					document.forms[0][elt.name].value = elt.value;
			}
		}
		window.status = "Done";
	}
			
	//reset all text fields to empty
	function resetAll(popup)
	{
		window.status = "Reseting values, please wait...";
		
		for (i = 0; i < popup.document.forms[0].elements.length; i++)
		{
			var elt = popup.document.forms[0].elements[i];

			if (elt.type != "button")
				popup.document.forms[0].elements[i].value = defaults[i];
		}
		
		window.status = "Done";
	}

	//The following function makes sure that the H2O or NH3 checkboxes are not checked
	//when noe of the ion-type boxes is checked
	function checkIonTypeBoxes()
	{
		var form = document.forms[0];

		if (form.h2o.checked == true || form.nh3.checked ==true)
		{
			if (form.b_ions.checked != true && form.y_ions.checked != true)
			{
				form.h2o.checked = false;
				form.nh3.checked = false;
			}
		}
	}

	function checkSpecialBoxes(box)
	{
		var form = document.forms[0];

		if (box.checked == true && form.b_ions.checked != true && form.y_ions.checked != true)
		{
			box.checked = false;
			alert('You must check at least one of the b-ion or y-ion boxes');
		}
	}


	//Create a popup window for editing neutral loss parameters
	//Code based on a similar function addmass_open in SEQUEST_LAUNCHER.PL
	function NLconfigure_open(sequence)
	{	
		if (sequence == "")
		{
			alert ('You need to enter a sequence in the sequence field!!!');
			document.forms[0].sequence.focus();
			document.forms[0].sequence.select();

			return;
		}

		if (NLconf && !NLconf.closed)
			NLconf.focus();
		else
		{
			NLconf = open("","NLconf_$unique_window_name","width=360,height=" + am_height + ",resizable,screenX=20,screenY=20");
			NLconf.document.open();
			NLconf.document.writeln('<HTML>');
			NLconf.document.writeln('<!-- this is the code for the add-mass pop-up window -->');
			NLconf.document.writeln('');
			NLconf.document.writeln('<HEAD><TITLE>Advanced Options Setup</TITLE>$stylesheet_javascript</HEAD>');
			NLconf.document.writeln('');
			NLconf.document.writeln('<BODY BGCOLOR=#FFFFFF>');
			NLconf.document.writeln('<CENTER>');
			NLconf.document.writeln('');
			NLconf.document.writeln('<CENTER><H4>Sequence: ' + sequence.toUpperCase() + '</H4></CENTER>');
			NLconf.document.writeln('');
			NLconf.document.writeln('<FORM>');
			NLconf.document.writeln('');
			NLconf.document.writeln('<TABLE WIDTH=240>');
			NLconf.document.writeln('<TR>');
			NLconf.document.writeln('	<TD>');
			NLconf.document.writeln('		<TABLE WIDTH=160 COLS=2>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center COLSPAN=2><span class="smallheading">Neutral Losses</span></TD>');
			NLconf.document.writeln('		</TR>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center><span class="smallheading">Residue#</span></TD>');
			NLconf.document.writeln('			<TD ALIGN=center><span class="smallheading">NL</span></TD>');
			NLconf.document.writeln('		</TR>');

			for (i = 1; i <= 10; i++)
			{
				NLconf.document.writeln('		<TR>');
				NLconf.document.writeln('			<TD ALIGN=center><INPUT TYPE="text" NAME="NL_res' + i + '" MAXLENGTH=7 SIZE=7 value="" onBlur="checkRes(this)" onFocus="this.select(); opener.status = this.value;"></TD>');
				NLconf.document.writeln('			<TD ALIGN=center><INPUT TYPE="text" NAME="NL_val' + i + '" MAXLENGTH=7 SIZE=7 value="" onBlur="checkVal(this)"></TD>');
				NLconf.document.writeln('		</TR>');
			}
			NLconf.document.writeln('		</TABLE>');
			NLconf.document.writeln('	</TD>');
			NLconf.document.writeln('	<TD VALIGN=top>');
			NLconf.document.writeln('		<TABLE WIDTH=120 COLS=2>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center COLSPAN=2 NOWRAP><span class="smallheading">Intensity</span></TD>');
			NLconf.document.writeln('		</TR>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center COLSPAN=2 NOWRAP><span class="smallheading">Amplification</span></TD>');
			NLconf.document.writeln('		</TR>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center><span class="smallheading">D&nbsp;</span><INPUT TYPE="text" NAME="D_amp" MAXLENGTH=7 SIZE=7 value=""></TD>');
			NLconf.document.writeln('		</TR>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center><span class="smallheading">E&nbsp;</span><INPUT TYPE="text" NAME="E_amp" MAXLENGTH=7 SIZE=7 value=""></TD>');
			NLconf.document.writeln('		</TR>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center><span class="smallheading">G&nbsp;</span><INPUT TYPE="text" NAME="G_amp" MAXLENGTH=7 SIZE=7 value=""></TD>');
			NLconf.document.writeln('		</TR>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center><span class="smallheading">H&nbsp;</span><INPUT TYPE="text" NAME="H_amp" MAXLENGTH=7 SIZE=7 value=""></TD>');
			NLconf.document.writeln('		</TR>');
			NLconf.document.writeln('		<TR>');
			NLconf.document.writeln('			<TD ALIGN=center><span class="smallheading">P&nbsp;</span><INPUT TYPE="text" NAME="P_amp" MAXLENGTH=7 SIZE=7 value=""></TD>');
			NLconf.document.writeln('		</TR>');
			

			
			NLconf.document.writeln('		</TABLE>');
			NLconf.document.writeln('	</TD>');
			NLconf.document.writeln('</TR>');
			NLconf.document.writeln('</TABLE>');

			NLconf.document.writeln('<BR>');
			NLconf.document.writeln('<TABLE ALIGN=center WIDTH=240>');
			NLconf.document.writeln('<TR>');
			NLconf.document.writeln('	<TD ALIGN=center><INPUT TYPE=button class="button" NAME="saveNLconf" VALUE=" Save" onClick="opener.saveValues(self); self.close()"></TD>');
			NLconf.document.writeln('	<TD ALIGN=center><INPUT TYPE=button class="button" NAME="cancelNLconf" VALUE="Cancel" onClick="self.close()"></TD>');
			NLconf.document.writeln('	<TD ALIGN=center><INPUT TYPE=button class="button" NAME="resetNLconf" VALUE="Reset" onClick="opener.resetAll(self)"></TD>');
			NLconf.document.writeln('</TR>');
			NLconf.document.writeln('</TABLE>');
			NLconf.document.writeln('');
			NLconf.document.writeln('<SCRIPT language="Javascript">');
			NLconf.document.writeln('	var seqLength=' + sequence.length + ';');
			NLconf.document.writeln('');
			NLconf.document.writeln('	//array to keep the res# boxes corresponding to val boxes with the same index');
			NLconf.document.writeln('	var corrRes = new Array(self.document.forms[0].NL_res1,');
			NLconf.document.writeln('				self.document.forms[0].NL_res2,');
			NLconf.document.writeln('				self.document.forms[0].NL_res3,');
			NLconf.document.writeln('				self.document.forms[0].NL_res4,');
			NLconf.document.writeln('				self.document.forms[0].NL_res5,');
			NLconf.document.writeln('				self.document.forms[0].NL_res6,');
			NLconf.document.writeln('				self.document.forms[0].NL_res7,');
			NLconf.document.writeln('				self.document.forms[0].NL_res8,');
			NLconf.document.writeln('				self.document.forms[0].NL_res9,');
			NLconf.document.writeln('				self.document.forms[0].NL_res10);');
			NLconf.document.writeln('');
			NLconf.document.writeln('	//array to keep the val boxes corresponding to res# boxes with the same index');
			NLconf.document.writeln('	var corrVal = new Array(self.document.forms[0].NL_val1,');
			NLconf.document.writeln('				self.document.forms[0].NL_val2,');
			NLconf.document.writeln('				self.document.forms[0].NL_val3,');
			NLconf.document.writeln('				self.document.forms[0].NL_val4,');
			NLconf.document.writeln('				self.document.forms[0].NL_val5,');
			NLconf.document.writeln('				self.document.forms[0].NL_val6,');
			NLconf.document.writeln('				self.document.forms[0].NL_val7,');
			NLconf.document.writeln('				self.document.forms[0].NL_val8,');
			NLconf.document.writeln('				self.document.forms[0].NL_val9,');
			NLconf.document.writeln('				self.document.forms[0].NL_val10);');
			NLconf.document.writeln('');
			NLconf.document.writeln('	//one-indexed array for masses at each residue');
			NLconf.document.writeln('	var resMass = new Array(seqLength + 1);');
			NLconf.document.writeln('	for (i=1; i <= seqLength; i++)');
			NLconf.document.writeln('	{');
			NLconf.document.writeln('		resMass[i] = opener.document.forms[0].massAt' + i +';');
			NLconf.document.writeln('	}');
			NLconf.document.writeln('');
			NLconf.document.writeln('	function checkRes(whichone)');
			NLconf.document.writeln('	{');
			NLconf.document.writeln('		if (whichone.value != "" &&  whichone.value > seqLength)');
			NLconf.document.writeln('		{');
			NLconf.document.writeln('			alert(\\\'The max residue is ' + sequence.length + '\\\');');
			NLconf.document.writeln('			//whichone.value = "";');
			NLconf.document.writeln('			whichone.focus();');
			NLconf.document.writeln('			whichone.select();');
			NLconf.document.writeln('		}');
			NLconf.document.writeln('');
			NLconf.document.writeln('		if (whichone.value != "" && whichone.value <= 0)');
			NLconf.document.writeln('		{');
			NLconf.document.writeln('			alert(\\\'The min residue is 1\\\');');
			NLconf.document.writeln('			whichone.value = "";');
			NLconf.document.writeln('		}');
			NLconf.document.writeln('');
			NLconf.document.writeln('		if (whichone.value != "" && corrVal[whichone.name.substr(6) - 1].value != "")');
			NLconf.document.writeln('			checkVal(corrVal[whichone.name.substr(6) - 1]);');
			NLconf.document.writeln('	}');
			NLconf.document.writeln('	function checkVal(whichone)');
			NLconf.document.writeln('	{');
			NLconf.document.writeln('		if (whichone.value != "" && corrRes[whichone.name.substr(6) - 1].value == "")');
			NLconf.document.writeln('		{');
			NLconf.document.writeln('			alert(\\\'You need to enter a residue number!!!\\\');');
			NLconf.document.writeln('			corrRes[whichone.name.substr(6) - 1].focus();');
			NLconf.document.writeln('			corrRes[whichone.name.substr(6) - 1].select();');
			NLconf.document.writeln('		}');
			NLconf.document.writeln('	}');
			NLconf.document.writeln('</SCRIPT>');
			NLconf.document.writeln('</FORM>');	
			NLconf.document.writeln('</CENTER>');
			NLconf.document.writeln('</BODY>');
			NLconf.document.writeln('</HTML>');

			getValues(NLconf);

			NLconf.document.close();
		}
	}

	//The function below leaves the cursor in the sequence textbox
	//This function is to be called when the form has loaded
	function cursorInSequence()
	{
		document.forms[0].sequence.focus();
		document.forms[0].sequence.select();
	}

	//-->
	</script>
	
EOP

	print "<FORM ACTION=\"$ourname\" METHOD=get>\n\n";

	# get the directories to put in the dropdown
	&get_alldirs;
	
	#begin table
	print "<TABLE>\n";

	# print the sequence text box
	# this sends a {name, value} pair with name="sequence" and value equal to whatever the user types in
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">Sequence:&nbsp;</span></TD>
		<TD align=left><input type=text width=10 maxlength=30 name="sequence" value=""></TD>
	</TR>
EOP

	# print the charge state dropdown
	# this sends a {name, value} pair with name="charge_state" and value = 1, 2, 3, 4,  ...., 10
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">Charge&nbsp;State:&nbsp;</span></TD>
		<TD>
			<TABLE cellspacing=0 cellpadding=0>
				<TD align=left><span class=dropbox><select name="charge_state" onChange='DisableBoxes()'>
		
EOP
	
	foreach(1..10) 
	{ 
		print <<EOL;
				<option $sel{"charge_state=$_"}>$_
EOL
	}

	for (1..10)
	{
	
		print <<EOP;
				</select ></span></TD>
				<TD align=right><span class="smallheading">&nbsp;$_</span></TD>
				<TD align=left><input type=checkbox name="box$_" onClick='ClickBox("box$_", this)'></TD>
EOP
	}

	print <<EOP;
			</TABLE>
		</TD>
	</TR>
EOP

	# print the MH+ input text box
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">MH+:&nbsp;</span></TD>
		<TD align=left><input type=text width=7 maxlength=10 name="MHplus"></TD>
	</TR>
EOP

	
	# print the ion series checkboxes
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">Ion&nbsp;Series:&nbsp;</span></TD>
		<TD>
			<TABLE cellspacing=0 cellpadding=0>
				<TD align=left><span class="smallheading">a</span><input type=checkbox name="a_ions" value="true" $checked{'a_ions'} onClick="checkIonTypeBoxes()"></TD>
				<TD align=left><span class="smallheading">&nbsp;&nbsp;&nbsp;b</span><input type=checkbox name="b_ions" value="true" $checked{'b_ions'} onClick="checkIonTypeBoxes()"></TD>
				<TD align=left><span class="smallheading">&nbsp;&nbsp;&nbsp;y</span><input type=checkbox name="y_ions" value="true" $checked{'y_ions'} onClick="checkIonTypeBoxes()"></TD>
				<TD align=left><span class="smallheading">H<sub>2</sub>O</span><input type=checkbox name="h2o" value="true" $checked{'h2o'} onClick="checkSpecialBoxes(this)"></TD>
				<TD align=left><span class="smallheading">NH<sub>3</sub></span><input type=checkbox name="nh3" value="true" $checked{'nh3'} onClick="checkSpecialBoxes(this)"></TD>
			</TABLE>
		</TD>
	</TR>
EOP
	
	#print text boxes for dealing with mass addition
	print <<EOP;
	<TR>		
		<TD align=right><span class="smallheading">Add Mass:&nbsp;</span></TD>
		<TD>
			<TABLE cellspacing=0 cellpadding = 0>
				<TD align=left><INPUT name="addmass" value="" size=5></TD>
				<TD align=right><span class="smallheading">&nbsp;&nbsp;Residue\#:&nbsp;&nbsp;</span></TD>
				<TD align=left><INPUT name="modlocations" value="" size=5></TD>
				<TD><span class=smallheading>&nbsp;&nbsp;Cys:&nbsp;</span></TD>
				<TD>
					<span class="dropbox"><select name="cys_alkyl">
					<option$sel{"cys_alkyl=free"}>free	
					<option$sel{"cys_alkyl=CAM"}>CAM
					<option$sel{"cys_alkyl=CM"}>CM
					<option$sel{"cys_alkyl=PE"}>PE
					<option$sel{"cys_alkyl=PA"}>PA
					<option$sel{"cys_alkyl=CAP"}>CAP</select></span>
				</TD>
			</TABLE>
		</TD>
	</TR>
EOP


	#prints low mass cut of text field
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">Low Mass Cutoff:&nbsp;</TD>
		<TD>
			<TABLE cellspacing=0 cellpadding = 0>	
				<TD align=left><INPUT name="low_cut_value" maxsize=5 size=5 value=$l_cutoff><span class="smallheading">&nbsp;%</span></span></TD>
				<TD align=right><span class="smallheading">&nbsp;&nbsp;High&nbsp;Mass&nbsp;Cutoff:&nbsp;</span></TD>
				<TD align=left><INPUT name="high_cut_value" maxsize=5 size=5 value=$h_cutoff><span class="smallheading">&nbsp;m/z</span></span></TD>
			</TABLE>
		</TD>
	</TR>
EOP

	#advanced options button
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">Advanced Options:&nbsp;</span></TD>
		<TD><input type=button class="button" value="Configure" onClick="NLconfigure_open(document.forms[0].sequence.value)"></TD>
	</TR>
EOP

	print <<EOP;
	<TR></TR>
	<TR>
		<TD>
			<input type=submit class=button value="Create">&nbsp;&nbsp;<A HREF="$webhelpdir/help_$ourshortname.html">Help</A>
		</TD>
		<TD></TD>
	</TR>
	<TR></TR>
EOP

	# print the filename text box
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">DTA Filename:&nbsp;</span></TD>
		<TD align=left><INPUT type=text size=45 width=20 maxlength=40 name="filename"></TD>
		<TD align=left><INPUT TYPE=SUBMIT class="button" value="Create DTA filename" onClick="return CreateFilename()"></TD>
	</TR>
EOP

	#print the dropdown box with dirs. Put a blank on top so that the user does not write in the wrong dir
	print <<EOP;
	<TR>
		<TD align=right><span class="smallheading">In Directory:&nbsp;</span></TD>
		<TD align=left><span class=dropbox><SELECT name="directory">
			<option value ="$tempdir">Temporary Directory
EOP

	foreach $dir (@ordered_names) 
	{
		print <<EOL;
			<option value="$dir">$fancyname{$dir}
EOL
	}
	print <<EOP;
		</SELECT></span></TD></TR>
	</TABLE>
EOP
	
	#create hidden elements to store the values from/for the popup window
	foreach (1..10)
	{
		print <<EOP;
			<input type="hidden" name="NL_res$_" value=$default_NL_res{"NL_res$_"}>
			<input type="hidden" name="NL_val$_" value=$default_NL_vals{"NL_val$_"}>
EOP
	}

	foreach (D, E, G, H, P)
	{
		my $temp = $_.'_amp';
	print <<EOP;
		<input type="hidden" name=$temp value=$acc_some{$_}>
EOP
	}


print <<EOP;
	</form>	
	<SCRIPT language="Javascript">
	<!--
		DisableBoxes();
		onload=cursorInSequence;
		
	//-->
	</SCRIPT>
	</body>
	</html>
EOP
	exit 0;
}


#This sub calculates the data for the ion ladder
sub make_ladder
{
	#arguments: %ladder_params
	
	my ($ladder_params, $ion_series, $charge_states, $aug_masses) = @_;

	#unpack params
	my $seq = $ladder_params{"sequence"};
	my $charge_state = $ladder_params{"charge_state"};
	my $filename = $ladder_params{"filename"};
	my $default_filename = $ladder_params{"tempfile"};
	my $low_cut_mass = $ladder_params{"low_cut_mass"};
	my $high_cut_mass = $ladder_params{"high_cut_mass"};
	my $remainder = $ladder_params{"remainder"};
	my $mhplus = $ladder_params{"mhplus"};


	$seq =~ s/[^A-Z]//g;

	#flag for amplified water loss intensity
	my $h2o_amplify = (($seq=~/(E|D).*/) ? 1 : 0);
	
	
	#flag for amplified ammonia intensity
	my $nh3_amplify = (($seq=~/(Q|N).*/) ? 1 : 0);
	
	#flag for tryptic sequences
	my $is_tryptic = (($seq =~/.*(K|R|H|N|Q)/) ? 1 : 0);

	my $seq_length = length($seq);

	# split the seq into residues
	@residues = &residues($seq);

	my @acc_some_additions = ();

	#precompute a map,@acc_some_additions, of the y-ions which has intensity enforcement data for y-ions 
	#ending in AAs from the hash %acc_some
	foreach (@residues)
	{
		if (defined $acc_some{$_})
		{
			push (@acc_some_additions, $acc_some{$_});
		}
		else
		{
			push (@acc_some_additions, 0);
		}
	}

	#correct ordering
	@acc_some_additions = reverse @acc_some_additions;

	my @b1_mass_ladder = &generate_b1_ladder($remainder, @$aug_masses) if ($ion_series{"b"} or $ion_series{"a"});
	my @y1_mass_ladder = &generate_y1_ladder($remainder, @$aug_masses) if ($ion_series{"y"});

	my @all_b_ladders = ();
	my @all_y_ladders = ();
	
	#build charge1 ladders
	if ($charge_states{"1"} == 1)
	{
		$all_b_ladders[1] = [@b1_mass_ladder];
		$all_y_ladders[1] = [@y1_mass_ladder];
	}

	#build additional charge ladders if the user has checked the appropriate boxes
	foreach(2..10)
	{
		if ($charge_states{$_} == 1)
		{
			$all_b_ladders[$_] = [ &generate_higher_ladder($_, @b1_mass_ladder) ] if ($ion_series{"b"} or $ion_series{"a"});
			$all_y_ladders[$_] = [ &generate_higher_ladder($_, @y1_mass_ladder) ] if ($ion_series{"y"});
		}
	}
	
	# write the .sta
	# make a (mass, value) hash of the b-ions or/and the a-ions
	foreach (1..10)
	{	
		my $charge = $_;
		
		if ($charge_states{$_} == 1 and ($ion_series{"b"} or $ion_series{"a"}))
		{
			foreach(@{$all_b_ladders[$_]})
			{	
				#handle b-ions
				if ($ion_series{"b"})
				{
					$peaks{$_}+= 50.0;
					$peaks{$_}-= $dim_factor if ($is_tryptic);
					$peaks{$_ + $Mono_mass{'Hydrogen'}/$charge} += 25.0;
					#$peaks{$_ - $Mono_mass{'Hydrogen'}} += 25.0;		# considering more realistic isotope spread for ion trap
					$peaks{$_ - $Mono_mass{'Water'}/$charge} += (10.0 + $h20_amplify*$water_amplify) if ($ion_series{'h2o'});
					$peaks{$_ - $Mono_mass{'Ammonia'}/$charge} += (10.0 + $nh3_amplify*$ammonia_amplify)if ($ion_series{'nh3'});
				}
				#handle a-ions
				$peaks{$_ - 28/$charge} += 3.0 if ($ion_series{"a"});
			}
		}
	
		# make a (mass, value) hash of the y-ions
	    if ($charge_states{$_} == 1 and $ion_series{"y"})
		{	
			foreach(@{$all_y_ladders[$_]})
			{
				
				$peaks{$_}+= (50.0 + (shift @acc_some_additions)); 
				$peaks{$_}+= $acc_factor if ($is_tryptic);
				$peaks{$_ + $Mono_mass{'Hydrogen'}/$charge} += 25.0;
			#	$peaks{$_ - $Mono_mass{'Hydrogen'}} += 25.0;	# considering more realistic isotope spread for ion trap
				$peaks{$_ - $Mono_mass{'Water'}/$charge} += 10.0 if ($ion_series{'h2o'});
				$peaks{$_ - $Mono_mass{'Ammonia'}/$charge} += 10.0 if ($ion_series{'nh3'});
				
			}
		}
	}

	#gausian envelope calculation 
	my %gaussian_peaks = ();

	my $max_intensity = &find_max_intensity(%peaks);
	my @sorted_keys = sort {$a <=> $b} keys %peaks;
	my $max_mz = pop @sorted_keys;

	foreach (keys (%peaks))
	{
		#print "$_<br>";
		$gaussian_peaks{$_} = $peaks{$_}*&gaussian($max_intensity, $max_mz, $_)/$max_intensity;
	}

	&write_sta($default_filename, $filename, $low_cut_mass, $high_cut_mass, $mhplus, $charge_state, %gaussian_peaks);

	}

#######################################
# subroutines (other than &output_form and error handling, see below)

sub compute_aug_residues
{
	#args: %additions, %losses

	#NOTE: %additions, %losses have already been error checked. 
	#		Also single mass addition/loss to multiplpe locations already incorporated in the two hashes
	
	my $seq = shift @_;
	my ($additions, $losses) = @_;
	
	#compute @aug_masses which contains the mass of each aminoacid in the sequence
	#NOTE: @aug_masses includes added masses at the relevant positions
	my $i = 1;
	foreach (&residues($seq))
	{
		push (@aug_masses, ($Mono_mass{$_} + $additions{$i} - $losses{$i}));
		$i++;
	}
	
	return (@aug_masses);
}
	

sub write_sta()
{
	# arguments:
	# $default_filename, $filename, $low_cut_mass, $high_cut_mass, $total_mass, $charge_state, %(mass, value)

	my $default_filename = shift @_;
	my $filename = shift @_;
	my $low_cut_mass = shift @_;
	my $high_cut_mass = shift @_;
	my $pep_mass = shift @_;
	my $charge_state = shift @_;
	my %peaks = @_; 

	#create files by writing less code
	my @files = ($default_filename, $filename);
	
	#always write tempfile and if appropriate other file 
	foreach (@files)
	{
		my $file = $_ if (defined $_);
	
		# open the file
		open STAFILE, ">$file";

		# write the mass
		print STAFILE "$pep_mass $charge_state\n";

		# write the (mass, value) pairs
		foreach(sort { $a <=> $b } keys %peaks)
		{
			if (defined $high_cut_mass)
			{	
				if ($_ >= $low_cut_mass and $_ <= $high_cut_mass)
				{
					print STAFILE "$_ $peaks{$_}\n";
				}
			}
			else
			{
				if ($_ >= $low_cut_mass)
				{
					print STAFILE "$_ $peaks{$_}\n";
				}
			}
		}
	}
	
		#output page;
		#print the teoretical spectrum data; 
		print "<HR>";
		print <<EOP;
			<div><span style="color:#8a2be2"><B>Theoretical Spectrum Data:</B></span></div><BR>
			<TABLE WIDTH=200>
			<TR>
				<TD><span style="color:#8a2be2"><U><I>M/z:</I></U></span></TD>
				<TD><span style="color:#8a2be2"><U><I>Intensity:</I></U></span></TD>
			</TR>
EOP
				
		#print the (mass, value) pairs;
		foreach(sort { $a <=> $b } keys %peaks)
		{
			if (defined $high_cut_mass) {	
				if ($_ >= $low_cut_mass and $_ <= $high_cut_mass) {
					my $temp_mz = precision($_, 5);
					my $temp_intensity = precision($peaks{$_},5);
					print "<TR><TD><span class=smalltext>$temp_mz</span></TD><TD><span class=smalltext>$temp_intensity</span></TD></TR>\n";
				}
			}
			else {
				if ($_ >= $low_cut_mass) {
					my $temp = precision($_, 5);
					my $temp_intensity = precision($peaks{$_},5);
					print "<TR><TD><span class=smalltext>$temp_mz</span></TD><TD><span class=smalltext>$temp_intensity</span></TD></TR>\n";
				}
			}
		}
		print "</tt>\n</TABLE>";
	
}

sub get_sequence
{
	return scalar <STDIN>;
}

sub residues()
{
	# arguments: $sequence
	#returns: @residues
	return split //, shift @_;
}

sub generate_b1_ladder
{
	#arguments: $remainder, @aug_masses
	my $remainder = shift @_;
	### @_ = @aug_masses

	my $mass = $Mono_mass{'Hydrogen'};
	my @b_mass_ladder = ();

	#print "b-ions values:<BR>";
	foreach(@_)
	{
		$mass+= $_;
		push (@b_mass_ladder, $mass);
	}

	#last b ion includes remainder
	#Note: if no remainder we just add 0 to the last one which is fine
	#$b_mass_ladder[$#b_mass_ladder] += $remainder;
	if ($remainder)
	{
		$mass+= $remainder;
		push (@b_mass_ladder, $mass);
	}


	return @b_mass_ladder;
}

sub generate_y1_ladder
{
	#arguments: $remainder, @aug_masses
	my $remainder = shift @_;
	### @_ = @aug_masses

	my $mass = $Mono_mass{'Water'} + $Mono_mass{'Hydrogen'};
	my @y_mass_ladder = ();
	
	if ($remainder)
	{
		$mass += $remainder;
		push (@y_mass_ladder, $mass);
	}

	#print "y-ions values:<BR>";
	foreach(reverse @_)
	{
		$mass+= $_;
		push (@y_mass_ladder, $mass);
		#print "$mass<BR>\n";
	}
	return @y_mass_ladder;
}

sub mhplus
{
	#arguments: $seq, %additions
	my $seq = shift @_;
	my %additions = @_;
	my $mhplus = $Mono_mass{'Water'} + $Mono_mass{'Hydrogen'};

	foreach (values(%additions))
	{
		$mhplus+= $_;
	}
	
	foreach (&residues($seq))
	{
		$mhplus += $Mono_mass{"$_"};
	}

	return $mhplus;
}

sub precursor
{
	#arguments: $charge_state, $mhplus 
	my $charge_state = shift @_;
	my $mhplus = shift @_;

	return ($mhplus - $Mono_mass{'Hydrogen'})/$charge_state + $Mono_mass{'Hydrogen'};
}

sub generate_higher_ladder
{
	#parameters: $charge_state, charge1 ladder
	my $charge_state = shift @_;
	my @charge1_ladder = @_;
	my @higher_ladder = ();

	foreach (@charge1_ladder)
	{
		push (@higher_ladder, ($_ - $Mono_mass{'Hydrogen'})/$charge_state + $Mono_mass{'Hydrogen'});
	}

	return @higher_ladder;
}

sub setup_losses
{
	#parameters: @loss_mass, @loss_locations
	#NOTE: Assumes that error checking has already been performed
	#	   Moreover, @loss_mass and @loss_locations must be of equal length

	my ($loss_mass, $loss_locations) = @_;
	
	my $i = 1;
	foreach (@$loss_locations)
	{
		$losses{"$_"} = $loss_mass[$i - 1];
		$i++;
	}

	return %losses;
}

sub setup_additions
{
	#parameters: @add_mass, @mod_locations
	#NOTE: Assumes that error checking has already been performed.

	my ($add_mass, $mod_locations) = @_;
	my %additions = ();
	
	#just one mass value for all positions
	if ($#add_mass == 0)
	{
		foreach (@$mod_locations)
		{
			$additions{$_} = $add_mass[0];
		}
	}
	
	#multiple mass values. Number of mass values matches number of position. Error checked earlier
	if ($#add_mass > 0)
	{	
		my $i = 1;
		foreach(@$mod_locations)
		{
			$additions{"$_"} =$add_mass[$i - 1];
			$i++;
		}
	}

	return %additions;
}

#this sub finds the max value in a hash
sub find_max_intensity
{
	#arguments: %some_hash
	my %some_hash = @_;
	my @sorted_values = (sort {$a <=> $b} values %some_hash);

	return shift @sorted_values;
}

#this is a simple quadratic function which is needed to shape the theoretical spectrum as a gaussian envelope
sub gaussian
{
	#arguments: $max_intensity, $max_mz, $m/z
	my ($max_intensity, $max_mz, $mz) = @_;

	return 4*(-$max_intensity*$mz*$mz/($max_mz * $max_mz) + ($max_intensity*$mz/$max_mz));
}

	