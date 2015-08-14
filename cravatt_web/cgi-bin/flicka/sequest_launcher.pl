#!/usr/local/bin/perl

#-------------------------------------
#	Sequest Launcher,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


## sequest_launcher.pl

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
	require "html_include.pl";
	require "html_bio_include.pl";
	require "seqstatus_include.pl"
}
################################################
require "seqcomm_include.pl" if ($multiple_sequest_hosts);

$helpfile = "$webhelpdir/help_$ourshortname.html";

&cgi_receive();

# set all essential variables, based on CGI input and/or sequest.params

# input from default visible form
$operator = $FORM{"operator"};
$operator =~ tr/A-Z/a-z/;
$dir = $FORM{"directory"};
$db = $FORM{"Database"};
$seconddb = (defined $FORM{"secondDatabase"} and $FORM{"secondDatabase"} ne "none") ? $FORM{"secondDatabase"} : "";
$enzyme = $FORM{"Enzyme"};
$continue_unfinished = $FORM{"continue_unfinished"};
$continue_different_params = ($FORM{"continue_different_params"} || 0);
$runOnServer = (defined $FORM{"runOnServer"}) ? $FORM{"runOnServer"} : ($multiple_sequest_hosts ? $DEFAULT_SEQSERVER : $ENV{"COMPUTERNAME"});
$nuc_read_frame = $FORM{"nuc_read_frame"};
$is_mono_parent = $FORM{"MonoAvg_par"};
$is_mono_fragment = $is_mono_parent;	# either MONO/MONO or AVG/AVG, no mixed
$show_frag_ions = $FORM{"show_frag_ions"};
$ModifiedAA1 = $FORM{"ModifiedAA1"};
$ModifiedAA1Num = $FORM{"ModifiedAA1Num"};
$ModifiedAA2 = $FORM{"ModifiedAA2"};
$ModifiedAA2Num = $FORM{"ModifiedAA2Num"};
$ModifiedAA3 = $FORM{"ModifiedAA3"};
$ModifiedAA3Num = $FORM{"ModifiedAA3Num"};
$ModifiedAA4 = $FORM{"ModifiedAA4"};
$ModifiedAA4Num = $FORM{"ModifiedAA4Num"};
$ModifiedAA5 = $FORM{"ModifiedAA5"};
$ModifiedAA5Num = $FORM{"ModifiedAA5Num"};
$ModifiedAA6 = $FORM{"ModifiedAA6"};
$ModifiedAA6Num = $FORM{"ModifiedAA6Num"};
$ModifiedAA7 = $FORM{"ModifiedAA7"};
$ModifiedAA7Num = $FORM{"ModifiedAA7Num"};
$ModifiedAA8 = $FORM{"ModifiedAA8"};
$ModifiedAA8Num = $FORM{"ModifiedAA8Num"};

$frag_ion_tol = $FORM{"frag_ion_tol"};
$pep_mass_tol = $FORM{"pep_mass_tol"};
$num_out_lines = $FORM{"num_output_lines"};
$num_desc_lines = $FORM{"num_description_lines"};
$pr_dupl_ref = $FORM{"print_duplicate_references"};
$auto_distribute = $FORM{"auto_distribute"};
for ($i = 0; $i < 3; $i++) {
	$ion_series[$i] = $FORM{"ion$i"};
}
for ($i = 3; $i < 12; $i++) {
	$ion_series[$i] = $FORM{"ion$i"};
}
$normalize_xcorr = $FORM{"normalize_xcorr"};

$ModifiedAA1 =~ tr[a-z][A-Z];
$ModifiedAA2 =~ tr[a-z][A-Z];
$ModifiedAA3 =~ tr[a-z][A-Z];
$ModifiedAA4 =~ tr[a-z][A-Z];
$ModifiedAA5 =~ tr[a-z][A-Z];
$ModifiedAA6 =~ tr[a-z][A-Z];
$ModifiedAA7 =~ tr[a-z][A-Z];
$ModifiedAA8 =~ tr[a-z][A-Z];

# new SequestC2 parameters
$seq_head_filt = $FORM{"seq_head_filt"};
$rem_prec_peak = $FORM{"rem_prec_peak"};
$ion_cutoff = $FORM{"ion_cutoff"} / 100 if (defined $FORM{"ion_cutoff"});
$prot_mass_filt_min = $FORM{"prot_mass_filt_min"};
$prot_mass_filt_max = $FORM{"prot_mass_filt_max"};
$residues_in_uppercase = $FORM{"residues_in_uppercase"};
$max_int_cleavage = $FORM{"max_int_cleavage"};
$match_peak_count = $FORM{"match_peak_count"};
$match_peak_allowed_error = $FORM{"match_peak_allowed_error"};
$match_peak_tolerance = $FORM{"match_peak_tolerance"};

my $use_alt_sequest, $alt_sequest_loc, $use_alt_runsequest, $xml_output;

$use_alt_sequest = $alt_sequest_loc = 0;


# input from add-mass pop-up window
$add_Cterm_pro = $FORM{"add_Cterm_pro"};
$add_Nterm_pro = $FORM{"add_Nterm_pro"};
$add_Cterm_pep = $FORM{"add_Cterm_pep"};
$add_Nterm_pep = $FORM{"add_Nterm_pep"};
$add_G = $FORM{"add_G"};
$add_A = $FORM{"add_A"};
$add_S = $FORM{"add_S"};
$add_P = $FORM{"add_P"};
$add_V = $FORM{"add_V"};
$add_T = $FORM{"add_T"};
$add_C = $FORM{"add_C"};
$add_L = $FORM{"add_L"};
$add_I = $FORM{"add_I"};
$add_X = $FORM{"add_X"};
$add_N = $FORM{"add_N"};
$add_O = $FORM{"add_O"};
$add_B = $FORM{"add_B"};
$add_D = $FORM{"add_D"};
$add_Q = $FORM{"add_Q"};
$add_K = $FORM{"add_K"};
$add_Z = $FORM{"add_Z"};
$add_E = $FORM{"add_E"};
$add_M = $FORM{"add_M"};
$add_H = $FORM{"add_H"};
$add_F = $FORM{"add_F"};
$add_R = $FORM{"add_R"};
$add_Y = $FORM{"add_Y"};
$add_W = $FORM{"add_W"};


# input from enzyme-info pop-up window
# find maximum enzyme number provided in form input
$max_enznum = 0;
foreach (keys %FORM) {
	if (/^enz_.*?(\d+)$/) {
		$max_enznum = $1 if ($1 > $max_enznum);
	}
}
foreach $num (1..$max_enznum)
{
	$enz_name[$num] = $FORM{"enz_name$num"};
	$enz_name[$num] =~ s/ /_/g;  # spaces are allowed in form input, but in sequest.params they must be _
	$enz_offset[$num] = $FORM{"enz_offset$num"};
	$enz_sites[$num] = $FORM{"enz_sites$num"};
	$enz_no_sites[$num] = $FORM{"enz_no_sites$num"};
}



# get a few defaults from microchem_form_defaults.pl

# set all/selected radio button state
if ($FORM{"prev_selected"}) {	# set according to whether previous run in chosen directory used "selected"
	$DataFile = (-e "$seqdir/$dir/run_selected.txt") ? "selected" : "all";
} else {						# set according to defaults from microchem_form_defaults.pl
	$DataFile = (defined $FORM{"DataFile"}) ? $FORM{"DataFile"} : lc($DEFS_SEQLAUNCHER{"Dta Files"});
}

# if Harvard Microchem, set up add'l input to enable use of alternate sequest executable
my $alt_sequest_html;
if ($Harvard_Microchem) {
	$adv_win_height_ie = "395";
	$adv_win_height_ns = "420";
	$adv_win_width = "464";
	$alt_sequest_html = qq(document.writeln('<TR><TD ALIGN=right class=smallheading bgcolor=#e8e8fa NOWRAP>Use alternate Sequest&nbsp;&nbsp;</TD><TD class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=checkbox NAME="use_alt_sequest"></TD></TR>'); document.writeln('<TR><TD class=smallheading ALIGN=right bgcolor=#e8e8fa NOWRAP>Alternate Sequest location&nbsp;&nbsp;</TD><TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<INPUT TYPE=text NAME="alt_sequest_loc">&nbsp;&nbsp;</TD></TR>'););
	$alt_runsequest_html = qq(document.writeln('<TR><TD class=smallheading bgcolor=#e8e8fa ALIGN=right NOWRAP>Use alternate runsequest.pl&nbsp;&nbsp;</td><td class=smalltext bgcolor=#f2f2f2>&nbsp;<input type=checkbox NAME="use_alt_runsequest"></td></tr>'););
	$xml_output_html = qq(document.writeln('<TR><TD class=smallheading ALIGN=right bgcolor=#e8e8fa NOWRAP>Output in XML format:&nbsp;&nbsp;</td><td class=smalltext bgcolor=#f2f2f2>&nbsp;<input type=checkbox NAME="xml_output"></TD></TR>'););
} else {
	$adv_win_height_ie = "300";
	$adv_win_height_ns = "325";
	$adv_win_width = "400";
	$alt_sequest_html = " ";
	$alt_runsequest_html = " ";
	$xml_output_html = " ";
}

$nuc_read_frame = $DEFS_SEQLAUNCHER{"Options"} unless (defined $nuc_read_frame);
$nuc_read_frame = "auto" if ($nuc_read_frame eq "Auto");
$nuc_read_frame = "0" if ($nuc_read_frame eq "Protein");
$nuc_read_frame = "9" if ($nuc_read_frame eq "Nucleotide");

$clear_existing = $FORM{"clear_existing"};
if (!defined $clear_existing) {
	$clear_existing = ($FORM{"defined_clear_existing"}) ? 0 : ($DEFS_SEQLAUNCHER{"Clear existing OUT files?"} eq "yes");
}

# end of reading CGI input


# get default sequest.params values from default seqparam file
# use $default_seqparams by default, but another file can be
# used if specified in CGI input

$def_params = $FORM{"default"} || $default_seqparams;
open (DEFPARAMS, "<$def_params") || &error("cannot open sequest.params template file");
@lines = <DEFPARAMS>;
close (DEFPARAMS);

# Check to make sure that the params file is compatible with the new file format, which includes
# first_database_name and (optionally) second_database_name.
# Read the params file normally, since most of the fields are the same, and then update to the new format
# in edit_paramsfile()
if ($FORM{"default"}) {
	# This is the user specified sequest params, this file may need updating to match the new format.
	# (1) If the file contains "database_name" and not "first_database_name," then the file is in the old
	# format and needs updating.  Read the params file normally, since most of the fields are the same,
	# and then update to the new format in edit_paramsfile() the next time Sequest is run
	# (2) If the file does not contain "database_name," then it is not even C2 compatible, so give an error
	if ((grep(/^database_name/,@lines)) && (!(grep(/^first_database_name/,@lines)))) {
		# File will be updated in edit_params()
	} elsif (grep(/^first_database_name/,@lines)) {
		# File is in the correct format, do nothing
	} else {
		&error("(1)The current params file, $def_params, is not in the proper format.");
	}
} else {
	# This is the default template, it must contain "first_database_name" or it
	# is an error
	if (grep(/^first_database_name/,@lines)) {
		# File is in the correct format, do nothing
	} else {
		&error("(2)The current params file, $def_params, is not in the proper format.");
	}
}

