#!/usr/local/bin/perl

#-------------------------------------
#	Name of Program,
#	(C)1999-2002 Harvard University
#	
#	W. S. Lane/Unknown)
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
&cgi_receive;
$dir1 = $FORM{"directory"};
$masslist = $FORM{"masslist"};

&MS_pages_header ("MassList", "#527F76");
print "<P><HR><P>\n";

if (!defined $dir1) {
  &output_form;
  exit 0;
}
else{
	&output_mass;
}

sub get_data {
	my $dir = $_[0];
	my ($mhplus, $z, $mass);
		# clear arrays:
	@mhplus = @masses = @dtas = ();
		#  @charges = ();
	opendir (DIR, "$seqdir/$dir");
	@dtas = grep { /\.dta$/ } readdir(DIR);
	closedir DIR;
	foreach $dta (@dtas) {
		open (FILE, "$seqdir/$dir/$dta");
		$mhplus_z = <FILE>;
		close FILE;
	    $dta =~ s!\.dta$!!;
	    chomp $mhplus_z;
		($mhplus, $z) = split (' ', $mhplus_z);
	    $mass = &precision ($mhplus - 1.01, 2, 4, " ");
		$mhplus = &precision ($mhplus, 2, 4, " ");
	    $charge{$dta} = $z;
	    push (@mhplus, $mhplus);
		push (@masses, $mass);
			#    push (@charges, $z);
	}
}
sub output_mass{
&get_data ($FORM{"directory"});
@masses = sort { $a <=> $b } @masses;
@mhplus = sort { $a <=> $b } @mhplus;
$masses = join ("\n", @masses);
$mhplus = join ("\n", @mhplus);
print qq(<TABLE BORDER=0 WIDTH="80%" ALIGN=center><TR>);
print qq(<FORM name=massform>);
if ($masslist == 1){
	print qq(<TD><span class="smallheading">Mass List for :</span>);&print_sample_name($dir1);	
	print qq(<TD><span class="smallheading">Some Mass-Search Links:</span></TR>);
	print qq(<TR><TD><br><tt><textarea name="masslist"rows=10 cols=40>$masses</textarea></tt>);
	print qq(<br>);
	print qq(<span class="smallheading"><br>Select: </span>
			<input type=button class=button value=" All " onClick="SelectAll()">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A href=\"$webhelpdir/help_$ourshortname.html\"><span class="smallheading">Help</span></a></TD>);
}
else{
	print qq(<TD><span class="smallheading">MH+ List for :</span>);&print_sample_name($dir1);
	print qq(<TD><span class="smallheading">Some Mass-Search Links:</span></TR>);
	print qq(<TR><TD><br><tt><textarea name="masslist" rows=10 cols=40 >$mhplus</textarea></tt>);
	print qq(<br>);
	print qq(<span class="smallheading"><br>Select: </span>
			<input type=button class=button value=" All " onClick="SelectAll()">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A href=\"$webhelpdir/help_$ourshortname.html\"><span class="smallheading">Help</span></a></TD>);
}
	
	print qq(<td VALIGN="top"><br>);
	foreach $link (@mass_search_links){
		print qq(<li>$link);
	}
	print qq(</TD></TR></FORM></TABLE>);

print <<SINGLEDIR;
<script language="Javascript">
<!--
	function SelectAll() {
		window.document.massform.masslist.select();
}
	function SelectNone(){
		window.document.massform.masslist.moveStart();
	}
//-->
</script>
SINGLEDIR
}
sub num_ions_cell {
	my ($file1, $file2) = @_;
	my ($num_ions, $url);
	$num_ions = `$compare_dtas Dta=$seqdir/$file1  Dta=$seqdir/$file2`;
	chomp $num_ions;
	$num_ions =~ s!^(\d+%) ions.*!$1!g; # just the percentage
	$url = "$thumbnails?Dta=$seqdir/$file1&amp;Dta=$seqdir/$file2";
	print qq(<TD><tt><a href="$url" target=_blank>$num_ions</a></tt></TD>\n);
}

sub urlize {
	my ($file) = @_;
	my $url;
	$url = $fuzzyions . "?dtafile=$seqdir/$file";
	return $url;
}

sub print_sample_name {
  my ($directory, $padding) = @_;
  
  my (%dir_info) = &get_dir_attribs ($directory);
  $dir_info{"Fancyname"} = &get_fancyname($directory,%dir_info);
 # join together the fancyname, sample ID, and operator name:
  $output = join (" ", map { $dir_info{$_} } ("Fancyname", "SampleID", "Operator") );
  ($dir_info{'Fancyname'}) =~ m/(.*) \((.*)\)/;
  $matched_name = $1;
  $matched_ID = "($2)" if ($2);

  $actualoutput = $output;


  print ("<span class=\"normaltext\">$actualoutput");
  if ($padding) {
    print ("&nbsp;" x ($padding - length ($output)));
  }
  print ("</span>\n");
}

sub output_form {
	
	print <<EOF;
	<FORM ACTION="$ourname" METHOD=POST>
	<TABLE CELLSPACING=4 CELLPADDING=4 BORDER=0>
	<TR><TD align=right><span class="smallheading">	Directory:</span></TD>
	<TD><span class=\"dropbox\"><SELECT name=\"directory\">\n
EOF
	&get_alldirs;
	foreach $dir (@ordered_names){
		print ("<OPTION VALUE = \"$dir\">$fancyname{$dir}\n");
	}
	print <<EOF;
	</SELECT></span>\n</TD></TR>
EOF
	#print ("&nbsp;" x 3);
	#print("<br><br>");	
	#$HelpLink = "<A href=\"$webhelpdir/help_$ourshortname.html\"><span class="smallheading">Help</span></a>&nbsp;";
	$checked{$DEFS_MASSLIST{"List"}} = " CHECKED";
	print <<EOF;
	<TR><TD align=right><span class="smallheading">List:</span></TD>
   	<TD><INPUT TYPE=RADIO NAME="masslist" VALUE=1 $checked{"Mass"}>Mass &nbsp;&nbsp; 
	<INPUT TYPE=RADIO NAME="masslist" VALUE=0 $checked{"MH+"}>MH+</TD></TR>
	<TR><TD align=right>&nbsp;</TD>
	<TD><INPUT TYPE=SUBMIT CLASS="button" VALUE=" List ">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A href=\"$webhelpdir/help_$ourshortname.html\"><span class="smallheading">Help</span></a></TD>
	</TR>
	</TABLE></FORM>
EOF
}

