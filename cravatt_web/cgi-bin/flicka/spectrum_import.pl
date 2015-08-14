#!/usr/local/bin/perl

#-------------------------------------
#	Name of Program,
#	(C)1999 Harvard University
#	
#	Authors Name(s), including Bill (e.g. W. S. Lane/C. M. Wendl/D. P. Jetchev)
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 12/1/00 Dimitar Jetchev
# Last Modified: 03/31/02 Rebecca Dezube


################################################
{
	$0 =~ m!(.*)\\([^\\]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}

&cgi_receive();

&MS_pages_header("Spectrum Import","#C0BA3F","tabvalues=Spectrum-Import&Spectrum-Import:\"cgi-bin/spectrum_import.pl\"&Ion-Ladder:\"ionladder.pl\"");


$dir=$FORM{"directory"};
$name=$FORM{"filename"};
$XCal=$FORM{"XCal_spectrum"};

if (not defined $XCal){
	
	&output_form;
}
elsif (($FORM{"ch_file"} eq "yes") and (not defined $name)){
	
	print "<B><span style=\"color:#FF0000\">You must enter a filename in the filename field!!!</span></B>\n";
	print "<BR><BR>\n";
	&output_form;
	
}
else {
	
	#choose the appropriate directory
	if ($FORM{"ch_file"} eq "yes"){
		if ($dir eq $nodir){
			$dirpath="$tempdir";
			$dir=$tempdir;
		}
		else {
			$dirpath="$seqdir/$dir";
			
		}
	}
	
	
	else {
		$name="spectrum_".&get_unique_timeID.".dta";
		$dirpath="$tempdir";
		$dir=$tempdir;
	}
		&readtext();
}




#######################################
# subroutines (other than &output_form and &error, see below)

sub readtext() {



#copy the content of the textarea to a temporary file
	$file=$name;
	chdir $dirpath or &error("Cannot open the chosen directory. \n");

	open (DTA_FILE, ">$file");
	print (DTA_FILE "$XCal");
	close (DTA_FILE);

#parse the temporary file
	open (DTA_FILE, "<$file");
	

#get the precursor from the data

	$line=<DTA_FILE>;
	while (not $line=~/.*(\s\d.*)\@.*/)
	{
		$line=<DTA_FILE>;
	}

	
	$line=~/.*(\s\d.*)\@.*/;
	$prec=$1;

#start from the line with the actual information for the dta and push all the lines in an array 

	while (not $line=~/Mass/)
	{
		$line=<DTA_FILE>;
	}

	$line=<DTA_FILE>;
			
	
	while ($line=<DTA_FILE>)
	{
		push @dta, $line;
		$m=$line
	}
	
#calculate the default mass
	$m=~/(.*)\s.*/;
	$maxmass=$1; 
	
	close (DTA_FILE);
	
	$round=1;
	while (abs($round-($maxmass/$prec))>=0.5)
	{
		$round++;
	}
	
	$z=$round;
	if (defined $FORM{"charge_state"}){
		$z=$FORM{"charge_state"};
	}
	
		
#Create the DTA file
	open (DTA_FILE, ">$file");
	
	
	
	$MH=($prec-1)*$z+1;
	
	print (DTA_FILE  "$MH $z\n");

	my $TIC = 0;  # compute TIC value to add to lcq_profile.txt

	foreach $line (@dta)
	{
		$linemod=$line;
		$linemod=~ s/\t/ /gis;
		$linemod=~ s/\r//gis;
		my @temp = split ' ', $line;  #get values to write to lcq_profile.txt
		$TIC += $temp[1]; 
		print(DTA_FILE "$linemod");
	}
	close (DTA_FILE);

	
# add entry for dta in lcq_profile.txt if adding dta to directory
# TIC value was computed above, all other values added are 0's

if ($dir ne $tempdir) {

open LCQ, ">>lcq_profile.txt";
$TIC = int $TIC;
# add new entry to array
print (LCQ "$name 0 0 0 0 $TIC $TIC\n");
}



#send query to displayions.exe

my %pre_query = ();

$pre_query{"DSite"} = $seq_map;
$pre_query{"Dta"} = "$dirpath/$file";


#print the output page
	my $displayions_params = make_query_string(%pre_query);
#	print "<div>Click <A HREF=\"$displayions?$displayions_params\">here</A> to view theoretical spectrum for file&nbsp;"; 
	print "<div><span style='color:#8a2be2'><B>Theoretical spectrum:&nbsp;&nbsp;</B></span>";
	print "<A HREF=\"$displayions?$displayions_params\">$file</A><BR></div>\n";	
#appropriate file link

#	if ($dir eq $tempdir)
#	{
#		print "<A HREF=\"$dir/$file\">$file</A><BR>\n";
#	}
#	else
#	{
#		print "<A HREF=\"$webseqdir/$dir/$file\">$file</A> in directory <I>$dir</I><BR></div>\n";
#	}
	
	print "<HR>";

#print the parameters 
	print <<EOP;
	<TABLE WIDTH=600 CELLSPACING=0 CELLPADDING=0 NOWRAP>
	<TR>
		<TD COLSPAN=3 align=left><span style="color:#8a2be2"><B>Parameters:</B></span></TD>
	</TR>
	
	<TR>
		<TD><span class="smallheading">Charge&nbsp;State:&nbsp;</span>$z</TD>
	</TR>
	<TR>
		<TD><span class="smallheading">Calculated&nbsp;MH+:&nbsp;</span>$MH</TD>
EOP

	print <<EOP;
		<TD><span class="smallheading">Precursor:&nbsp;</span>$prec</TD>
	</TR>
	</TABLE>
EOP

#(mass,intensity)

	print <<EOP;
	<HR>
	<div><span style="color:#8a2be2"><B>Theoretical Spectrum Data:</B></span><BR><BR>
	<TABLE WIDTH=200>
			<TR>
				<TD><span style="color:#8a2be2"><U><I>M/z:</I></U></span></TD>
				<TD><span style="color:#8a2be2"><U><I>Intensity:</I></U></span></TD>
			</TR></div>
EOP
	foreach $line (@dta){
		($mass,$intensity)=split(' ',$line); 
		print <<EOP; 
			<TR><TD><span class="smalltext">$mass</span></TD><TD><span class="smalltext">$intensity</span></TD></TR>
EOP
		print ("\n");
	}

}



sub output_form {

	$checked{"check_file"}="CHECKED" if ($DEFS_SPECTRUMIMP{"Write to A DTA File:"} eq "yes");
	$disabled{"$namef"}="DISABLED" if ($DEFS_SPECTRUMIMP{"Write to A DTA File:"} eq "yes");
	$disabled{"$direct"}="DISABLED" if ($DEFS_SPECTRUMIMP{"Write to A DTA File:"} eq "yes");
		
	print <<EOP;
	
	
	
	<FORM ACTION="$ourname" METHOD=POST NAME="form">
EOP

	#get all directories to put in the dropbox;
	&get_alldirs();

	print <<EOP;
	
	
	<TABLE>
	<TR>
	<TD align=left><span class="smallheading">In XCalibur, Export MS/MS data to the Clipboard and then Paste Here:</span></TD>
	
	</TR>
	<TR>
	<TD colspan=2 align=left><TEXTAREA ROWS=15 COLS=80 name="XCal_spectrum"></TEXTAREA></TD>
	</TR>
	</TABLE>
	<TABLE>
	<TR>
		<TD align=left><span class="smallheading">Select&nbsp;A&nbsp;Charge&nbsp;State:&nbsp;</span></TD>
		<TD align=left><span class=dropbox><select name="charge_state">
EOP
	
	print qq(<OPTION VALUE = "1">1);
	print qq(<OPTION VALUE = "2" selected>2);
	
	foreach $z (3..10) {
		
		print qq(<OPTION VALUE = "$z">$z \n);

	}
			
		print <<EOP;
		</select></span>
	
	&nbsp;&nbsp;
	<INPUT type=SUBMIT class=button value="Clear" onClick="return Clear()">
	</TD>
		
	<TD align=right>&nbsp;&nbsp;
			<INPUT TYPE=SUBMIT CLASS=button STYLE="background:#C0BA3F" VALUE="Create">&nbsp;&nbsp<A HREF="$webhelpdir/help_spectrum_import.pl.html">Help</A>
	</TD>
	</TR>
	</TABLE>
	<HR>
	<TABLE>
	<TR>
		<TD>
			<TABLE cellspacing=0 cellpadding=0>
				<TD align=right><input type=checkbox name="ch_file" value="yes"$checked{"check_file"}></TD>
				<TD align=left><span class="smallheading">Write to a DTA file:&nbsp;</span></TD>
			</TABLE>
		</TD>
		<TD align=left><INPUT TYPE=TEXT SIZE=35 maxlength=100 NAME="filename"></TD>
		<TD align=left><INPUT TYPE=SUBMIT class="button" value="Create filename" onClick="return CreateFilename()"></TD>
	</TR>


	<TR>
		<TD align=right><span class="smallheading">In Directory:&nbsp;</span></TD>
		<TD align=left><span class=dropbox><SELECT NAME="directory">
		<option value="$nodir">
			
EOP
	
	foreach $dir (@ordered_names) 
	{
			print qq(<option value="$dir">$fancyname{$dir}\n);

	}
		print <<EOF; 
		</SELECT></span></TD></TR>
	
	<TR><TD><span class="smallheading">&nbsp;</span></TD></TR>
	</TABLE>
		
	</FORM>
EOF

	print <<EOFFORM07;

<SCRIPT LANGUAGE="JavaScript">


function CreateFilename(){
	
	if (document.forms[0].XCal_spectrum.value)
	{
	
		var Charge=document.forms[0].charge_state.value;
		var Data=document.forms[0].XCal_spectrum.value;
		var Exp=/(.*)\.RAW/;
		array=Data.match(Exp);
		var Name=array[1];
		var RegExp=/\#\:.(.*)/;
		scanarray=Data.match(RegExp);
		
		
		if (scanarray[1].match(/-/)) 
		{
			var firstarr=scanarray[1].match(/(.*)-/);
			var secondarr=scanarray[1].match(/-(.*)/);
			var Scan1=firstarr[1];
			var Scan2=secondarr[1];
			var l1=firstarr[1].length;
			for (i=0;i<4-l1;i++) {
				Scan1="0"+Scan1;
			}
			
			var l2=secondarr[1].length;
			for (i=0;i<5-l2;i++) {
				Scan2="0"+Scan2;
			}
		}
		

		else
		{
				var Scan1=scanarray[1];
				var Scan2=Scan1;
				var l1=Scan1.length;
				
				for (i=0;i<5-l1;i++) {
					var	Scan1="0"+Scan1;
					var	Scan2=Scan1;
				}
		}

		var fName=Name+"."+Scan1+"."+Scan2+"."+Charge+"."+"dta";
		
		document.forms[0].filename.value=fName;
	}

	else 
	{
		alert("You must enter the data in the textarea before clicking 'Create Filename'");
	}

	
	return false;

}


function Disable() {
	if (document.forms[0].directory.disabled)
	{
		document.forms[0].directory.disabled=false;
		document.forms[0].filename.disabled=false;
	}
	else {
		document.forms[0].directory.disabled=true;
		document.forms[0].filename.disabled=true;
	}
	
	return false;

}

function Clear() {
	document.forms[0].XCal_spectrum.value="";
	
	return false;
}


</SCRIPT>

EOFFORM07
	
}





#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {
	
	print <<EOF;
	<H3>Error:</H3>
	<div>
	@_
	</div>
	</body></html>
EOF
	exit 0;
}