$whole = join ("", @lines);
($seq_info,$enz_info) = split(/\[SEQUEST_ENZYME_INFO\]*.\n/, $whole);
$_ = $seq_info;
# top portion
($db) = /^first_database_name\s*=.*?([^\\\/\s]+)(\s*;|\s*$)/m unless (defined $db);
($seconddb) = /^second_database_name\s*=.*?([^\\\/\s]+)(\s*;|\s*$)/m unless ($seconddb ne "");
($enzyme) = /^enzyme_number\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $enzyme);
($is_mono_parent) = (/^mass_type_parent\s*=\s*(.*?)(\s*;|\s*$)/m) unless (defined $is_mono_parent);
($is_mono_fragment) = (/^mass_type_fragment\s*=\s*(.*?)(\s*;|\s*$)/m) unless (defined $is_mono_fragment);
($def_ModifiedAA1Num, $def_ModifiedAA1, $def_ModifiedAA2Num, $def_ModifiedAA2, $def_ModifiedAA3Num, $def_ModifiedAA3, $pp,
$def_ModifiedAA4Num, $def_ModifiedAA4, $def_ModifiedAA5Num, $def_ModifiedAA5, $def_ModifiedAA6Num, $def_ModifiedAA6) = 
	/^diff_search_options\s*=\s*(\S+)\s+(\w+)\s+(\S+)\s+(\w+)\s+(\S+)\s+(\w+)(\s+(\S+)\s+(\w+)\s+(\S+)\s+(\w+)\s+(\S+)\s+(\w+))?/m;
($def_ModifiedAA8Num, $def_ModifiedAA7Num) = /^term_diff_search_options\s*=\s*(\S+)\s+(\S+)?;/m;


# Load defaults from params file only if it is specified, otherwise use the ones in microchem_form_defaults.pl (see below)
# 7-26-00 P.Djeu
if ($FORM{"default"}) {
	$ModifiedAA1Num = $def_ModifiedAA1Num;
	$ModifiedAA1 = $def_ModifiedAA1;
	$ModifiedAA2Num = $def_ModifiedAA2Num;
	$ModifiedAA2 = $def_ModifiedAA2;
	$ModifiedAA3Num = $def_ModifiedAA3Num;
	$ModifiedAA3 = $def_ModifiedAA3;
	$ModifiedAA4Num = $def_ModifiedAA4Num;
	$ModifiedAA4 = $def_ModifiedAA4;
	$ModifiedAA5Num = $def_ModifiedAA5Num;
	$ModifiedAA5 = $def_ModifiedAA5;
	$ModifiedAA6Num = $def_ModifiedAA6Num;
	$ModifiedAA6 = $def_ModifiedAA6;
	$ModifiedAA7Num = $def_ModifiedAA7Num;
	$ModifiedAA7 = $def_ModifiedAA7;
	$ModifiedAA8Num = $def_ModifiedAA8Num;
	$ModifiedAA8 = $def_ModifiedAA8;

}

($def_ion_series) = /^ion_series\s*=\s*(.*?)(\s*;|\s*$)/m;
@def_ion_series = split /\s+/, $def_ion_series;
foreach $i (0..2) {
	# checkboxes need special treatment
	if ($FORM{"defined_ion$i"}) {
		$ion_series[$i] = 0 unless (defined $ion_series[$i]);
	} else {
		$ion_series[$i] = $def_ion_series[$i] unless (defined $ion_series[$i]);
	}
}
foreach $i (3..$#def_ion_series) {
	$ion_series[$i] = $def_ion_series[$i] unless (defined $ion_series[$i]);
}
$ion_series = join(" ", @ion_series);

if ($FORM{"defined_normalize_xcorr"}) {
	$normalize_xcorr = 0 unless (defined $normalize_xcorr);
}

($frag_ion_tol) = /^fragment_ion_tolerance\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $frag_ion_tol);
($pep_mass_tol) = /^peptide_mass_tolerance\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $pep_mass_tol);
($num_out_lines) = /^num_output_lines\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $num_out_lines);
($num_desc_lines) = /^num_description_lines\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $num_desc_lines);

# checkboxes require special treatment
# why?  because if you don't select a checkbox on a form, its name=value pair is not passed to the script,
# and by default that's the only way to tell that the checkbox wasn't selected
# yet we want to be able to run this script in automatic mode without having to specify all name=value pairs;
# we want the script to choose default values for those that we don't specify.
# so we put extra hidden elements on the form as signifiers that A VALUE WAS CHOSEN (affirmative or negative)
# -cmw (5/20/99)
if ($FORM{"defined_print_duplicate_references"}) {
	$pr_dupl_ref = 0 unless (defined $pr_dupl_ref);
} else {
	($pr_dupl_ref) = /^print_duplicate_references\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $pr_dupl_ref);
}
if ($FORM{"defined_show_frag_ions"}) {
	$show_frag_ions = 0 unless (defined $show_frag_ions);
} else {
	($show_frag_ions) = /^show_fragment_ions\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $show_frag_ions);
}
if ($FORM{"defined_rem_prec_peak"}) {
	$rem_prec_peak = 0 unless (defined $rem_prec_peak);
} else {
	($rem_prec_peak) = /^remove_precursor_peak\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $rem_prec_peak);
}
if ($FORM{"defined_residues_in_uppercase"}) {
	$residues_in_uppercase = 0 unless (defined $residues_in_uppercase);
} else {
	($residues_in_uppercase) = /^residues_in_upper_case\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $residues_in_uppercase);
}
if ($FORM{"defined_auto_distribute"}) {
	$auto_distribute = 0 unless (defined $auto_distribute);
} else {
	$auto_distribute = $DEFS_SEQLAUNCHER{"Auto-distribute?"};
}

# new SequestC2 parameters
#($seq_head_filt) = /^sequence_header_filter\s*?= *?(.*)$/m unless (defined $seq_head_filt);
# For $seq_head_filt, the character class is equivalent to \s without \n because we do not want to match
# newlines, otherwise, we get a match on the next non-blank line when sequence_header_filter is
# blank after the '=' (in which case $seq_head_file should be "")
($seq_head_filt) = /^sequence_header_filter\s*?=[ \t\r\f]*(.*)$/m unless (defined $seq_head_filt);
($ion_cutoff) = /^ion_cutoff_percentage\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $ion_cutoff);
# kludge kludge kludge! change this someday:
$ion_cutoff = "0.0" if ($ion_cutoff == 0);
($def_prot_mass_filt_min,$def_prot_mass_filt_max) = /^protein_mass_filter\s*=\s*(\S*)\s*(\S*)(\s*;|\s*$)/m;
$prot_mass_filt_min = $def_prot_mass_filt_min unless (defined $prot_mass_filt_min);
$prot_mass_filt_max = $def_prot_mass_filt_max unless (defined $prot_mass_filt_max);
($max_int_cleavage) = /^max_num_internal_cleavage_sites\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $max_int_cleavage);
($match_peak_count) = /^match_peak_count\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $match_peak_count);
($match_peak_allowed_error) = /^match_peak_allowed_error\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $match_peak_allowed_error);
($match_peak_tolerance) = /^match_peak_tolerance\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $match_peak_tolerance);


# add-mass portion
($add_Cterm_pro) = /^add_Cterm_protein\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Cterm_pro);
($add_Nterm_pro) = /^add_Nterm_protein\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Nterm_pro);
($add_Cterm_pep) = /^add_Cterm_peptide\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Cterm_pep);
($add_Nterm_pep) = /^add_Nterm_peptide\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Nterm_pep);
($add_G) = /^add_G_Glycine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_G);
($add_A) = /^add_A_Alanine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_A);
($add_S) = /^add_S_Serine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_S);
($add_P) = /^add_P_Proline\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_P);
($add_V) = /^add_V_Valine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_V);
($add_T) = /^add_T_Threonine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_T);
($add_C) = /^add_C_Cysteine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_C);
($add_L) = /^add_L_Leucine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_L);
($add_I) = /^add_I_Isoleucine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_I);
($add_X) = /^add_X_LorI\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_X);
($add_N) = /^add_N_Asparagine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_N);
($add_O) = /^add_O_Ornithine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_O);
($add_B) = /^add_B_avg_NandD\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_B);
($add_D) = /^add_D_Aspartic_Acid\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_D);
($add_Q) = /^add_Q_Glutamine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Q);
($add_K) = /^add_K_Lysine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_K);
($add_Z) = /^add_Z_avg_QandE\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Z);
($add_E) = /^add_E_Glutamic_Acid\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_E);
($add_M) = /^add_M_Methionine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_M);
($add_H) = /^add_H_Histidine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_H);
($add_F) = /^add_F_Phenylalanine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_F);
($add_R) = /^add_R_Arginine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_R);
($add_Y) = /^add_Y_Tyrosine\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Y);
($add_W) = /^add_W_Tryptophan\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_W);

# temporary kludge for compatiblity, since these fields are not defined in the old params format
$add_Cterm_pro = "0.0000" unless (defined $add_Cterm_pro);
$add_Nterm_pro = "0.0000" unless (defined $add_Nterm_pro);
$add_Cterm_pep = "0.0000" unless (defined $add_Cterm_pep);
$add_Nterm_pep = "0.0000" unless (defined $add_Nterm_pep);

# enzyme info portion
@enz_lines = ($enz_info =~ /^\d.*$/mg);
foreach (@enz_lines)
{
	($num,$name,$offset,$sites,$no_sites) = split(/\s+/);
	chop($num);  # remove trailing dot
	$enz_name[$num] = $name unless (defined $enz_name[$num]);
	$enz_offset[$num] = $offset unless (defined $enz_offset[$num]);
	$enz_sites[$num] = $sites unless (defined $enz_sites[$num]);
	$enz_no_sites[$num] = $no_sites unless (defined $enz_no_sites[$num]);
}
# reading of default values ends here

# the number of running sequests 
$runningseq = 0;
$runningdir = 0;
my(@seqs) = &read_status;
# extract error messages from this list of Sequest processes
@procs = ();
	my $i = 0;
foreach $seq (@seqs) {
	if ($seq !~ s/^Error:\s*//) {
		push(@procs,$seq);
	}
}
foreach $ID (@procs)
{
	$runningseq++  if ($status{$ID} eq "RUNNING");
	$dirpath = $dirpath{$ID};
	$i++;
	my $samedir = "false";
	my $j = $i;
	for ($j; $j<=$#procs; $j++) {
		my $proc = $procs[$j];
		if ( $proc ne $ID) {
			my $dirloc = $dirpath{$proc};
			if ($dirpath eq $dirloc ) {
				$samedir = "true";
				last;
			}
		}	
	}
	$runningdir++ if ($samedir ne "true");
}

$statuslink = &create_link(link=>$seqstatus, text=>"$runningdir Dir&nbsp;&nbsp;$runningseq Procs");
###

unless ($FORM{"running"}) {  # this part produces HTML for the Sequest Launcher page
	my $heading = qq(heading=<span style="color:#0080C0">Run</span> <span style="color:#0000FF">TurboSequest</span>);
	&MS_pages_header("Run TurboSequest", 0, $heading);
	print "<HR>";
	&get_dbases;
	&get_alldirs;

	$ModifiedAA1 = $DEFS_SEQLAUNCHER{'Modified AA'} unless (defined $ModifiedAA1);
	$ModifiedAA1Num = $DEFS_SEQLAUNCHER{'Modified AA num'} unless (defined $ModifiedAA1Num);
	$ModifiedAA2 = $DEFS_SEQLAUNCHER{'2nd Modified AA'} unless (defined $ModifiedAA2);
	$ModifiedAA2Num = $DEFS_SEQLAUNCHER{'2nd Modified AA num'} unless (defined $ModifiedAA2Num);
	$ModifiedAA3 = $DEFS_SEQLAUNCHER{'3rd Modified AA'} unless (defined $ModifiedAA3);
	$ModifiedAA3Num = $DEFS_SEQLAUNCHER{'3rd Modified AA num'} unless (defined $ModifiedAA3Num);
	$ModifiedAA4 = $DEFS_SEQLAUNCHER{'4th Modified AA'} unless (defined $ModifiedAA4);
	$ModifiedAA4Num = $DEFS_SEQLAUNCHER{'4th Modified AA num'} unless (defined $ModifiedAA4Num);
	$ModifiedAA5 = $DEFS_SEQLAUNCHER{'5th Modified AA'} unless (defined $ModifiedAA5);
	$ModifiedAA5Num = $DEFS_SEQLAUNCHER{'5th Modified AA num'} unless (defined $ModifiedAA5Num);
	$ModifiedAA6 = $DEFS_SEQLAUNCHER{'6th Modified AA'} unless (defined $ModifiedAA6);
	$ModifiedAA6Num = $DEFS_SEQLAUNCHER{'6th Modified AA num'} unless (defined $ModifiedAA6Num);
	$auto_distribute = $DEFS_SEQLAUNCHER{'Auto-distribute?'} unless (defined $auto_distribute);

	$checked{$DataFile} = " CHECKED";
	$checked{$nuc_read_frame} = " CHECKED";
	$ion_cutoff *= 100;		# convert decimal to percent

    $enz_sel{$enzyme} = "SELECTED";
	$checked{($is_mono_parent ? "mono_par" : "avg_par")} = "CHECKED";
	$checked{($is_mono_fragment ? "mono_frag" : "avg_frag")} = "CHECKED";
    $checked{"show_frag_ions"} = "CHECKED" if ($show_frag_ions);
    $checked{"pr_dupl_ref"} = "CHECKED" if ($pr_dupl_ref);
	$checked{"ion0"} = "CHECKED" if ($ion_series[0]);
	$checked{"ion1"} = "CHECKED" if ($ion_series[1]);
	$checked{"ion2"} = "CHECKED" if ($ion_series[2]);
	$checked{"rem_prec_peak"} = "CHECKED" if ($rem_prec_peak);
	$checked{"normalize_xcorr"} = "CHECKED" if ($normalize_xcorr);
	$checked{"continue_different_params"} = "CHECKED" if ($continue_different_params);

	$checked{"clearouts"} = " CHECKED" if ($clear_existing);

	foreach ("continue_unfinished","Q_immunity","start_suspended") {
		$checked{$_} = ($FORM{$_}) ? " checked" : "";
	}

	if ($auto_distribute) {
		$checked{"auto_distribute"} = " CHECKED";
		$checked{"Q_immunity"} = " CHECKED";
	}

	$unique_window_name = "$$\_$^T";

    print <<FORMPAGE;


<SCRIPT LANGUAGE="Javascript">
<!--
var addmass;
var enzymes;
var advanced;
var defaults = new Array();
var enz_defaults = new Array();
var isSelected = "advancedoptions_";

// redirect page to VuDTA
function selectDTAs()
{
	var selected = document.forms[0].directory.options.selectedIndex;
	var gotoDir = document.forms[0].directory.options[selected].value;
	var gotoURL = "$VuDTA?directory=" + gotoDir + "&labels=checked&show=show";

	location.href=gotoURL;
}


// reload page with default parameters from sequest.params in the currently selected directory
function loadparams()
{
	var selected = document.forms[0].directory.options.selectedIndex;
	var gotoDir = document.forms[0].directory.options[selected].value;
	var paramsfile = escape("$seqdir/" + gotoDir + "/sequest.params");
	var gotoURL = "$ourname?directory=" + gotoDir + "&default=" + paramsfile + "&prev_selected=1&continue_unfinished=1&continue_different_params=1";

	location.href=gotoURL;
}



// error checking subroutine for ion-series
function check_ion_series(eltname)
{
	var elt = document.forms[0][eltname];
	var input = parseFloat(elt.value);
	if (!((input >= 0.0) && (input <= 1.0)))
	{
		alert("Ion series weightings must have values between 0 and 1.");
		elt.focus();
	}
}


function continueWarning()
{
	if (document.forms[0].continue_unfinished.checked)
		alert("Note: by default, checking this box causes Sequest to be run without any changes to the sequest.params file in your chosen directory, so whatever parameters you've edited on this page will be ignored.  If you want to change parameters and continue a run, you must also select the \\"Use different parameters to continue\\" option in the Advanced window.");
}


// all the rest of this has to do with pop-up windows

// save all default form element values in an array, for use by the resetAll function later
function getDefaults()
{
	// default form element values
	for (i = 0; i < document.forms[0].elements.length; i++)
	{
		defaults[i] = document.forms[0].elements[i].value;
	}

	// default dropbox text
	for (i = 1; i < document.forms[0].Enzyme.options.length; i++)
	{
		enz_defaults[i] = document.forms[0].Enzyme.options[i].text;
	}
}


// reset all form elements to default values, INCLUDING hidden elements and selected tabs
// (HTML does not necessarily do this by default)
function resetAll()
{
	window.status = "Resetting form to default values, please wait...";

	for (i = 0; i < document.forms[0].elements.length; i++)
		document.forms[0].elements[i].value = defaults[i];
	getValues(add_mass);
	getValues(enzyme_info);
	getValues(advanced_settings);

	// update Enzyme list in dropbox on main form
	document.forms[0].Enzyme.options.length = enz_defaults.length
	for (i = 1; i < enz_defaults.length; i++)
		document.forms[0].Enzyme.options[i].text = enz_defaults[i];	

	window.status = "Done";
}



// retrieve form values from hidden values in main window
// and display in selected tab
function getValues(form)
{
    window.status = "Retrieving values, please wait...";

    for (i = 0; i <form.elements.length; i++)
    {
		if (form.elements[i]) {
			elt = form.elements[i];
			if (document.mainform[elt.name]) {
				if (elt.type == "checkbox")
					// Always define the actual checkboxes in the pop-up as value="1", put the real value in
					// the hidden form element on the main page
					elt.checked = (document.mainform[elt.name].value == elt.value);
				else
					elt.value = document.mainform[elt.name].value;
			}
		}
    }

    window.status = "Done";
}

// opposite of getValues(): save values from form elements in a selected tab
// as values of hidden elements in main window, and update enzyme dropbox
function saveValues(form)
{
	window.status = "Saving values, please wait...";
	selectTab('advancedoptions_');
	for (i = 0; i < form.elements.length; i++)
	{
		elt = form.elements[i];
		if (document.forms[0][elt.name]) {
			if (elt.type == "checkbox")
				document.forms[0][elt.name].value = (elt.checked) ? elt.value : 0;
			else
				document.forms[0][elt.name].value = elt.value;
		}

		// update Enzyme list in dropbox on main form if necessary
		if (elt.name != null) {		
			if (elt.name.substring(0,8) == "enz_name")
			{
				var enz_num = elt.name.substring(8,elt.name.length);
				var enz_text = elt.value;
				// replace all underscores in enz_text with spaces
				textlength = enz_text.length;
				for (j = 0; j < textlength; j++)
				{
					if (enz_text.charAt(j) == "_")
						enz_text = enz_text.substring(0,j) + " " + enz_text.substring(j+1,textlength);
				}
				document.forms[0].Enzyme.options[enz_num].text = enz_text;
			}
		}
	}
	window.status = "Done";
}

function selectTab(tab) {
	hide();
	var selectedTab = document.getElementById(tab);
	var displayTab;
	var selectedTabLab;
	if (tab == "addmass_") {
		displayTab = document.getElementById("edit_add_mass");
		isSelected = "addmass_";
		getValues(add_mass);
		selectedTabLab = document.getElementById("addmass_lab");
	}
	else if (tab == "enzymes_") {
		displayTab = document.getElementById("enzymes");
		isSelected = "enzymes_";
		getValues(enzyme_info);
		selectedTabLab = document.getElementById("enzymes_lab");
	}
	else if (tab == "advanced_") {
		displayTab = document.getElementById("advanced");
		isSelected = "advanced_";
		getValues(advanced_settings);
		selectedTabLab = document.getElementById("advanced_lab");
	}
	else if (tab == "advancedoptions_") {
		displayTab = document.getElementById("advancedoptions");
		isSelected = "advancedoptions_";
		selectedTabLab = document.getElementById("advancedoptions_lab");
	}
	selectedTabLab.className = "selectedtablabel";
	selectedTab.className="selectedtab";
	displayTab.style.display = "";
	displayTab.focus();
}

function hide() {
	var selectedTab = document.getElementById(isSelected);
	var addmass = document.getElementById("edit_add_mass");
	var enzymes = document.getElementById("enzymes");
	var advanced = document.getElementById("advanced");
	var advancedoptions = document.getElementById("advancedoptions");
	var selectedTabLab = document.getElementById(isSelected + "lab");
	selectedTabLab.className = "tablabel";
	advancedoptions.style.display = "none";
	addmass.style.display = "none";
	enzymes.style.display = "none";	
	advanced.style.display = "none";
	selectedTab.className = "unselectedtab";
 }

 function tab_revert(tab) {
	 if (tab != isSelected) {
		 var selected = document.getElementById(tab);
		 selected.className = "unselectedtab";
	 }
 }

function tab_highlighted(tab) {
	if (tab != isSelected) {
		 var selected = document.getElementById(tab);
		 selected.className = "activetab";
	 }
}

//taggle the check boxes auto_distribute and start paused
function toggle_distribute_pause(checkbox) {
	if (checkbox == "auto_distribute") {
		if (document.mainform.auto_distribute.checked)
			document.mainform.start_suspended.checked = false;
	}
	else if (checkbox == "start_suspended") {
		if (document.mainform.start_suspended.checked)
			document.mainform.auto_distribute.checked = false;
	}
}


// Args: value can be either true or false
function set_q_immunity (value)
{
	document.forms[0].Q_immunity.checked = value;
}


function browse_makedbparams_open(databaseId)
{
	var database;
	if (databaseId == 1 ) {
		database = document.mainform.Database.value;
	}
	else 
	{
		database = document.mainform.secondDatabase.value;
	}
	var makedbparams = open("$webcgi/browse_makedbparams.pl?database="+database+"&conserve_space=1","","resizable,scrollbars");
}


// Args: name is the string name of the value in the dropbox that will be displayed in the runOnServer dropbox
function dropbox_select(name)
{
	var i;
	for (i = 0; i < document.forms[0].runOnServer.options.length; i++) {
		if (document.forms[0].runOnServer.options[i].text == name) {
			break;
		}
	}

	document.forms[0].runOnServer.selectedIndex = i;
}


onunload = hide;
onload = getDefaults;

//-->
</SCRIPT>
<br style="font-size:10">
<FORM NAME="mainform" METHOD="POST" ACTION="$ourname" style="margin-top:0; margin-bottom:0" onReset="resetAll()">

<!-- these are to signify to the script that values for these checkboxes are specified, even if not submitted (not selected) -->
<input type=hidden name="defined_clear_existing" value=1>
<input type=hidden name="defined_continue_unfinished" value=1>
<input type=hidden name="defined_Q_immunity" value=1>
<input type=hidden name="defined_print_duplicate_references" value=1>
<input type=hidden name="defined_show_frag_ions" value=1>
<input type=hidden name="defined_rem_prec_peak" value=1>
<input type=hidden name="defined_ion0" value=1>
<input type=hidden name="defined_ion1" value=1>
<input type=hidden name="defined_ion2" value=1>
<input type=hidden name="defined_auto_distribute" value=1>
<input type=hidden name="defined_normalize_xcorr" value=1>

<TABLE cellspacing=0 cellpadding=0 border=0 width=975><TR><TD VALIGN=top>
<TABLE cellspacing=0 cellpadding=0 border=0>
<tr><td bgcolor=#e8e8fa style="font-size:3">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:3">&nbsp;</td></tr>
<TR height=25>
	<TD ALIGN=RIGHT class=smallheading bgcolor=#e8e8fa NOWRAP>&nbsp;&nbsp;Sequest Directory:&nbsp;&nbsp;</TD>
	<TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME="directory">
FORMPAGE

    foreach $directory (@ordered_names) {
	if ($directory eq $dir) {
	    $selected = "SELECTED";
	}
	else {
	    $selected = "";
	}
		print "<OPTION VALUE = \"$directory\" $selected>$fancyname{$directory}\n";
    }

    print <<FORMPAGE;
                </SELECT></span>&nbsp;&nbsp;
	</TD>
</TR>

<TR height=25>
	<TD ALIGN=RIGHT class=smallheading bgcolor=#e8e8fa NOWRAP>Dta Files:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2 nowrap>
			<input type="radio" name="DataFile" value="all"$checked{"all"}>All
			&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type="radio" name="DataFile" value="selected"$checked{"selected"}>Selected 
			&nbsp;&nbsp;&nbsp;&nbsp;<span class=smallheading style="cursor:hand; color:#0000cc" id="selectlink" 
			onmouseover="this.style.color='red';window.status='javascript:selectDTAs()';return true;" onmouseout="this.style.color='#0000cc';window.status='';return true;"
			onclick="javascript:selectDTAs()">Select...</span>
			&nbsp;&nbsp;&nbsp;&nbsp;<INPUT NAME="clear_existing" TYPE=checkbox$checked{"clearouts"}>Clear OUTs?
	</TD>
</TR>
<tr heigth=15><td class=smalltext>&nbsp;</td></tr>
<tr>
	<td colspan=2>
	<table cellspacing=0 cellpadding=0 bgcolor="#e8e8fa" height=20 width=100%><tr>
		<td width=20><img src="${webimagedir}/ul-corner.gif" width=10 height=20></td>
		<td width=100% class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;Database & Enzyme</td>
		<td width=20><img src="${webimagedir}/ur-corner.gif" width=10 height=20></td>
	</tr></table>
	</td>
</tr>
<tr><td colspan=2><table cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
			
<TR height=25>
	<TD width=118 ALIGN=RIGHT class=smallheading bgcolor=#e8e8fa NOWRAP>First:&nbsp;&nbsp;</TD>
	<TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME="Database">
           <OPTION VALUE="sequestparams">Use sequest.params default
FORMPAGE

	# Adapted from microchem_include.pl
    opendir (DBDIR, $dbdir) || &error("can't open $dbdir");
	@other_db_names = grep {/fasta.hdr$/} readdir (DBDIR);
	closedir DBDIR;

	@all_db_names = sort {lc($a) cmp lc($b)} (@ordered_db_names, @other_db_names);

	foreach $database (@all_db_names) {
		print "<OPTION VALUE=\"$database\"";
		print " SELECTED" if ($database eq $db);
		print ">$database\n";
	}

	print <<FORMPAGE;;
                </SELECT></span>
	&nbsp;&nbsp;
	</TD>
</TR>

<TR height=25>
	<TD ALIGN=RIGHT class=smallheading bgcolor=#e8e8fa NOWRAP>Second:&nbsp;&nbsp;</TD>
	<TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME="secondDatabase">
		<OPTION VALUE="none" SELECTED>
        <OPTION VALUE="sequestparams">Use sequest.params default
FORMPAGE

	# Adapted from microchem_include.pl
    opendir (DBDIR, $dbdir) || &error("can't open $dbdir");
	@other_db_names = grep {/fasta.hdr$/} readdir (DBDIR);
	closedir DBDIR;

	@all_db_names = sort {lc($a) cmp lc($b)} (@ordered_db_names, @other_db_names);

	foreach $database (@all_db_names) {
		print "<OPTION VALUE=\"$database\"";
		print " SELECTED" if ($database eq $seconddb);
		print ">$database\n";
	}

	print <<FORMPAGE;;
		  </SELECT></span>
	    &nbsp;&nbsp; 
	</TD>
</TR>

<TR height=25>
	<TD ALIGN=RIGHT class=smallheading bgcolor=#e8e8fa NOWRAP>Options:&nbsp;&nbsp;</TD>
	<TD bgcolor=#f2f2f2 class=smalltext NOWRAP>
		<INPUT TYPE=radio NAME="nuc_read_frame" VALUE="auto"$checked{"auto"}>Auto 
		&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE=radio NAME="nuc_read_frame" VALUE="0"$checked{"0"}>Protein 
		&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE=radio NAME="nuc_read_frame" VALUE="9"$checked{"9"}>Nucleotide<BR>
	</TD>
</TR>
<TR height=25>
<TD ALIGN=RIGHT class=smallheading bgcolor=#e8e8fa NOWRAP>Enzyme:&nbsp;&nbsp;</TD>
     <TD bgcolor=#f2f2f2 class=smalltext NOWRAP>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME=Enzyme>
	<OPTION $enz_sel{"0"} VALUE=0>None
FORMPAGE

	foreach $num (1..$#enz_name)
	{
		$name = $enz_name[$num];
		$name =~ s/_/ /g;
		print "<OPTION VALUE=$num $enz_sel{$num}>$name\n";
	}

	print <<FORMPAGE;
		</SELECT></span>
	</TD>
</TR>
</TABLE>
</TD></table></td>

<td width=40>&nbsp;</td>
<td valign=top align=center>
<TABLE cellspacing=0 cellpadding=0 border=0>
<tr>
	<td colspan=2>
	<table cellspacing=0 cellpadding=0 bgcolor="#e8e8fa" height=20 width=100%><tr>
		<td width=20><img src="${webimagedir}/ul-corner.gif" width=10 height=20></td>
		<td width=100% class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;Server Options</td>
		<td width=20><img src="${webimagedir}/ur-corner.gif" width=10 height=20></td>
	</tr></table>
	</td>
</tr>
<tr><td colspan=2>
<table cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
<tr height=22><td bgcolor=#e8e8fa class=smallheading align=right>Sequest Status:&nbsp;&nbsp;</td><td class=smallheading bgcolor=#f2f2f2>&nbsp;&nbsp;$statuslink&nbsp;&nbsp;</td>
FORMPAGE
if ($multiple_sequest_hosts) {
	print "<tr height=22><td align=right bgcolor=#e8e8fa class=smallheading>&nbsp;&nbsp;Run on Server:&nbsp;&nbsp;</td>\n";
	print "<td bgcolor=#f2f2f2>&nbsp;&nbsp;<span class=\"dropbox\"><SELECT NAME=\"runOnServer\">\n";
	print "<OPTION>$ENV{'COMPUTERNAME'}";
	foreach $seqserver (@seqservers) {
		print ("<OPTION" . (($seqserver eq $runOnServer) ? " SELECTED" : "") . ">$seqserver");
	}
	print "</SELECT></span>&nbsp;&nbsp;</td></tr>\n";
	print <<EOF;
<tr height=22><td align=right bgcolor=#e8e8fa><span class=smalltext>&nbsp;&nbsp;&nbsp;&nbsp;Auto-Distribute&nbsp;&nbsp;</span></td>
	<td bgcolor=#f2f2f2>&nbsp;<input type=checkbox name="auto_distribute" value=1$checked{"auto_distribute"} onclick="toggle_distribute_pause('auto_distribute')">&nbsp;</td>
</tr>
<tr height=22>
	<td align=right bgcolor=#e8e8fa>&nbsp;<span class=smalltext>Q Immunity&nbsp;&nbsp;</span></td>
	<td  bgcolor=#f2f2f2>&nbsp;<input type=checkbox name="Q_immunity" value=1$checked{"Q_immunity"}>&nbsp;</td></tr>

EOF
}
$helplink = &create_link();
print <<EOF;
<tr height=22><td align=right bgcolor=#e8e8fa>&nbsp;<span class=smalltext>Continue</span>&nbsp;&nbsp;</td>
	<td bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=checkbox NAME="continue_unfinished" VALUE="1"$checked{"continue_unfinished"} onClick="continueWarning()">&nbsp;</td>
</tr>
<tr height=22><td align=right bgcolor=#e8e8fa>&nbsp;<span class=smalltext>Start Paused&nbsp;&nbsp;</span></td>
	<td bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=checkbox NAME="start_suspended" VALUE="1"$checked{"start_suspended"} onclick="toggle_distribute_pause('start_suspended')">&nbsp;</td>
</tr>
</TABLE></td></tr>
<tr height=35><td colspan=3 align=center valign=bottom>
<span class=smallheading>Oper:&nbsp;</span><INPUT NAME="operator" VALUE="$operator" SIZE=3 MAXLENGTH=3>
<INPUT TYPE=submit class="outlinebutton button" style="cursor:hand; width=100" NAME="running" VALUE="Run SEQUEST">
<INPUT TYPE=hidden name="symbol" value="">
$helplink
</td></tr>	
</table>
</td>
<td width=45>&nbsp;</td>

<TD VALIGN=top align=right>
<TABLE cellspacing=0 cellpadding=0 border=0>
<tr><td valign=top>
EOF

my @chars = ($ModifiedAA1, $ModifiedAA2, $ModifiedAA3, $ModifiedAA4, $ModifiedAA5, $ModifiedAA6, $ModifiedAA7, $ModifiedAA8);
my @values= ($ModifiedAA1Num, $ModifiedAA2Num, $ModifiedAA3Num, $ModifiedAA4Num, $ModifiedAA5Num, $ModifiedAA6Num, $ModifiedAA7Num, $ModifiedAA8Num);
my $mod = &create_mod_box("characters" => \@chars, "masses" => \@values, "scrollbar" => 1);
print $mod;

print <<EOF;
</td></tr></table></td>	
</tr>
</table>
</td></tr></table>

<br style="font-size:25">
EOF

print <<FORMPAGE;
<!-- hidden CGI-info for editing the middle and bottom parts of sequest.params
     these values can be altered by the Javascript pop-up windows //-->

<!-- AddMass window -->
<INPUT TYPE=hidden NAME="add_Cterm_pro" VALUE="$add_Cterm_pro">
<INPUT TYPE=hidden NAME="add_Nterm_pro" VALUE="$add_Nterm_pro">
<INPUT TYPE=hidden NAME="add_Cterm_pep" VALUE="$add_Cterm_pep">
<INPUT TYPE=hidden NAME="add_Nterm_pep" VALUE="$add_Nterm_pep">
<INPUT TYPE=hidden NAME="add_G" VALUE="$add_G">
<INPUT TYPE=hidden NAME="add_A" VALUE="$add_A">
<INPUT TYPE=hidden NAME="add_S" VALUE="$add_S">
<INPUT TYPE=hidden NAME="add_P" VALUE="$add_P">
<INPUT TYPE=hidden NAME="add_V" VALUE="$add_V">
<INPUT TYPE=hidden NAME="add_T" VALUE="$add_T">
<INPUT TYPE=hidden NAME="add_C" VALUE="$add_C">
<INPUT TYPE=hidden NAME="add_L" VALUE="$add_L">
<INPUT TYPE=hidden NAME="add_I" VALUE="$add_I">
<INPUT TYPE=hidden NAME="add_X" VALUE="$add_X">
<INPUT TYPE=hidden NAME="add_N" VALUE="$add_N">
<INPUT TYPE=hidden NAME="add_O" VALUE="$add_O">
<INPUT TYPE=hidden NAME="add_B" VALUE="$add_B">
<INPUT TYPE=hidden NAME="add_D" VALUE="$add_D">
<INPUT TYPE=hidden NAME="add_Q" VALUE="$add_Q">
<INPUT TYPE=hidden NAME="add_K" VALUE="$add_K">
<INPUT TYPE=hidden NAME="add_Z" VALUE="$add_Z">
<INPUT TYPE=hidden NAME="add_E" VALUE="$add_E">
<INPUT TYPE=hidden NAME="add_M" VALUE="$add_M">
<INPUT TYPE=hidden NAME="add_H" VALUE="$add_H">
<INPUT TYPE=hidden NAME="add_F" VALUE="$add_F">
<INPUT TYPE=hidden NAME="add_R" VALUE="$add_R">
<INPUT TYPE=hidden NAME="add_Y" VALUE="$add_Y">
<INPUT TYPE=hidden NAME="add_W" VALUE="$add_W">


<!-- Enzyme window -->
FORMPAGE
	# enzymes window
	foreach $num (1..$#enz_name)
	{
	print <<ENZINFO;
<INPUT TYPE=hidden NAME="enz_name$num" VALUE="$enz_name[$num]">
<INPUT TYPE=hidden NAME="enz_offset$num" VALUE="$enz_offset[$num]">
<INPUT TYPE=hidden NAME="enz_sites$num" VALUE="$enz_sites[$num]">
<INPUT TYPE=hidden NAME="enz_no_sites$num" VALUE="$enz_no_sites[$num]">

ENZINFO
	}

	print <<FORMPAGE;

<!-- Advanced window -->
<INPUT TYPE=hidden NAME="defined_continue_different_params" VALUE=1>
<INPUT TYPE=hidden NAME="residues_in_uppercase" VALUE="$residues_in_uppercase">
<INPUT TYPE=hidden NAME="defined_residues_in_uppercase" VALUE=1>
<INPUT TYPE=hidden NAME="max_int_cleavage" VALUE="$max_int_cleavage">
<INPUT TYPE=hidden NAME="match_peak_count" VALUE="$match_peak_count">
<INPUT TYPE=hidden NAME="match_peak_allowed_error" VALUE="$match_peak_allowed_error">
<INPUT TYPE=hidden NAME="match_peak_tolerance" VALUE="$match_peak_tolerance">
<INPUT TYPE=hidden NAME="use_alt_sequest" VALUE="$use_alt_sequest">
<INPUT TYPE=hidden NAME="alt_sequest_loc" VALUE="$alt_sequest_loc">
<input type=hidden name="use_alt_runsequest" VALUE="$use_alt_runsequest">
<input type=hidden name="xml_output" value="$xml_output">
<INPUT type=hidden NAME="ion_cutoff" VALUE="$ion_cutoff">
<INPUT type=hidden NAME="prot_mass_filt_min" VALUE="$prot_mass_filt_min">
<INPUT type=hidden NAME="prot_mass_filt_max" VALUE="$prot_mass_filt_max">
<INPUT type=hidden NAME="rem_prec_peak" VALUE=$rem_prec_peak>

<span id=advancedoptions_ onmouseover="tab_highlighted('advancedoptions_')" onmouseout="tab_revert('advancedoptions_')" class=selectedtab style="width:95"  onClick="selectTab('advancedoptions_')">
	<img src="${webimagedir}/ul-corner.gif" width=10 height=20 style="position:absolute; left:0; top:0">
	<span class=selectedtablabel id="advancedoptions_lab">&nbsp;&nbsp;Options</span>
	<img src="${webimagedir}/ur-corner.gif" width=10 height=20 style="position:absolute; left:85; top:0">
</span>
<span id=addmass_ onmouseover="tab_highlighted('addmass_')" onmouseout="tab_revert('addmass_')" class=unselectedtab style="width:120" onClick="selectTab('addmass_')">
	<img src="${webimagedir}/ul-corner.gif" width=10 height=20 style="position:absolute; left:0; top:0">
	<span class=tablabel id=addmass_lab>Edit Add-Mass</span>
	<img src="${webimagedir}/ur-corner.gif" width=10 height=20 style="position:absolute; left:110; top:0">
</span>
<span id=enzymes_ onmouseover="tab_highlighted('enzymes_')" onmouseout="tab_revert('enzymes_')" class=unselectedtab style="width:130" onClick="selectTab('enzymes_')">
	<img src="${webimagedir}/ul-corner.gif" width=10 height=20 style="position:absolute; left:0; top:0">
	<span class=tablabel id=enzymes_lab>Edit Enzyme Info</span>
	<img src="${webimagedir}/ur-corner.gif" width=10 height=20 style="position:absolute; left:120; top:0">
</span>
<span id=advanced_ onmouseover="tab_highlighted('advanced_')" onmouseout="tab_revert('advanced_')" class=unselectedtab style="width:120" onClick="selectTab('advanced_')">
	<img src="${webimagedir}/ul-corner.gif" width=10 height=20 style="position:absolute; left:0; top:0">
	<span class=tablabel id=advanced_lab>Edit Advanced</span>
	<img src="${webimagedir}/ur-corner.gif" width=10 height=20 style="position:absolute; left:110; top:0">
</span>

<div id="advancedoptions" style="border: solid #000099; border-width:1px;width:975">
<TABLE cellspacing=0 cellpadding=0 border=0>
<tr><td>&nbsp;</td></tr>
<TR><td width=15>&nbsp;</td>
<TD valign=top>
<TABLE cellspacing=0 cellpadding=0 border=0>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Mass:&nbsp;&nbsp;</td>
	<TD class=smalltext bgcolor=#f2f2f2 nowrap>&nbsp;<INPUT TYPE=radio NAME="MonoAvg_par" VALUE="1" $checked{"mono_par"}>Mono
		<INPUT TYPE=radio NAME="MonoAvg_par" VALUE="0" $checked{"avg_par"}>Avg&nbsp;&nbsp;</td>
</tr>		
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>&nbsp;&nbsp;Fragment Ion Tolerance:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="frag_ion_tol" VALUE="$frag_ion_tol" SIZE=6></TD>
</TR>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Peptide Mass Tolerance:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="pep_mass_tol" VALUE="$pep_mass_tol" SIZE=6>&nbsp;&nbsp;</TD>
</TR>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Output Lines:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="num_output_lines" VALUE="$num_out_lines" SIZE=2 MAXLENGTH=3></TD>
</TR>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Description Lines:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="num_description_lines" VALUE="$num_desc_lines" SIZE=2 MAXLENGTH=3></TD>
</TR>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Duplicate Proteins:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=checkbox NAME="print_duplicate_references" VALUE="1" $checked{"pr_dupl_ref"}></TD>
</TR>
</TABLE>
</TD>
<td width=30></td>
<TD valign=top>
<TABLE cellspacing=0 cellpadding=0 border=0><TR><TD>
<fieldset style="padding:5px; border: solid #0000cc 1px">
	<legend class=smallheading>Neutral Losses (H<sub>2</sub>O/NH<sub>3</sub>)</legend>
	<br style="font-size:5">
	&nbsp;&nbsp;&nbsp;&nbsp;<tt>a:&nbsp;</tt><INPUT TYPE=checkbox NAME="ion0" VALUE="1" $checked{"ion0"}>&nbsp;&nbsp;&nbsp;&nbsp; 
	<tt>b:&nbsp;</tt><INPUT TYPE=checkbox NAME="ion1" VALUE="1" $checked{"ion1"}>&nbsp;&nbsp;&nbsp;&nbsp;
	<tt>y:&nbsp;</tt><INPUT TYPE=checkbox NAME="ion2" VALUE="1" $checked{"ion2"}>&nbsp;&nbsp;&nbsp;&nbsp;
	<br style="font-size:5">
</fieldset></td></tr>
<tr height=10><td>&nbsp;</td></tr>
<tr><td>
<fieldset style="padding:5px; border: solid #0000cc 1px">
	<legend class=smallheading>Ion Series Weightings</legend>
	<br style="font-size:5">
	<TABLE cellspacing=0 cellpadding=0 border=0>
	<TR heigth=25>
		<TD ALIGN=right><tt>&nbsp;&nbsp;a:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion3" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[3]" onBlur="check_ion_series('ion3')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
		<TD ALIGN=right><tt>b:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion4" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[4]" onBlur="check_ion_series('ion4')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
		<TD ALIGN=right><tt>c:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion5" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[5]" onBlur="check_ion_series('ion5')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR height=25>
		<TD ALIGN=right><tt>d:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion6" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[6]" onBlur="check_ion_series('ion6')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
		<TD ALIGN=right><tt>v:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion7" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[7]" onBlur="check_ion_series('ion7')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
		<TD ALIGN=right><tt>w:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion8" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[8]" onBlur="check_ion_series('ion8')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR>
		<TD ALIGN=right><tt>x:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion9" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[9]" onBlur="check_ion_series('ion9')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
		<TD ALIGN=right><tt>y:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion10" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[10]" onBlur="check_ion_series('ion10')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
		<TD ALIGN=right><tt>z:&nbsp;</tt></TD>
		<TD><INPUT NAME="ion11" SIZE=3 MAXLENGTH=4 VALUE="$ion_series[11]" onBlur="check_ion_series('ion11')">&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	</TABLE>
</fieldset></TD></TR></TABLE>
</TD>
<td width=30>&nbsp;</td>
<TD valign=top>
<TABLE cellspacing=0 cellpadding=0 border=0>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Normalize XCorr Values:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT NAME="normalize_xcorr" value="1" TYPE="checkbox"$checked{"normalize_xcorr"}></TD>
</TR>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Sequence Header Filter:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="seq_head_filt" VALUE="$seq_head_filt" SIZE=12>&nbsp;&nbsp;</TD>
</TR>
<TR height=26>
	<TD ALIGN=right NOWRAP class=smallheading bgcolor=#e8e8fa>&nbsp;&nbsp;&nbsp;&nbsp;Use different parameters to continue&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=checkbox NAME="continue_different_params" VALUE=1 $checked{"continue_different_params"} ></TD>
</TR>
<TR height=26>
	<TD ALIGN=right NOWRAP class=smallheading bgcolor=#e8e8fa>Load params from selected directory&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT TYPE=button CLASS="outlinebutton button" VALUE="Refresh" onClick="loadparams()"></TD>
</TR>
<TR height=26>
	<TD ALIGN=right class=smallheading bgcolor=#e8e8fa NOWRAP>Show Fragment Ions:&nbsp;&nbsp;</TD>
	<TD class=smalltext bgcolor=#f2f2f2 NOWRAP>
		&nbsp;<input type=checkbox name="show_frag_ions" value="1" $checked{"show_frag_ions"}>
	</TD>
</TR>
</TABLE>
</TD>
</TR></TABLE>
<br style="font-size:10">
</div>
</FORM>
<FORM name="add_mass" METHOD="POST" style="margin-top:0; margin-bottom:0" ACTION="$ourname">
<div id='edit_add_mass' style="display:none; border: solid #000099; border-width:1px; width:975">
<table cellspacing=0 cellpadding=0 border=0>
	<tr><td>&nbsp;</td></tr>	
	<tr><td width=15>&nbsp;</td>
	<td><table  cellspacing=0 cellpadding=0 border=0>
		<tr height=25><td class=smallheading bgcolor=#e8e8fa align=right nowrap>&nbsp;&nbsp;&nbsp;&nbsp;C-terminus(pro):&nbsp;&nbsp;</td>
					  <td class=smalltext bgcolor=#f2f2f2 nowrap>&nbsp;&nbsp;<INPUT TYPE=TEXT NAME="add_Cterm_pro" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;&nbsp;&nbsp;</td></tr>
		<tr height=25><td class=smallheading bgcolor=#e8e8fa align=right nowrap>N-terminus(pro):&nbsp;&nbsp;</td>
					  <td class=smalltext bgcolor=#f2f2f2 nowrap>&nbsp;&nbsp;<INPUT TYPE=TEXT NAME="add_Nterm_pro" MAXLENGTH=7 SIZE=7></td></tr>
		<tr height=25><td class=smallheading bgcolor=#e8e8fa align=right nowrap>C-terminus(pep):&nbsp;&nbsp;</td>
					  <td class=smalltext bgcolor=#f2f2f2 nowrap>&nbsp;&nbsp;<INPUT TYPE=TEXT NAME="add_Cterm_pep" MAXLENGTH=7 SIZE=7></td></tr>
		<tr height=25><td class=smallheading bgcolor=#eaeaf8 align=right nowrap>N-terminus(pep):&nbsp;&nbsp;</td>
					  <td class=smalltext bgcolor=#f2f2f2 nowrap>&nbsp;&nbsp;<INPUT TYPE=TEXT NAME="add_Nterm_pep" MAXLENGTH=7 SIZE=7></td></tr>
	</table></td>

	<td width=25>&nbsp;</td>
	<td><table cellspacing=0 cellpadding=0 border=0>
			  <tr height=25 bgcolor=#f2f2f2>
				<td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbsp;G:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_G" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				<td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbsp;A:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_A" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				<td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbsp;S:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_S" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				<td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbsp;P:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_P" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				<td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbsp;V:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_V" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				<td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbsp;T:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_T" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
			  </tr>
			  <tr height=25 bgcolor=#e8e8fa><td width=10>&nbsp;</td>
				   <TD class=smallheading>&nbsp;&nbspC:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_C" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspL:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_L" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspI:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_I" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspX:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_X" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspN:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_N" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspO:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_O" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
			  </tr>
			  <tr height=25 bgcolor=#f2f2f2><td width=10>&nbsp;</td>
				  <TD class=smallheading>&nbsp;&nbspB:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_B" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspD:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_D" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspQ:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_Q" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspK:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_K" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspZ:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_Z" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspE:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_E" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
			  </tr>
			  <tr height=25 bgcolor=#e8e8fa><td width=10>&nbsp;</td>
				  <TD class=smallheading>&nbsp;&nbspM:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_M" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspH:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_H" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspF:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_F" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspR:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_R" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspY:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_Y" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
				  <td width=10>&nbsp;</td><TD class=smallheading>&nbsp;&nbspW:&nbsp;&nbsp;</td><td class=smalltext><INPUT TYPE=TEXT NAME="add_W" MAXLENGTH=7 SIZE=7>&nbsp;&nbsp;</TD>
			  </tr>
		</table></td></tr>
	 <tr><td>&nbsp;</td></tr>
	 <tr><td colspan=6 align=center>
		<INPUT TYPE=button class="outlinebutton button" NAME="saveAddmass" VALUE="Save" onClick="saveValues(add_mass)">
		<INPUT TYPE=reset class="outlinebutton button" NAME="cancelAddmass" VALUE="Cancel" onClick="selectTab('advancedoptions_')">
	 </td><tr>
  </table>
<br style="font-size:10">					 
</div>					 
</FORM>

<FORM name="enzyme_info" METHOD="POST" style="margin-top:0; margin-bottom:0" ACTION="$ourname">
<div id="enzymes" style="display:none; border: solid #000099; border-width:1px; width:975">
<table cellspacing=0 cellpadding=0 border=0>
<tr><td>&nbsp;</td></tr>
<tr><td width=15>&nbsp;</td>
	<td valign=top>
	 <table cellspacing=0 cellpadding=0 border=0> 
		<TR height=20 bgcolor=#e8e8fa><TH></TH><TH ALIGN=left class=smallheading>Name</TH>
					<TH class=smallheading nowrap align=center>&nbsp;&nbsp;Offset&nbsp;&nbsp;</TH>
					<TH ALIGN=left class=smallheading nowrap>Sites</TH>
					<TH class=smallheading align=center nowrap>No-sites&nbsp;&nbsp</TH>
	   </TR>
	   <TR bgcolor=#f2f2f2><TH ALIGN=right class=smalltext>&nbsp;&nbsp;0.&nbsp;&nbsp;</TH>
			<TD class=smalltext>No Enzyme</TD>
			<TD ALIGN=center class=smalltext>0</TD>
			<TD class=smalltext>-</TD>
			<TD ALIGN=center class=smalltext>-</TD></TR>
    <script>
		var len = Math.floor(document.forms[0].Enzyme.options.length/2);
		for (i = 1; i < len + 1; i++)
		{
			document.writeln('<TR bgcolor=#f2f2f2>');
			document.writeln('	<TH ALIGN=right class=smallheading>' + i + '.&nbsp;&nbsp;</TH>');
			document.writeln('	<TD><INPUT NAME="enz_name' + i + '"style=font-size:12></TD>');
			document.writeln('	<TD ALIGN=center><INPUT NAME="enz_offset' + i + '" SIZE=1 MAXLENGTH=1 style=font-size:12></TD>');
			document.writeln('	<TD><INPUT NAME="enz_sites' + i + '"style=font-size:12></TD>');
			document.writeln('	<TD ALIGN=center><INPUT NAME="enz_no_sites' + i + '" SIZE=1 MAXLENGTH=1 style=font-size:12></TD>');
			document.writeln('</TR>');
		}
	</script>
	</table></td>
	<td width=25>&nbsp;</td>
	<td valign=top><table cellspacing=0 cellpadding=0 border=0> 
		<TR height=20 bgcolor=#e8e8fa><TH></TH><TH ALIGN=left class=smallheading>Name</TH>
					<TH class=smallheading align=center nowrap>&nbsp;&nbsp;Offset&nbsp;&nbsp;</TH>
					<TH ALIGN=left class=smallheading nowrap>Sites</TH>
					<TH class=smallheading align=center nowrap>No-sites&nbsp;&nbsp</TH>
	   </TR>	
	   <TR bgcolor=#f2f2f2><TH ALIGN=right class=smalltext></TH>
			<TD class=smalltext>-</TD>
			<TD ALIGN=center class=smalltext>-</TD>
			<TD class=smalltext>-</TD>
			<TD ALIGN=center class=smalltext>-</TD></TR>
    <script>
		for (i = len+1; i < document.forms[0].Enzyme.options.length; i++)
		{
			document.writeln('<TR bgcolor=#f2f2f2>');
			document.writeln('	<TH ALIGN=right class=smallheading>&nbsp;&nbsp;' + i + '.&nbsp;&nbsp;</TH>');
			document.writeln('	<TD><INPUT NAME="enz_name' + i + '"style=font-size:12></TD>');
			document.writeln('	<TD ALIGN=center><INPUT NAME="enz_offset' + i + '" SIZE=1 MAXLENGTH=1 style=font-size:12></TD>');
			document.writeln('	<TD><INPUT NAME="enz_sites' + i + '"style=font-size:12></TD>');
			document.writeln('	<TD ALIGN=center><INPUT NAME="enz_no_sites' + i + '" SIZE=1 MAXLENGTH=1 style=font-size:12></TD>');
			document.writeln('</TR>');
		}
	</script>
	</table></td></tr>
<tr><td>&nbsp;</td></tr>
<TR><TD align=center colspan=5>
	<INPUT TYPE=button class="outlinebutton button" NAME="saveEnzymes" VALUE="Save" onClick="saveValues(enzyme_info)"> 
	<INPUT TYPE=button class="outlinebutton button" NAME="cancelEnzymes" VALUE="Cancel" onClick="selectTab('advancedoptions_')">
</td></tr></table>
<br style="font-size:10">
</div>	
</form>

<FORM name="advanced_settings" METHOD="POST" style="margin-top:0; margin-bottom:0" ACTION="$ourname">
<div id="advanced" style="display:none; border: solid #000099; border-width:1px; width:975">
<table cellspacing=0 cellpadding=0 border=0>
<tr><td>&nbsp</td></tr>
<tr><td width=15>&nbsp;</td>
	<td valign=top>
	 <table cellspacing=0 cellpadding=2 border=0> 
		<TR><TD ALIGN=right NOWRAP class=smallheading bgcolor=#e8e8fa>Residues in Uppercase&nbsp;&nbsp;</TD><TD bgcolor=#f2f2f2 class=smalltext>&nbsp;<input type=checkbox name="residues_in_uppercase" value=1></TD></TR>
		<TR><TD ALIGN=right NOWRAP class=smallheading bgcolor=#e8e8fa>&nbsp;&nbsp;&nbsp;&nbsp;Max Internal Cleavage Sites&nbsp;&nbsp;</TD><TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<input name="max_int_cleavage" size=3 maxlength=3></TD></TR>
		<TR><TD ALIGN=right NOWRAP class=smallheading bgcolor=#e8e8fa>Match Peak Count&nbsp;&nbsp;</TD><TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<input name="match_peak_count" size=4 maxlength=4></TD></TR>
		<TR><TD ALIGN=right NOWRAP class=smallheading bgcolor=#e8e8fa>Match Peak Allowed Error&nbsp;&nbsp;</TD><TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<input name="match_peak_allowed_error" size=4 maxlength=4></TD></TR>
		<TR><TD ALIGN=right NOWRAP class=smallheading bgcolor=#e8e8fa>Match Peak Tolerance&nbsp;&nbsp;</TD><TD bgcolor=#f2f2f2 class=smalltext>&nbsp;&nbsp;<input name="match_peak_tolerance" size=4 maxlength=4>&nbsp;&nbsp;</TD></TR>
		<TR><TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Ion Cutoff Percentage:&nbsp;&nbsp;</TD><TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="ion_cutoff" SIZE=2 MAXLENGTH=2></TD></TR>

	</table>
	<td width=35>&nbsp;</td>
	<td valign=top>
	<table cellspacing=0 cellpadding=2 border=0> 
		<TR><TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>Protein Mass Filter:&nbsp;&nbsp;</TD><TD class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="prot_mass_filt_min"  SIZE=5>&nbsp;(Min)&nbsp;&nbsp;<INPUT NAME="prot_mass_filt_max" SIZE=5>&nbsp;(Max)&nbsp;&nbsp;</TD>
		<TR><TD ALIGN=right class=smallheading bgcolor=#e8e8fa nowrap>&nbsp;&nbsp;Remove Precursor Peak:&nbsp;&nbsp;</TD><TD class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=checkbox NAME="rem_prec_peak" VALUE="1"></TD></TR>
		<script>
		$alt_sequest_html
		$alt_runsequest_html
		$xml_output_html
		</script>
	</td></tr></TABLE>
<tr><td>&nbsp;</td></tr>
<tr><td align=center colspan=4>
		<INPUT TYPE=button class="outlinebutton button" NAME="saveAdvanced" VALUE="Save" onClick="saveValues(advanced_settings)"> 
		<INPUT TYPE=button class="outlinebutton button" NAME="cancelAdvanced" VALUE="Cancel" onClick="selectTab('advancedoptions_')">
</td></tr></table>
<br style="font-size:10">
</div>
</form>
<br style="font-size:15">
<div class="smalltext">
<A HREF="$SequestURL" target=_blank>SEQUEST</a>
is a registered trademark of the Univ. of Washington, J.Eng/J.Yates.   
<!-- <INPUT TYPE=checkbox NAME="test" VALUE="1">Test (for programmer's use only) -->
<!-- &nbsp;&nbsp;<a href="$webhelpdir/help_$ourshortname.html" target=_blank>Help</a> -->
</div>
</BODY>
</HTML>

FORMPAGE

    exit 0;
}


###### everything below is for running Sequest: it's executed when the form has been submitted

$seqid = "SEQ$dir" . "_" . time();

&error("You must enter your initials in the <B>Operator</B> field.") if (!defined $operator);

# so that status page comes up automatically
$statusurl = "$inspector?directory=$dir";

&error ("No directory given") if (!defined $dir);
&error ("No such directory: $dir") if (! (-d "$seqdir/$dir"));


chdir "$seqdir/$dir" || &error ("Could not change to $seqdir/$dir. $!");

# if we are asked to continue an interrupted run,
# skip all the other processing

if ($continue_unfinished && !$continue_different_params)
{

	$error = &sequest_launch("seqid" => $seqid, "onServer" => $runOnServer, "dir" => $dir, "continue" => 1, "start_suspended" => $FORM{"start_suspended"});
	&error("Failed to run Sequest: $error") if ($error);

	# this creates a flag to seqcomm_Q, indicating that the Q should ignore this run:
	if ($multiple_sequest_hosts) {
		&Q_immunize($runOnServer,$seqid) if ($FORM{"Q_immunity"});
	}

	# write to log file (added by cmw,7-24-98)
	&write_log($dir,"Sequest continued on $runOnServer " . localtime() . "  $operator");

	$url = $statusurl;
	&redirect ($url);

	exit 0;
}



###############################################################
# this is what happens when user presses "Run Sequest"

if (!defined $ModifiedAA8Num) {
#  $ModifiedAA8 = "C";
  $ModifiedAA8Num = "0.000";
}
if (!defined $ModifiedAA7Num) {
 # $ModifiedAA7 = "N";
  $ModifiedAA7Num = "0.000";
}

if ((!$ModifiedAA6) || (!defined $ModifiedAA6Num)) {
  $ModifiedAA6 = "X";
  $ModifiedAA6Num = "0.000";
}
if ((!$ModifiedAA5) || (!defined $ModifiedAA5Num)) {
  $ModifiedAA5 = "X";
  $ModifiedAA5Num = "0.000";
}
if ((!$ModifiedAA4) || (!defined $ModifiedAA4Num)) {
  $ModifiedAA4 = "X";
  $ModifiedAA4Num = "0.000";
}
if ((!$ModifiedAA3) || (!defined $ModifiedAA3Num)) {
  $ModifiedAA3 = "X";
  $ModifiedAA3Num = "0.000";
}
if ((!$ModifiedAA2) || (!defined $ModifiedAA2Num)) {
  $ModifiedAA2 = "C";
  $ModifiedAA2Num = "0.000";
}
if ((!$ModifiedAA1) || (!defined $ModifiedAA1Num)) {
  $ModifiedAA1 = "M";
  $ModifiedAA1ANum = "0.000";
}


unlink "run_selected.txt";

if ($DataFile eq "selected") 
{
  if (open(SELECTEDDTAS,"<selected_dtas.txt")) {
    @dtafiles = <SELECTEDDTAS>;
	close SELECTEDDTAS;
	chomp @dtafiles;
  } else {
    @dtafiles = ();
  }
  if ($#dtafiles + 1 == 0) {
    &error (qq(The directory $SearchDir has no selected DTA files. Go to <a href = "$VuDTA">VuDTA</A>),
	    " or hit the back button and use all DTA files.");
  }
  $filenames = join(" ", @dtafiles);

	# put file in this directory to indicate that this run uses selected DTAs
	open(RUNSEL,">run_selected.txt");
	print RUNSEL "This file is only for use by Sequest Launcher.  Do not delete it manually.\n";
	print RUNSEL "If this file exists, it means that the most recent Sequest run on this directory\n";
	print RUNSEL "used only selected DTA files.  The \"Continue Unfinished Run\" function needs to know this.";
	close(RUNSEL);
} 
else 
{
  opendir (THISDIR, ".");
  @dtafiles = grep /\.dta$/, readdir THISDIR;
  closedir THISDIR;

  if ($#dtafiles + 1 == 0) {
    &error (qq(The directory $SearchDir has no DTA files. Go to <a href = "$create_dta">Create Dta</A>.));
  }
  $filenames = join(" ", @dtafiles);
}


# Since we're about to run sequest on these files any post-sequest results on these files are now obsolete
&erase_post_sequest_results(@dtafiles);		# REP 10/16/01 

$files = join(" ", @dtafiles);

# get the database type
$path_to_db = "$dbdir/$db";
if ($nuc_read_frame eq "auto") {
  $nuc_read_frame = (&get_dbtype("$path_to_db")) ? 9 : 0;
}

# unchecked checkboxes must appear as "0" in sequest.params
$show_frag_ions = "0" unless ($show_frag_ions);
$pr_dupl_ref = "0" unless ($pr_dupl_ref);
$rem_prec_peak = "0" unless ($rem_prec_peak);
foreach $i (0..2) {
	$ion_series[$i] = "0" unless ($ion_series[$i]);
}


# edit sequest.params file

# When there are multiple hosts, pull the name of the proper server's local database directory from that machine's
# local include file
require "//$runOnServer$remote_webseqcommdir/seqcomm_var_$runOnServer.pl" if (($multiple_sequest_hosts) && (lc $ENV{'COMPUTERNAME'} ne lc $runOnServer));

&edit_paramsfile;


# run Sequest


if ($FORM{"test"})  # just display sequest.params, don't run Sequest
{
	$url = "$webseqdir/$dir/sequest.params";
	&redirect ($url);
}
else       # run Sequest and display sequest_status
{
	# delete all *.out files if asked
	if ($clear_existing) {
	  opendir (THISDIR, ".");
	  @allouts = grep /\.out$/, readdir THISDIR;
	  closedir THISDIR;
	  unlink @allouts;
	}

	# use_index is now obsolete because the type of run is now determined by Sequest based on the extension of the db (.fasta for
	# regular runs versus .fasta.hdr for turbo runs), so 2 of the fields in &sequest_launch are simply passed  0 -- P.Djeu 8-7-01
	$error = &sequest_launch("seqid" => $seqid, "onServer" => $runOnServer, "dir" => $dir, "db" => $db, "seconddb" => $seconddb, 
							 "files" => $files, "start_suspended" => $FORM{"start_suspended"}, "use_index" => 0, "check_index" => 0, 
							 "continue" => $continue_unfinished, "use_alt_sequest" => $use_alt_sequest, 
							 "alt_sequest_loc" => $alt_sequest_loc, "use_alt_runsequest" => $use_alt_runsequest,
							 "xml_output" => $xml_output, "normalize_xcorr" => $normalize_xcorr);
	&error("Failed to run Sequest: $error") if ($error);

	# this creates a flag to seqcomm_Q, indicating that the Q should ignore this run:
	if ($multiple_sequest_hosts) {
		&Q_immunize($runOnServer,$seqid) if ($FORM{"Q_immunity"});
	}

	# write to log file (added by cmw,7-24-98)
	$enzyme_name = ($enzyme == 0) ? "No Enzyme" : $enz_name[$enzyme];
	my $using_index;
	if ($db =~ /\.hdr$/) {
		$using_index = " (hdr)";
	} else {
		$using_index = "";
	}
	my $using_index2;
	if ($seconddb =~ /\.hdr$/) {
		$using_index2 = " (hdr)";
	} else {
		$using_index2 = "";
	}

	&write_log($dir,"Sequest started on $runOnServer " . localtime() . "  $db$using_index $seconddb$using_index2  $enzyme_name  $ModifiedAANum $ModifiedAA $ModifiedAA2Num $ModifiedAA2 $ModifiedAA3Num $ModifiedAA3 $ModifiedAA4Num $ModifiedAA4 $ModifiedAA5Num $ModifiedAA5 $ModifiedAA6Num $ModifiedAA6 mods $ModifiedAA7 $ModifiedAA8 $operator");

	if (!$auto_distribute) {
		$url = $statusurl;
	} else {
		$url = "$seqdistributor?distribute_using_defaults=1&distribute=" . $seqid . ":::" . $dir . ":::" . $db . ":::" . "$runOnServer:$seqid";

		if ($xml_output) {
			$url .= "&xml_output=$xml_output";
		}
		if ($normalize_xcorr) {
			$url .= "&normalize_xcorr=$normalize_xcorr";
		}
	}

	&redirect ($url);

}
exit 0;


# edit_paramsfile
# ---------------
# Makes sure sequest.params is in proper format for use with regular or .hdr databases, and then edits it appropriately.
# If the file is not in the proper format, a proper template file is copied over, edited, and then used.
# This subroutine requires a whole lot of variables from the main routine and should be called after all of the form data has
# been processed and before Sequest is actually run.
# Be sure not to change any of the main routine's variables before calling this routine.
#
# Arguments: None
# Returns: Nothing
sub edit_paramsfile {
	open(SEQPARAMS,"<sequest.params");	# Do not error, it is okay if this file doesn't exist; the template will just be copied over
	@lines = <SEQPARAMS>;
	close(SEQPARAMS);
	unless (grep(/^first_database_name/,@lines)) {
		# check $default_seqparams to make sure that it is in the proper format
		open (CHKPARAMS, "<$default_seqparams") || &error ("Could not open $default_seqparams $!");
		@lines = <CHKPARAMS>;
		close (CHKPARAMS);
		unless (grep(/^first_database_name/,@lines)) {
			&error("The params file template, $default_seqparams, is not in the proper format.");
		}

		# backup the local params file, copy the template over as the new local copy, and edit the new local copy
		if (-e "sequest.params") {
			rename("sequest.params","sequest.params_orig") || &error("Could not update SequestC2 format of <a href=\"$webseqdir/$dir/sequest.params_orig\">sequest.params_orig</a>.  Check permissions.");
		}
		copy($default_seqparams,"sequest.params") || &error("Could not update SequestC2 format of <a href=\"$webseqdir/$dir/sequest.params\">sequest.params</a>.  Check permissions.");
	}


	open (NEWPARAMS, "<sequest.params") || &error ("Could not open sequest.params $!");
	@lines = <NEWPARAMS>;
	close (NEWPARAMS);

	$whole = join("",@lines);
	($seq_info,$enz_info) = split(/\[SEQUEST_ENZYME_INFO\]*.\n/, $whole);

	$_ = $seq_info;


	# replace parameters in top portion of sequest.params
	s/^(database_name\s*=\s*)(.+?)(\s*;|\s*$)/$1$dbdir\\$db$3/m;
	s/^(first_database_name\s*=\s*)(.+?)(\s*;|\s*$)/$1$dbdir\\$db$3/m;
	
	# All very miserable because the second database may not be there, unlike all other values.
	# This is a kludge that could probably be better.
	if ($seconddb) {
		if (/^second_database_name\s*=\s*\n/m) {
			s/^(second_database_name\s*=\s*)\n/$1$dbdir\\$seconddb\n/m;
		} else {
			s/^(second_database_name\s*=\s*)(.+?)(\s*;|\s*$)/$1$dbdir\\$seconddb$3/m;
		}
	} else { # If seconddb isn't defined, remove the database from the sequest.params file if there is one defined
		unless (/^second_database_name\s*=\s*\n/m) {
			s/^(second_database_name\s*=\s*)(.+?)(\s*;|\s*$)/$1/m;
		}
	}
	
	s/^(nucleotide_reading_frame\s*=\s*)(.+?)(\s*;|\s*$)/$1$nuc_read_frame$3/m;
	s/^(enzyme_number\s*=\s*)(.+?)(\s*;|\s*$)/$1$enzyme$3/m;
	s/^(mass_type_parent\s*=\s*)(.+?)(\s*;|\s*$)/$1$is_mono_parent$3/m;
	s/^(mass_type_fragment\s*=\s*)(.+?)(\s*;|\s*$)/$1$is_mono_fragment$3/m;
	s/^(diff_search_options\s*=\s*)(.+?)(\s*;|\s*$)/$1$ModifiedAA1Num $ModifiedAA1 $ModifiedAA2Num $ModifiedAA2 $ModifiedAA3Num $ModifiedAA3 $ModifiedAA4Num $ModifiedAA4 $ModifiedAA5Num $ModifiedAA5 $ModifiedAA6Num $ModifiedAA6$3/m;
	
	# This has been added recently, so if it doesn't exist, add it to the sequest.params file.
	if (m/^term_diff_search_options\s*=\s*.+?(\s*;|\s*$)/m) {
		s/^(term_diff_search_options\s*=\s*)(.+?)(\s*;|\s*$)/$1$ModifiedAA8Num $ModifiedAA7Num$3/m;

	} else {
		s/^(diff_search_options.*?\n)/${1}term_diff_search_options = $ModifiedAA8Num $ModifiedAA7Num; c term, n term diff mods\n/m;
	}	
	
	s/^(show_fragment_ions\s*=\s*)(.+?)(\s*;|\s*$)/$1$show_frag_ions$3/m;
	s/^(ion_series\s*=\s*)(.+?)(\s*;|\s*$)/$1$ion_series$3/m;
	s/^(fragment_ion_tolerance\s*=\s*)(.+?)(\s*;|\s*$)/$1$frag_ion_tol$3/m;
	s/^(peptide_mass_tolerance\s*=\s*)(.+?)(\s*;|\s*$)/$1$pep_mass_tol$3/m;
	s/^(num_output_lines\s*=\s*)(.+?)(\s*;|\s*$)/$1$num_out_lines$3/m;
	s/^(num_description_lines\s*=\s*)(.+?)(\s*;|\s*$)/$1$num_desc_lines$3/m;
	s/^(print_duplicate_references\s*=\s*)(.+?)(\s*;|\s*$)/$1$pr_dupl_ref$3/m;

	# new SequestC2 parameters
	s/^(remove_precursor_peak\s*=\s*)(.+?)(\s*;|\s*$)/$1$rem_prec_peak$3/m;
	s/^(ion_cutoff_percentage\s*=\s*)(.+?)(\s*;|\s*$)/$1$ion_cutoff$3/m;
	s/^(protein_mass_filter\s*=\s*)(\S+)(\s*)(\S+)(\s*;|\s*$)/$1$prot_mass_filt_min$3$prot_mass_filt_max$5/m;
	s/^(sequence_header_filter\s*?=) *(.*)$/$1 $seq_head_filt/m;
	s/^(max_num_internal_cleavage_sites\s*=\s*)(.+?)(\s*;|\s*$)/$1$max_int_cleavage$3/m;
	s/^(match_peak_count\s*=\s*)(.+?)(\s*;|\s*$)/$1$match_peak_count$3/m;
	s/^(match_peak_allowed_error\s*=\s*)(.+?)(\s*;|\s*$)/$1$match_peak_allowed_error$3/m;
	s/^(match_peak_tolerance\s*=\s*)(.+?)(\s*;|\s*$)/$1$match_peak_tolerance$3/m;
	if (m/residues_in_upper_case/) {
		s/^(residues_in_upper_case\s*=\s*)(.+?)(\s*;|\s*$)/$1$residues_in_uppercase$3/m;
	}
	else {
		s/^(add_Cterm_protein)/residues_in_upper_case = $residues_in_uppercase             ; 0=no, 1=yes\n\n$1/m;
	}

	# replace parameters in add-mass portion of sequest.params



	# these two lines have changed since the C2 format of sequest.params
	s/^(add_Cterm_protein\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Cterm_pro$3/m;
	s/^(add_Nterm_protein\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Nterm_pro$3/m;

	s/^(add_Cterm_peptide\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Cterm_pep$3/m;
	s/^(add_Nterm_peptide\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Nterm_pep$3/m;
	s/^(add_G_Glycine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_G$3/m;
	s/^(add_A_Alanine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_A$3/m;
	s/^(add_S_Serine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_S$3/m;
	s/^(add_P_Proline\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_P$3/m;
	s/^(add_V_Valine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_V$3/m;
	s/^(add_T_Threonine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_T$3/m;
	s/^(add_C_Cysteine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_C$3/m;
	s/^(add_L_Leucine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_L$3/m;
	s/^(add_I_Isoleucine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_I$3/m;
	s/^(add_X_LorI\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_X$3/m;
	s/^(add_N_Asparagine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_N$3/m;
	s/^(add_O_Ornithine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_O$3/m;
	s/^(add_B_avg_NandD\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_B$3/m;
	s/^(add_D_Aspartic_Acid\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_D$3/m;
	s/^(add_Q_Glutamine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Q$3/m;
	s/^(add_K_Lysine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_K$3/m;
	s/^(add_Z_avg_QandE\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Z$3/m;
	s/^(add_E_Glutamic_Acid\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_E$3/m;
	s/^(add_M_Methionine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_M$3/m;
	s/^(add_H_Histidine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_H$3/m;
	s/^(add_F_Phenylalanine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_F$3/m;
	s/^(add_R_Arginine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_R$3/m;
	s/^(add_Y_Tyrosine\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Y$3/m;
	s/^(add_W_Tryptophan\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_W$3/m;


	$seq_info = $_;


	# replace parameters in enzyme-info portion of sequest.params
	$_ = $enz_info;

	# find out the width of each field in the file
	($num,$name,$offset,$sites,$no_sites) = /^(\d+\.\s*)(.+?\s+)(\d\s+)([A-Z\-]+\s+)([A-Z\-])/m;
	$len[0] = length($num) - 1;
	$len[1] = length($name) - 1;
	$len[2] = length($offset) - 1;
	$len[3] = length($sites) - 1;

	# we already know the right-most field can only have width 1

	# construct variable $new_enz_info as text to replace old $enz_info
	$new_enz_info = "";
	foreach $num (1..$#enz_name)
	{
		$new_enz_info .= sprintf("%-$len[0].$len[0]s %-$len[1].$len[1]s %-$len[2].$len[2]s %-$len[3].$len[3]s %1.1s\n",
			"$num.", $enz_name[$num], $enz_offset[$num], $enz_sites[$num], $enz_no_sites[$num]);
	}

	# delete all numbered lines of $enz_info after 0., and add $new_enz_info after 0.
	s/^[1-9].*\n//gm;
	s/^(0.*\n)/$1$new_enz_info/m;
	$enz_info = $_;

	# write to the file itself
	open (PARAMS, ">sequest.params") || &error ("Could not write to sequest.params file. $!");
	print PARAMS join("[SEQUEST_ENZYME_INFO]\n", $seq_info, $enz_info);
	close PARAMS;

	return;
}





sub error {
	&MS_pages_header ("Sequest Launcher Results", "#cc4080");
	my $dbnotfound;

	if ($_[0] =~ /Database/ && $_[0] =~ /is not available on/) {
		$dbnotfound = 1;
	}

	print '<hr><br>';
#	print ("<h2>Error:</h2>\n") if (!$dbnotfound);
	print "<p>$ICONS{'error'}";
	print (join ("\n", @_));

	if ($dbnotfound) {
		$runOnServer =~ tr/a-z/A-Z/;
		@text = ("Copy $db to $runOnServer");
		@links = ("$fastacopycat?db=$db&hosts=$runOnServer&run=1");
		&WhatDoYouWantToDoNow(\@text, \@links);
	}
	
	print("</p></body></html>\n");

	exit 1;
}



# return true if the database is a nucleotide database,
# false otherwise
#
# There are two ways to autodetect.  
# 1.  If the database is a .hdr file, the db type should be pulled directly from the database .hdr.
# 2.  If the database is a regular .fasta, then check if the database is more than 80% ACTG over
# the first 500 lines.  If so, we will assume it is nucleotide. Otherwise, assume it is protein.

sub get_dbtype {
	my ($db) = $_[0];

	if ($db =~ /.hdr$/) {
		# Look right in the header
		open (DB, "$db") || &error ("Could not open database $db for auto-detecting database type.");
		while ($line = <DB>) {
			last if ($line =~ /OrigDatabaseType/);
		}
		close DB;

		# Check if the proper line was never found
		&error ("Could not find OrigDatabaseType field in $db.") if (!($line));

		if ($line =~ /Nucleotide/) {
			return 1;
		} elsif ($line =~ /Protein/) {
			return 0;
		} else {
			&error ("Unknown OrigDatabaseType field in $db: $line");
		}
	}

	# if control reaches this point, the database is a regular fasta database

	# Count the percentage of nucleotide bases in the first 500 lines, if it is > 80%, assume the database is
	# nucleotide.  Otherwise, assume the database is protein.
	my ($line, $numchars, $numnucs, $numlines);

	open (DB, "$db") || &error ("Could not open database $db for auto-detecting database type.");
	while ($line = <DB>) {
		next if ($line =~ m!^>!);

		chomp $line;
		$numchars += length ($line);
		$numnucs += $line =~ tr/ACTGactg/ACTGactg/;

		$numlines++;
		last if ($numlines >= 500);
	}
	close DB;

	return (1) if ($numnucs > .8 * $numchars);

	return (0);
}

# erase_post_sequest_results
# This subroutine is used to erase any existing results that will become obsolete when sequest is run.
# Input is a list of dtas
# This deletes appropriate lines in results files for sig_calc and score_combiner
sub erase_post_sequest_results{
	
	my(%onList,$line,$dta,$score,$score2,@newlines);

	# hash the dtas 
	foreach (@_) {
		$onList{$_} = 1;
	}
	
	# take care of sig calc results
	if(-e "$seqdir/$dir/probability.txt"){
		
		# read in the old file
		open SIGCALC,  "$seqdir/$dir/probability.txt";

		while(<SIGCALC>){
			
			$line = $_;

			# exclude lines corresponding to dtas on the list
			($dta,$score) = split / /, $line;
			push @newlines, $line unless($onList{$dta});
		}
		close SIGCALC;
		
		# rewrite the file
		unlink "$seqdir/$dir/probability.txt";
		open NEWFILE, ">$seqdir/$dir/probability.txt";
		print NEWFILE @newlines;
		close NEWFILE;
	}

	# reinitialize
	@newlines = ();

	# now do the same for combined scores
	if(-e "$seqdir/$dir/seq_score_combiner.txt"){
		
		# read in the old file
		open SF,  "$seqdir/$dir/seq_score_combiner.txt";

		while(<SF>){
			
			$line = $_;
			# exclude lines corresponding to dtas on the list
			($dta,$score,$score2) = split / /, $line;
			push @newlines, $line unless($onList{$dta});
		}
		close SF;

		# rewrite the file
		unlink "$seqdir/$dir/seq_score_combiner.txt";
		open NEWFILE, ">$seqdir/$dir/seq_score_combiner.txt";
		print NEWFILE @newlines;
		close NEWFILE;
	}	

}