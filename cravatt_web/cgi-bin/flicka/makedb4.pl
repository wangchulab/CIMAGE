#!/usr/local/bin/perl

#-------------------------------------
#	MakeDB4
#	(C)1999 Harvard University
#	
#	W. S. Lane/P. Djeu
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 7/18/00 by Peter Djeu
# Description: A web wrapper around the makedb4.exe indexing program.  Writes the parameters selected on the web
# page to the parameters file, and then calls the script runmakedb4.pl (via SeqComm when using a remote makedb4
# machine, and directly otherwise) to actually run the .exe.
#
# CGI Parameters:
# Database - the name of the database
# proceed - 0 for stay on first page, one for execute makedb4.exe

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
	require "microchem_form_defaults.pl";
	require "html_bio_include.pl";
	require "html_include.pl";
}

#################################################
# Default Settings

# size_estimate_constants
#
#
# N.B. To force the indexing to run, lower these values so that diskspace error checking doesn't kick in.
#
# Still under testing because haven't thought of an algorithm to determine the size of the final index.
# Based on the number of internal cleavage sites, multiply the actual db's size by this constant to
# get the amount of disk space makedb4 believes it needs.  The peptide mass range and peptide size range
# should also be factored in later.
# This estimate is for the final size of the index, which is multiplied by 3 to determine the total disk space (the
# factor of 3 is not included in these constants, it is hard coded below)
# -- 8-25-00, P.Djeu
%size_estimate_constants = (
	"0"	=>	$DEFS_MAKEDB{"Growth Constant 0"},
	"1"	=>	$DEFS_MAKEDB{"Growth Constant 1"},
	"2"	=>	$DEFS_MAKEDB{"Growth Constant 2"},
	"3"	=>	$DEFS_MAKEDB{"Growth Constant 3"},
	"4"	=>	$DEFS_MAKEDB{"Growth Constant 4"},
	"5"	=>	$DEFS_MAKEDB{"Growth Constant 5"}
);

$paramsfile_name = "makedb.params";
$webserver_dbdir = $dbdir;
$auto_distribute = $DEFS_MAKEDB{"Auto-distribute"} eq "yes" ? "checked" : "";

# This must be done before multiple sequest hosts is done, or else $dbdir will be incorrect
&get_dbases;

if ($multiple_sequest_hosts) {
	require "seqcomm_include.pl";

	$runOnServer = $DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER;

	#remote run. Note that this script is always run on the webserver => $ENV{'COMPUTERNAME'} = $webserver
	if ($DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER ne $webserver)
	{
		# Set $dbdir with include file on remote host, must use -e conditional or else error won't appear (due to 'require' short-circuiting?)
		if (-e "\\\\$runOnServer$remote_webseqcommdir/seqcomm_var_$runOnServer.pl") {
			require "\\\\$runOnServer$remote_webseqcommdir/seqcomm_var_$runOnServer.pl";
		} else {
			&error("Cannot find \\\\$runOnServer$remote_webseqcommdir/seqcomm_var_$runOnServer.pl: $!", 1);
		}
	}
	#local run on the webserver
	else
	{
		# Set $dbdir with include file on remote host, must use -e conditional or else error won't appear (due to 'require' short-circuiting?)
		if (-e "$seqcommdir/seqcomm_var_$runOnServer.pl") {
			require "$seqcommdir/seqcomm_var_$runOnServer.pl";
		} else {
			&error("Cannot find $seqcommdir/seqcomm_var_$runOnServer.pl: $!", 1);
		}
	}

	$remote_db = "\\\\$runOnServer/Database";
	$out_params = "$remote_db/makedb/$paramsfile_name";
	if (!(defined $makedb_dir)) {
		&error("SeqComm params file for the MakeDB4 machine needs to define \$makedb_dir", 1);
	} elsif ($makedb_dir eq "") {
		&error("No MakeDB4 output dir specified in the SeqComm params file for $runOnServer; $runOnServer is most likely NOT a MakeDB4 machine", 1);
	}
} else {
	# Use local $dbdir from standard include file
	$runOnServer = $ENV{'COMPUTERNAME'};
	$out_params = "$dbdir/makedb/$paramsfile_name";
	$scratch_dbdir = "$dbdir";
}

################################################
# end Defailt Settings


#######################################
# Initial output
# this may or may not be appropriate; you might prefer to put a separate call to the header
# subroutine in each control branch of your program (e.g. in &output_form)
&cgi_receive;

&MS_pages_header("DB Indexer","#8800FF", "tabvalues=MakeDB4&MakeDB4:\"$makedb4\"&FastaIdx:\"$fastaidx_web\"");

$db = $FORM{"Database"};


#######################################
# Fetching defaults values
#
# The defaults for the web page are found in either:
# 1. The form defaults file (see Site Administration on the home page)
# 2. The makedb template file (see microchem_var.pl).
#
# In cases of redundancy, the order of precedence is 1., followed by 2.


#######################################
# Flow control
&output_form unless (defined $FORM{"Database"} && $FORM{"proceed"});

&launch_remote;

exit 0;

######################################
# Main action

# Use the default template to make a new copy before executing makedb4.exe.  Also, prepare the command line args for proper
# input (i.e. strip unspecified args).
sub launch_remote {
	# Check to see if ftp_fastadb.pl is running, if it is, postpone indexing
	$stamp = "$webserver_dbdir/.ftp_fastadb_running";
	if (open(STAMP, ">$stamp")) {
		if (!(flock STAMP, ($LOCK_EX | $LOCK_NB))) {
			# File locked by ftp_fastadb.pl, which means it is running
			&error("Database Autodownload is currently running.  Unable to launch MakeDB4.");
			close STAMP;
		} else {
			close STAMP;
			unlink "$stamp";
		}
	}
	# Check to see if itself is running, if it is, postpone indexing
	$stamp = "$webserver_dbdir/.runmakedb_running";
	if (open(STAMP, ">$stamp")) {
		unless (flock STAMP, ($LOCK_EX | $LOCK_NB)) {
			# File locked by ftp_fastadb.pl, which means it is running
			&error("Another instance of MakeDB4 is already running.  Please wait until it finishes.");
		}
		close STAMP;
	}


	# Check to make sure database exits on the indexing server
	if ($multiple_sequest_hosts) {
		if (!(-e "$remote_db/$db")) {
			&error("The remote database $remote_db/$db could not be found");
		}
	} else {
		if (!(-e "$dbdir/$db")) {
			&error("The database $dbdir/$db could not be found");
		}
	}

	# Make checks for diskspace
	$cmdline = ($runOnServer eq $ENV{'COMPUTERNAME'}) ? "$dbdir" : "\\\\$runOnServer\\Database";
	$cmdline =~ s!/!\\!gi;   #make sure directory paths are properly formated  
	$_ = `dir $cmdline`;
	($bytes_free) = /([\d,]+) bytes free/;
	$bytes_free =~ s/,//g;
	$temp_path = ($multiple_sequest_hosts) ? "$remote_db/$db" : "$dbdir/$db";
	$dbsize = &dos_file_size("$temp_path");
	if ($dbsize <= 0) {
		&error("Could not check the size of $temp_path.  MakeDB4 halted.");
	}

	$growth_constant = $size_estimate_constants{"$FORM{'max_num_internal_cleavage_sites'}"};
	# The hard coded 3 is for: the final index itself, the sort files, and alltryptic.txt, each about the size
	# of the final index. (3/01) wsl changed to 2.8 for trials)
	$total_needed = &precision($dbsize * $growth_constant * 2.8, 0);

	if ($total_needed > $bytes_free) {
		# If this form value is specified, run regardless of diskspace failure.  Just print a warning message
		if ($FORM{"diskspace_override"}) {
			print <<EOF;
<br>Warning: Not enough disk space to index $temp_path.<br><br>
Using the growth factor of <b>$size_estimate_constants{"$FORM{'max_num_internal_cleavage_sites'}"}</b> (corresponding
to <b>$FORM{'max_num_internal_cleavage_sites'}</b> max internal cleavage site(s)),
an estimated <b>$total_needed</b> bytes were needed, and only <b>$bytes_free</b> bytes were available.<br><br>
Running MakeDB4 anyways.
EOF
			# Now, proceed to altering the params file
		} else {

			$err_msg = <<EOF;
Not enough disk space to index $temp_path.<br><br>
Using the growth factor of <b>$size_estimate_constants{"$FORM{'max_num_internal_cleavage_sites'}"}</b> (corresponding
to <b>$FORM{'max_num_internal_cleavage_sites'}</b> max internal cleavage site(s)),
an estimated <b>$total_needed</b> bytes were needed, and only <b>$bytes_free</b> bytes were available.  MakeDB4 halted.<br><br>
The growth factor can be changed in the Form Defaults Editor.
EOF
			&error($err_msg);	# Stop the script
		}
	}

	open (PARAMS, "<$default_makedbparams") || &error ("Could not open $paramsfile_name template. $!");
	@lines = <PARAMS>;
	close (PARAMS);

	$whole = join("",@lines);

	# Alter new params file if default is not picked, else make an exact copy of the template (don't do s/// modifications)
	if ($db ne "$paramsfile_name") {
		($seq_info,$enz_info) = split(/\[SEQUEST_ENZYME_INFO\]*.\n/, $whole);

		# get rid of base pathname if it exists
		if (defined $FORM{"temp_dir"}) {
			$temp_dir = $FORM{"temp_dir"};

			# remove shell meta-characters
			$temp_dir =~ tr/A-Za-z0-9\/-_//cd;
		} else {
			$temp_dir = $DEFS_MAKEDB{"Temp Directory"};
		}
		# Remove terminating slash in the directory path since it will be added in this file
		$temp_dir =~ s!(/$|\\$)!!;

		if (defined $FORM{"out_dir"}) {
			$out_dir = $FORM{"out_dir"};

			# remove shell meta-characters
			$out_dir =~ tr/A-Za-z0-9\/-_//cd;
		} else {
			$out_dir = $DEFS_MAKEDB{"Index Output Directory"};
		}
		# Remove terminating slash in the directory path since it will be added in this file
		$out_dir =~ s!(/$|\\$)!!;

		if (!$multiple_sequest_hosts) {
			if (!(-d "$temp_dir")) {
				&error("The temp directory $temp_dir could not be found.");
			}
			if (!(-d "$out_dir")) {
				&error("The index output directory $out_dir could not be found.");
			}
		}

		# For multiple sequest hosts, some of the drives are not web-accessible, so there is no real
		# way to check if they exist or not -- we will just have to assume the user-specified paths
		# are accurate

		# Get popup settings from hidden form elements, do for all 3 windows
		# input from add-mass pop-up window
		$add_Cterm = $FORM{"add_Cterm"};
		$add_Nterm = $FORM{"add_Nterm"};
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

		# end of getting form info

		# autodetect the database type
		if ($FORM{"protein_or_nucleotide_dbase"} == 2) {
			$FORM{"protein_or_nucleotide_dbase"} = &get_dbtype("$webserver_dbdir/$db");
		}

		# If the database is protein, than there is no need for a nucleotide reading frame
		if (!$FORM{"protein_or_nucleotide_dbase"}) {
			$FORM{"nucleotide_reading_frames"} = 0;
		}

		# if certain diff mods are not specified, use the default placeholders:
		# Mod AA: 0.0000 M
		# Mod AA2: 0.0000 C
		# Mod AA3: 0.0000 X
		if ((!(defined $FORM{"ModifiedAA1"})) || ($FORM{"ModifiedAA1"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA1"} = "M";
			$FORM{"ModifiedAA1Num"} = "0.0000";
		}
		if (!((defined $FORM{"ModifiedAA2"})) || ($FORM{"ModifiedAA2"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA2"} = "C";
			$FORM{"ModifiedAA2Num"} = "0.0000";
		}
		if (!((defined $FORM{"ModifiedAA3"})) || ($FORM{"ModifiedAA3"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA3"} = "X";
			$FORM{"ModifiedAA3Num"} = "0.0000";
		}
		if (!((defined $FORM{"ModifiedAA4"})) || ($FORM{"ModifiedAA4"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA4"} = "X";
			$FORM{"ModifiedAA4Num"} = "0.0000";
		}
		if (!((defined $FORM{"ModifiedAA5"})) || ($FORM{"ModifiedAA5"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA5"} = "X";
			$FORM{"ModifiedAA5Num"} = "0.0000";
		}
		if (!((defined $FORM{"ModifiedAA6"})) || ($FORM{"ModifiedAA6"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA6"} = "X";
			$FORM{"ModifiedAA6Num"} = "0.0000";
		}
		if (!((defined $FORM{"ModifiedAA7"})) || ($FORM{"ModifiedAA7"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA7"} = "X";
			$FORM{"ModifiedAA7Num"} = "0.0000";
		}
		if (!((defined $FORM{"ModifiedAA8"})) || ($FORM{"ModifiedAA8"} =~ /^\s*$/)) {
			$FORM{"ModifiedAA8"} = "X";
			$FORM{"ModifiedAA8Num"} = "0.0000";
		}

		$_ = $seq_info;
		
		# Begin editing makedb.params file.  Most directory paths come from the Machine-specific SeqComm var file

		s/^(database_name\s*=\s*)(.+?)(\s*;|\s*$)/$1$dbdir\\$db$3/m;
		s/^(sort_directory\s*=\s*)(.+?)(\s*;|\s*$)/$1$temp_dir$3/m;
		s/^(sort_program\s*=\s*)(.+?)(\s*;|\s*$)/$1$makedb_dir\\sort.exe$3/m;
		s/^(enzyme_number\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"Enzyme"}$3/m;
		s/^(protein_or_nucleotide_dbase\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"protein_or_nucleotide_dbase"}$3/m;
		s/^(nucleotide_reading_frames\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"nucleotide_reading_frames"}$3/m;
		s/^(use_mono\/avg_masses\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"use_mono\/avg_masses"}$3/m;
		s/^(min_peptide_mass\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"min_peptide_mass"}$3/m;
		s/^(max_peptide_mass\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"max_peptide_mass"}$3/m;
		s/^(min_peptide_size\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"min_peptide_size"}$3/m;
		s/^(max_peptide_size\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"max_peptide_size"}$3/m;
		s/^(max_num_internal_cleavage_sites\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"max_num_internal_cleavage_sites"}$3/m;
		s/^(max_num_differential_AA_per_mod\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"max_num_diff_aa_per_mod"}$3/m;

		s/^(diff_search_options\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"ModifiedAA1Num"} $FORM{"ModifiedAA1"} $FORM{"ModifiedAA2Num"} $FORM{"ModifiedAA2"} $FORM{"ModifiedAA3Num"} $FORM{"ModifiedAA3"} $FORM{"ModifiedAA4Num"} $FORM{"ModifiedAA4"} $FORM{"ModifiedAA5Num"} $FORM{"ModifiedAA5"} $FORM{"ModifiedAA6Num"} $FORM{"ModifiedAA6"}$3/m;

		# This has been added recently, so if it doesn't exist, add it to the sequest.params file.
		if (m/^term_diff_search_options\s*=\s*.+?(\s*;|\s*$)/m) {
			s/^(term_diff_search_options\s*=\s*)(.+?)(\s*;|\s*$)/$1$FORM{"ModifiedAA8Num"} $FORM{"ModifiedAA7Num"}$3/m;
		} else {
			s/^(diff_search_options.*?\n)/${1}term_diff_search_options = $FORM{"ModifiedAA8Num"} $FORM{"ModifiedAA7Num"}; c term, n term diff mods\n/m;
		}	

		# replace parameters in add-mass portion of sequest.params
		s/^(add_Cterm_peptide\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Cterm$3/m;
		s/^(add_Nterm_peptide\s*=\s*)(.+?)(\s*;|\s*$)/$1$add_Nterm$3/m;
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

		$whole = join("[SEQUEST_ENZYME_INFO]\n", $seq_info, $enz_info);
	}

	# write to the file itself
	open (PARAMS, ">$out_params") || &error ("Could not write to $out_params. $!");
	print PARAMS "$whole";
	close PARAMS;

	if ($FORM{'print_params_only'}) {
		# Print out the params file
		$whole =~ s/\n/<br>\n/g;
		print "$whole";
		print "</body></html>";
	} else {
		# Run makedb4

		#### cmd line
		# -Ostring -- the indexed database to be created, where string is the name
		# -F -- if specified, use multiple temp files during indexing
		# -I -- if specified, display additional information about indexing
		# -U -- if specified, use a unique sequence sort (database will be smaller, but no duplicates)
		# -C -- if specified, the database will ne considered to be chromosome data
		# -T -- if specified, timestamps will be printed during each step
		# -Bnumber -- number can be 1-4, inclusive; if specified, certain stages of the makedb4 process will be bypassed
		#	-B1 - skip generating the digest header
		#	-B2 - skip generating the digest index
		#	-B3 - skip generating the peptide txt files
		#	-B4 - skip sorting the peptide txt files

		# Get the name of the temp file to do scratch work (with .tmp extension), if sepecified on the form, use it, otherwise
		# use the name of the selected database
		if (defined $FORM{"indexed_db"}) {
			$indexed_db = $FORM{"indexed_db"};
		} else {	# Use name of the selected database
			$indexed_db = $db . ".hdr";
		}
		
		# Output the index to the new repository in $scratch_dbdir (machine specific dir) instead of the regular fastadb dir
		# because the indexed db's are so large
		$indexed_db = "$out_dir\\$indexed_db";

		# if an optional arg is unspecified, leave it out
		# -O must always be specified for log creation / renaming puposes in runmakedb4.pl
		$args = qq(-O$indexed_db -F -I -T);
		$args .= qq( -U) if ($FORM{"unique_seq_sort"});
		$args .= qq( -C) if ($FORM{"chromosome_data"});
		$args .= qq( -B$FORM{"bypass"}) unless (($FORM{"bypass"} == 0) || (!(defined $FORM{"bypass"})));
		$args .= qq( -D) if ($FORM{"auto_distribute"});

		if ($runOnServer eq $ENV{'COMPUTERNAME'}) {
			$args .= qq( stayon=0);			#for a local run shut down runmakedb4.pl as soon as it's done since no console will pop-up
		} else {
			$args .= qq( stayon=1);
			# If we're running remotely, we want the hdr to be moved over to the webserver automatically when the index is made
			$args .= qq( webcopy=1);
		}

		# Code adapted from seqindex.pl
		print "<div><p>";
		if ($runOnServer eq $ENV{'COMPUTERNAME'}) {
			# run locally
			print "<BR>Running locally, on machine $runOnServer<BR><BR>\n";
			print "Command line: runmakedb4.pl $args . . .<BR>\n";
			print "The indexed database will appear in <b>$out_dir</b>.<BR>\n";

			&run_in_background("$perl $cgidir/runmakedb4.pl $args");
		} else {
			print "<BR>Running remotely, on server $runOnServer<BR><BR>\n";
			print "Command line: runmakedb4.pl $args . . .<BR>\n";
			print "The indexed database will appear in <b>$out_dir</b>.<BR>\n";

			&seqcomm_send($runOnServer, "run_in_background&\$perl \$cgidir/runmakedb4.pl $args", "\$seqcommdir_local");
		}
		print <<EOF;
</body></html>
EOF

	}
	
	exit 0;
}


#######################################
# subroutines (other than &output_form and &error, see below)




#######################################
# Main form subroutine
# Most of the params parsing is adapted from sequest_launcher.pl
sub output_form {
	@enz_name = ();
	open (PARAMS, "<$default_makedbparams") || &error ("Could not open $paramsfile_name template. $!");
	@lines = <PARAMS>;
	close (PARAMS);

	$whole = join("",@lines);

	($seq_info,$enz_info) = split(/\[SEQUEST_ENZYME_INFO\]*.\n/, $whole);

	$_ = $seq_info;
	# add-mass portion
	($add_Cterm) = /^add_Cterm_peptide\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Cterm);
	($add_Nterm) = /^add_Nterm_peptide\s*=\s*(.*?)(\s*;|\s*$)/m unless (defined $add_Nterm);
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

	#  advanced setting portion
	$def_out_dir = $DEFS_MAKEDB{"Index Output Directory"};
	$def_temp_dir = $DEFS_MAKEDB{"Temp Directory"};
	$def_min_pep_size = $DEFS_MAKEDB{"Minimum Peptide Size"};
	$def_max_pep_size = $DEFS_MAKEDB{"Maximum Peptide Size"};
	$def_unique_seq_sort = ($DEFS_MAKEDB{"Unique Sequence Sort"} eq "yes") ? "1" : "0";
	$def_chromosome_data = ($DEFS_MAKEDB{"Chromosome Data"} eq "yes") ? "1" : "0";

	# main page's defaults
	# For database, order of precedence is form, then form_defaults, then nr.fasta
	$def_database = (defined $FORM{"Database"}) ? $FORM{"Database"} : $DEFS_MAKEDB{"Database"};
	$def_database = (grep /$def_database/, @ordered_db_names) ? $def_database : "nr.fasta";
	$def_enzyme = (defined $FORM{"Enzyme"}) ? $FORM{"Enzyme"} : $DEFS_MAKEDB{"Enzyme"};
	$def_enzyme = (grep /$def_enzyme/, @enz_name) ? $def_enzyme : "Trypsin Strict";
	%def_selected = ();
	$def_selected{$DEFS_MAKEDB{"Database Type"}} = " checked";
	$def_selected{$DEFS_MAKEDB{"Nucleotide Reading Frame"}} = " checked";
	$def_selected{$DEFS_MAKEDB{"Monoisotopic or Average Mass"}} = " checked";
	$def_min_pep_mass = $DEFS_MAKEDB{"Minimum Peptide Mass"};
	$def_max_pep_mass = $DEFS_MAKEDB{"Maximum Peptide Mass"};
	$def_selected{"max_internal$DEFS_MAKEDB{'Max Internal Cleavage Sites'}"} = " selected";
	$def_max_diff_aa = $DEFS_MAKEDB{"Max Diff AAs per Mod"};
	$def_ModifiedAA1 = $DEFS_MAKEDB{"Modified AA"};
	$def_ModifiedAA1Num = $DEFS_MAKEDB{"Modified AA num"};
	$def_ModifiedAA2 = $DEFS_MAKEDB{"2nd Modified AA"};
	$def_ModifiedAA2Num = $DEFS_MAKEDB{"2nd Modified AA num"};
	$def_ModifiedAA3 = $DEFS_MAKEDB{"3rd Modified AA"};
	$def_ModifiedAA3Num = $DEFS_MAKEDB{"3rd Modified AA num"};
	$def_ModifiedAA4 = $DEFS_MAKEDB{"4th Modified AA"};
	$def_ModifiedAA4Num = $DEFS_MAKEDB{"4th Modified AA num"};
	$def_ModifiedAA5 = $DEFS_MAKEDB{"5th Modified AA"};
	$def_ModifiedAA5Num = $DEFS_MAKEDB{"5th Modified AA num"};
	$def_ModifiedAA6 = $DEFS_MAKEDB{"6th Modified AA"};
	$def_ModifiedAA6Num = $DEFS_MAKEDB{"6th Modified AA num"};
	$def_ModifiedAA7Num = $DEFS_MAKEDB{"C-term mod num"};
	$def_ModifiedAA8Num = $DEFS_MAKEDB{"N-term mod num"};



	# Convert the strings from form defaults into numbers, which are used on the forms
	if ($DEFS_MAKEDB{"Bypass"} eq "None") {
		# To allow for multiple radio buttons to have a "None" feature specified in %DEFS_MAKEDB, use "Bypass_None"
		$def_bypass = 0;
	} elsif ($DEFS_MAKEDB{"Bypass"} eq "Digest Header") {
		$def_bypass = 1;
	} elsif ($DEFS_MAKEDB{"Bypass"} eq "Digest Index") {
		$def_bypass = 2;
	} elsif ($DEFS_MAKEDB{"Bypass"} eq "Peptide Files") {
		$def_bypass = 3;
	} elsif ($DEFS_MAKEDB{"Bypass"} eq "Sorting Peptide Files") {
		$def_bypass = 4;
	} else {
		# Default to no bypass
		$def_bypass = 0;
	}

	# reading of default values ends here


	&load_java_dbnames;
	&load_java_popups;

	my $databaseEnzymeTable = &createDatabaseEnzymeTable();
	my $optionsTable = &createOptionsTable();

	# Now create the mod table box
	my @chars = ($def_ModifiedAA1, $def_ModifiedAA2, $def_ModifiedAA3, $def_ModifiedAA4, $def_ModifiedAA5, $def_ModifiedAA6, $def_ModifiedAA7, $def_ModifiedAA8);
	my @values= ($def_ModifiedAA1Num, $def_ModifiedAA2Num, $def_ModifiedAA3Num, $def_ModifiedAA4Num, $def_ModifiedAA5Num, $def_ModifiedAA6Num, $def_modifiedAA7Num, $def_modifiedAA8Num);
	my $modTable = &create_mod_box("characters" => \@chars, "masses" => \@values);

	my $helpLink = &create_link();

	print <<EOF;

<div>

<BR>

<form method="POST" action="$ourname">

<TABLE cellspacing=0 cellpadding=0 border=0>
	<TR>
	<TD>
		<TABLE cellspacing=0 cellpadding=0>
			<TR><TD>
				$databaseEnzymeTable<BR>$optionsTable
			</TD></TR>
		</TABLE>
	</TD>
	<TD width=40></TD>
	<TD align=left valign=top>$modTable
		<BR>
		&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type="submit" class="outlinebutton" style="cursor:hand;" value="MakeDB4">
		&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$helpLink
	</TD>
	</TR>
</TABLE>


<TR><TD><input type ="hidden" name="proceed" value="1">&nbsp;</TD></TR>
<!--&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE=checkbox NAME="print_params_only" VALUE="1">Test (for programmer's use only)-->
</TR>
</TABLE>

<HR>

<TABLE WIDTH=100%><TR><TD WIDTH=33%>
	<CENTER><INPUT TYPE=button class="outlinebutton" style="cursor:hand;" VALUE="Edit Add-Mass" onClick="addmass_open()"></CENTER>
</TD><TD WIDTH=34%>
	<CENTER><INPUT TYPE=button class="outlinebutton" style="cursor:hand;" VALUE="Edit Enzyme Info" onClick="enzymes_open()"></CENTER>
</TD><TD WIDTH=33%>
	<CENTER><INPUT TYPE=button  class="outlinebutton" style="cursor:hand;" VALUE="Edit Advanced" onClick="advanced_open()"></CENTER>
</TD></TR>
</TABLE>

<!-- hidden CGI-info for editing the middle and bottom parts of sequest.params
     these values can be altered by the Javascript pop-up windows //-->

<!-- AddMass window -->
<INPUT TYPE=hidden NAME="add_Cterm" VALUE="$add_Cterm">
<INPUT TYPE=hidden NAME="add_Nterm" VALUE="$add_Nterm">
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
EOF
	# enzymes window
	foreach $num (1..$#enz_name)
	{
	print <<EOF;
<INPUT TYPE=hidden NAME="enz_name$num" VALUE="$enz_name[$num]">
<INPUT TYPE=hidden NAME="enz_offset$num" VALUE="$enz_offset[$num]">
<INPUT TYPE=hidden NAME="enz_sites$num" VALUE="$enz_sites[$num]">
<INPUT TYPE=hidden NAME="enz_no_sites$num" VALUE="$enz_no_sites[$num]">
EOF
	}
	
	# advanced window
	print <<EOF;


<!-- Advanced window -->
<INPUT TYPE=hidden NAME="out_dir" VALUE="$def_out_dir">
<INPUT TYPE=hidden NAME="temp_dir" VALUE="$def_temp_dir">
<INPUT TYPE=hidden NAME="min_peptide_size" VALUE="$def_min_pep_size">
<INPUT TYPE=hidden NAME="max_peptide_size" VALUE="$def_max_pep_size">
<INPUT TYPE=hidden NAME="unique_seq_sort" VALUE="$def_unique_seq_sort">
<INPUT TYPE=hidden NAME="diskspace_override" VALUE="0">
EOF


	print "</FORM></div></body></html>";

	exit 0;
}

sub createOptionsTable {
	my $table = <<EOF;

	<table cellspacing=0 cellpadding=0 border=0>
<tr>
	<td colspan=2>&nbsp;&nbsp;
	<table cellspacing=0 cellpadding=0 bgcolor="#e8e8fa" height=20 width=100%><tr>
		<td width=20><img src="${webimagedir}/ul-corner.gif" width=10 height=20></td>
		<td width=100% class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;Options</td>
		<td width=20><img src="${webimagedir}/ur-corner.gif" width=10 height=20></td>
	</tr></table>
	</td>
</tr>

<tr><td colspan=2><table cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>

<TR height=25>
	<TD class=title>Indexed Database Name:&nbsp;&nbsp;</TD>
	<TD class=data>&nbsp;
		<input type="text" name="indexed_db" value="" size="30" maxlength="1024">&nbsp;&nbsp;
	</TD>
</TR>

<TR height=25>
	<TD class=title>Nucleotide Reading Frames:&nbsp;&nbsp;</TD>
	<TD class=data>&nbsp;
		<input type="radio" name="nucleotide_reading_frames" value="1"$def_selected{"3 Foward"}>3 Foward&nbsp;&nbsp;
		<input type="radio" name="nucleotide_reading_frames" value="2"$def_selected{"3 Reverse"}>3 Reverse&nbsp;&nbsp;
		<input type="radio" name="nucleotide_reading_frames" value="3"$def_selected{"Both"}>Both
	</TD>
</TR>

<TR height=25>
	<TD class=title>Mass:&nbsp;&nbsp;</TD>
	<TD class=data>&nbsp;
		<input type="radio" name="use_mono/avg_masses" value="0"$def_selected{"Average"}>Average&nbsp;&nbsp;
		<input type="radio" name="use_mono/avg_masses" value="1"$def_selected{"Monoisotopic"}>Monoisotopic
	</TD>
</TR>

<TR height=25>
	<TD class=title>Peptide Mass:&nbsp;&nbsp;</TD>
	<TD class=data>&nbsp;
		Min&nbsp;<input type="text" name="min_peptide_mass" size="10" maxlength="20" value=$def_min_pep_mass>&nbsp;&nbsp;&nbsp;
		Max&nbsp;<input type="text" name="max_peptide_mass" size="10" maxlength="20" value=$def_max_pep_mass>
	</TD>
</TR>

<TR height=25>
	<TD class=title>Max Internal Cleavage Sites:&nbsp;&nbsp;</TD>
	<TD class=data>&nbsp;
		<span class="dropbox"><select name="max_num_internal_cleavage_sites">
		<option value="0"$def_selected{"max_internal0"}>0&nbsp;
		<option value="1"$def_selected{"max_internal1"}>1&nbsp;
		<option value="2"$def_selected{"max_internal2"}>2&nbsp;
		<option value="3"$def_selected{"max_internal3"}>3&nbsp;
		<option value="4"$def_selected{"max_internal4"}>4&nbsp;
		<option value="5"$def_selected{"max_internal5"}>5&nbsp;
		</select></span>
	</TD>
</TR>

<TR height=25>
	<TD class=title>Max Diff AA\'s per Mod:&nbsp;&nbsp;</TD>
	<TD class=data>&nbsp;
		<input type="text" name="max_num_diff_aa_per_mod" size="2" maxlength="2" value=$def_max_diff_aa>
	</TD>
</TR>

<tr height=25>
	<td class=title>Auto-Distribute:&nbsp;&nbsp;</td>
	<td class=data>&nbsp;<input type=checkbox name="auto_distribute" $auto_distribute>
	</td>
</tr>

</TABLE>
</TABLE>
EOF
	return $table;
}



sub createDatabaseEnzymeTable {
	my $table = <<EOF;

<table cellspacing=0 cellpadding=0 border=0>
<tr>
	<td colspan=2>
	<table cellspacing=0 cellpadding=0 bgcolor="#e8e8fa" height=20 width=100%><tr>
		<td width=20><img src="${webimagedir}/ul-corner.gif" width=10 height=20></td>
		<td width=100% class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;Database & Enzyme</td>
		<td width=20><img src="${webimagedir}/ur-corner.gif" width=10 height=20></td>
	</tr></table>
	</td>
</tr>

<tr><td colspan=2>
	<table cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
	<tr><td class=title style="font-size:2">&nbsp;</td><td class=data style="font-size:2">&nbsp;</td></tr>

	<TR height=25>
	<TD class=title width=119 NOWRAP>Database:&nbsp;&nbsp;</TD>
	<TD class=data>&nbsp;
		<span class="dropbox"><SELECT NAME="Database" onChange="generateindexname()">
	
EOF

	foreach $database (@ordered_db_names) {
		$table .= "<OPTION VALUE=\"$database\"";
		$table .= " selected" if ($database eq $def_database);
		$table .= ">$database\n";
	}

	$table .= <<EOF;
		</SELECT></span>&nbsp;&nbsp;
	</TD>
</TR>

<TR height=25>
	<TD class=title NOWRAP>Database Type:&nbsp;&nbsp;</TD>
	<TD class=data NOWRAP>
		<INPUT TYPE=radio NAME="protein_or_nucleotide_dbase" VALUE="2"$def_selected{"Auto"}>Auto 
		&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE=radio NAME="protein_or_nucleotide_dbase" VALUE="0"$def_selected{"Protein"}>Protein 
		&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE=radio NAME="protein_or_nucleotide_dbase" VALUE="1"$def_selected{"Nucleotide"}>Nucleotide<BR>
	</TD>
</TR>


<TD class=title NOWRAP>Enzyme:&nbsp;&nbsp;</TD>
     <TD class=data NOWRAP>&nbsp;&nbsp;<span class="dropbox"><select name="Enzyme">
<OPTION $enz_sel{"0"} VALUE=0>None
EOF

	foreach $num (1..$#enz_name)
	{
		$name = $enz_name[$num];
		$name =~ s/_/ /g;
		$selected = ($name eq $def_enzyme) ? " selected" : "";
		$table .= "<OPTION VALUE=$num$selected>$name\n";
	}

	$table .= <<EOF;
</select></span>
	</TD>
	</TR>
	</TABLE>
</TABLE>
EOF

return $table;
}



####################################### Start Javascript ##############################################

# Functions involved with the additional popup boxes
# Adapted from sequest_launcher.pl
sub load_java_popups {
	$unique_window_name = "$$\_$^T";
	
	print <<EOF;
<script language="Javascript">
<!--
var addmass;
var enzymes;
var advanced;
var defaults = new Array();
var enz_defaults = new Array();

// experience shows, optimal pop-up window heights are different in IE than in Netscape, thus:
var am_height = (navigator.appName == "Microsoft Internet Explorer") ? 540 : 590;
var ez_height = (navigator.appName == "Microsoft Internet Explorer") ? 600 : 650;
var adv_height = (navigator.appName == "Microsoft Internet Explorer") ? 370 : 400;


// retrieve form values from hidden values in main window
// and display in pop-up window
function getValues(popup)
{
    window.status = "Retrieving values, please wait...";

    for (i = 0; i < popup.document.forms[0].elements.length; i++)
    {
		if (popup.document.forms[0].elements[i]) {
			elt = popup.document.forms[0].elements[i];
			if (document.forms[0][elt.name]) {
				if (elt.type == "checkbox" || elt.type == "radio") {
					// Always define the actual checkboxes in the pop-up as value="1", put the real value in
					// the hidden form element on the main page
					// For radio buttons, check all pop-up radios against the one hidden form element to see if
					// it matches, if so, check the current one
					elt.checked = (document.forms[0][elt.name].value == elt.value);
				} else {
					elt.value = document.forms[0][elt.name].value;
				}
			}
		}
    }

    window.status = "Done";
}


// opposite of getValues(): save values from form elements in a pop-up window
// as values of hidden elements in main window, and update enzyme dropbox
function saveValues(popup)
{
	window.status = "Saving values, please wait...";

	for (i = 0; i < popup.document.forms[0].elements.length; i++)
	{
		elt = popup.document.forms[0].elements[i];
		if (document.forms[0][elt.name]) {
			if (elt.type == "checkbox") {
				document.forms[0][elt.name].value = (elt.checked) ? elt.value : 0;
			} else if (elt.type == "radio") {
				// only overwrite the hidden form element on the main page on checked, else it is overwritten
				// whenever the last radio option is not selected
				if (elt.checked) {
					document.forms[0][elt.name].value = elt.value;
				}
			} else {
				document.forms[0][elt.name].value = elt.value;
			}
		}

		// update Enzyme list in dropbox on main form if necessary
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

	window.status = "Done";
}


// create pop-up window for editing add-mass parameters
function addmass_open()
{
	if (addmass && !addmass.closed)
		addmass.focus();
	else
	{
		addmass = open("","addmass_$unique_window_name","width=240,height=" + am_height + ",resizable,screenX=20,screenY=20,left=20,top=20");
		addmass.document.open();
		addmass.document.writeln('<HTML>');
		addmass.document.writeln('<!-- this is the code for the add-mass pop-up window -->');
		addmass.document.writeln('');
		addmass.document.writeln('<HEAD><TITLE>Add Masses</TITLE>$stylesheet_javascript</HEAD>');
		addmass.document.writeln('');
		addmass.document.writeln('<BODY BGCOLOR=#FFFFFF>');
		addmass.document.writeln('<CENTER>');
		addmass.document.writeln('');
		addmass.document.writeln('<H4>Add Masses</H4>');
		addmass.document.writeln('');
		addmass.document.writeln('<FORM>');
		addmass.document.writeln('');

		addmass.document.writeln('<tt>C-terminus:</tt> <INPUT NAME="add_Cterm" MAXLENGTH=7 SIZE=7><BR>');
		addmass.document.writeln('<tt>N-terminus:</tt> <INPUT NAME="add_Nterm" MAXLENGTH=7 SIZE=7><P>');

		var ABC = "GASPVTCLIXNOBDQKZEMHFRYW";

		addmass.document.writeln('<TABLE WIDTH=200><TR><TD>');
		addmass.document.writeln('<TABLE WIDTH=100>');
		for (i = 0; i < 12; i++)
		{
			var A = ABC.charAt(i);
			addmass.document.writeln('<TR>');
			addmass.document.writeln('	<TD ALIGN=right><tt>' + A + ':</tt></TD>');
			addmass.document.writeln('	<TD><INPUT NAME="add_' + A + '" MAXLENGTH=7 SIZE=7"></TD>');
			addmass.document.writeln('</TR>');
		}
		addmass.document.writeln('</TABLE>');
		addmass.document.writeln('</TD><TD>');
		addmass.document.writeln('<TABLE WIDTH=100>');
		for (i = 12; i < 24; i++)
		{
			var A = ABC.charAt(i);
			addmass.document.writeln('<TR>');
			addmass.document.writeln('	<TD ALIGN=right><tt>' + A + ':</tt></TD>');
			addmass.document.writeln('	<TD><INPUT NAME="add_' + A + '" MAXLENGTH=7 SIZE=7></TD>');
			addmass.document.writeln('</TR>');

		}
		addmass.document.writeln('</TABLE>');
		addmass.document.writeln('</TD></TR></TABLE>');

		addmass.document.writeln('<br>');
		addmass.document.writeln('<INPUT TYPE=button class="button" NAME="saveAddmass" VALUE="Save" onClick="opener.saveValues(self); self.close()"> ');
		addmass.document.writeln('<INPUT TYPE=button class="button" NAME="cancelAddmass" VALUE="Cancel" onClick="self.close()">');

		addmass.document.writeln('</FORM>');

		addmass.document.writeln('</CENTER>');
		addmass.document.writeln('</BODY>');
		addmass.document.writeln('</HTML>');

		getValues(addmass);

		addmass.document.close();
	}
}


// create pop-up window for editing enzyme-info parameters
function enzymes_open()
{
	if (enzymes && !enzymes.closed)
		enzymes.focus();
	else
	{
		enzymes = open("","enzymes_$unique_window_name","width=520,height=" + ez_height + ",resizable,screenX=220,screenY=30,left=220,top=30");
		enzymes.document.open();
		enzymes.document.writeln('<HTML>');
		enzymes.document.writeln('<!-- this is the code for the enzyme-info pop-up window -->');
		enzymes.document.writeln('');
		enzymes.document.writeln('<HEAD><TITLE>Enzyme Information</TITLE>$stylesheet_javascript</HEAD>');
		enzymes.document.writeln('');
		enzymes.document.writeln('<BODY BGCOLOR=#FFFFFF>');
		enzymes.document.writeln('<CENTER>');
		enzymes.document.writeln('');
		enzymes.document.writeln('<H4>Enzyme Information</H4>');
		enzymes.document.writeln('');
		enzymes.document.writeln('<FORM>');
		enzymes.document.writeln('');
		enzymes.document.writeln('<TABLE>');
		enzymes.document.writeln('<TR><TH></TH><TH ALIGN=left>Name</TH><TH>Offset</TH><TH ALIGN=left>Sites</TH><TH>No-sites</TH></TR>');
		enzymes.document.writeln('<TR>');
		enzymes.document.writeln('	<TH ALIGN=right>0.</TH>');
		enzymes.document.writeln('	<TD>No Enzyme</TD>');
		enzymes.document.writeln('	<TD ALIGN=center>0</TD>');
		enzymes.document.writeln('	<TD>-</TD>');
		enzymes.document.writeln('	<TD ALIGN=center>-</TD>');
		enzymes.document.writeln('</TR>');
		for (i = 1; i < document.forms[0].Enzyme.options.length; i++)
		{
			enzymes.document.writeln('<TR>');
			enzymes.document.writeln('	<TH ALIGN=right>' + i + '.</TH>');
			enzymes.document.writeln('	<TD><INPUT NAME="enz_name' + i + '"></TD>');
			enzymes.document.writeln('	<TD ALIGN=center><INPUT NAME="enz_offset' + i + '" SIZE=1 MAXLENGTH=1></TD>');
			enzymes.document.writeln('	<TD><INPUT NAME="enz_sites' + i + '"></TD>');
			enzymes.document.writeln('	<TD ALIGN=center><INPUT NAME="enz_no_sites' + i + '" SIZE=1 MAXLENGTH=1></TD>');
			enzymes.document.writeln('</TR>');
		}
		enzymes.document.writeln('</TABLE>');
		enzymes.document.writeln('<br>');
		enzymes.document.writeln('<INPUT TYPE=button class="button" NAME="saveEnzymes" VALUE="Save" onClick="opener.saveValues(self); self.close()"> ');
		enzymes.document.writeln('<INPUT TYPE=button class="button" NAME="cancelEnzymes" VALUE="Cancel" onClick="self.close()">');
		enzymes.document.writeln('');
		enzymes.document.writeln('</FORM>');
		enzymes.document.writeln('');
		enzymes.document.writeln('</CENTER>');
		enzymes.document.writeln('</BODY>');
		enzymes.document.writeln('</HTML>');

		getValues(enzymes);

		enzymes.document.close();
		
	}
}


function advanced_open() {
	if (advanced && !advanced.closed) {
		advanced.focus();
	} else {
		advanced = open("","advanced_$unique_window_name","width=520,height=" + adv_height + ",resizable,screenX=440,screenY=40,left=440,top=40");
		advanced.document.open();
		advanced.document.writeln('<HTML>');
		advanced.document.writeln('<!-- this is the code for the advanced settings pop-up window -->');
		advanced.document.writeln('');
		advanced.document.writeln('<HEAD><TITLE>Advanced Settings</TITLE>$stylesheet_javascript</HEAD>');
		advanced.document.writeln('');
		advanced.document.writeln('<BODY BGCOLOR=#FFFFFF>');
		advanced.document.writeln('<CENTER>');
		advanced.document.writeln('');
		advanced.document.writeln('<H4>Advanced Settings</H4>');
		advanced.document.writeln('');
		advanced.document.writeln('<FORM>');
		advanced.document.writeln('');
		advanced.document.writeln('<TABLE>');
		advanced.document.writeln('<TR><TD align="right"><span class="smallheading">Index Output Directory:</span>');
		advanced.document.writeln('<TD><input type="text" name="out_dir" size="30" maxlength="1023"></TR>');
		advanced.document.writeln('');
		advanced.document.writeln('<TR><TD align="right"><span class="smallheading">Temp Directory:</span>');
		advanced.document.writeln('<TD><input type="text" name="temp_dir" size="30" maxlength="1023"></TR>');
		advanced.document.writeln('');
		advanced.document.writeln('<TR><TD align="right"><span class="smallheading">Minimum Peptide Size:</span>');
		advanced.document.writeln('<TD><input type="text" name="min_peptide_size" size="4" maxlength="4"></TR>');
		advanced.document.writeln('');
		advanced.document.writeln('<TR><TD align="right"><span class="smallheading">Maximum Peptide Size:</span>');
		advanced.document.writeln('<TD><input type="text" name="max_peptide_size" size="4" maxlength="4"></TR>');
		advanced.document.writeln('');
		advanced.document.writeln('<TR><TD align="right"><span class="smallheading">Unique Sequence Sort:</span>');
		advanced.document.writeln('<TD><input type="checkbox" name="unique_seq_sort" value="1"></TR>');
EOF


	print <<EOF;
		advanced.document.writeln('<TR><TD align="right"><span class="smallheading">Diskspace Override:</span>');
		advanced.document.writeln('<TD><input type="checkbox" name="diskspace_override" value="1"></TR>');

		advanced.document.writeln('</TABLE>');
		advanced.document.writeln('');

		advanced.document.writeln('<br>');
		advanced.document.writeln('<INPUT TYPE=button class="button" NAME="saveAdvanced" VALUE="Save" onClick="opener.saveValues(self); self.close()"> ');
		advanced.document.writeln('<INPUT TYPE=button class="button" NAME="cancelAdvanced" VALUE="Cancel" onClick="self.close()">');

		advanced.document.writeln('');
		advanced.document.writeln('</FORM>');
		advanced.document.writeln('');
		advanced.document.writeln('</CENTER>');
		advanced.document.writeln('</BODY>');
		advanced.document.writeln('</HTML>');

		getValues(advanced);

		advanced.document.close();

	}
}


// close all pop-up windows
function closeAll_popups()
{
	if (addmass)
		if (!addmass.closed)
			addmass.close();
	if (enzymes)
		if (!enzymes.closed)
			enzymes.close();
	if (advanced)
		if (!advanced.closed)
			advanced.close();
}

onunload = closeAll_popups;
//-->
</script>
EOF
}

# Causes an autoupdate of the indexed db box
# This code adapted from seqindex.pl
sub load_java_dbnames {
	print <<EOF;
<script language = "Javascript">
<!--
function isvaliddatabase(database_name)
{
	return(database_name.match(/.fasta\$/i));
}

function generateindexname()
{
	var database_name = document.forms[0].Database.options[document.forms[0].Database.selectedIndex].value;

	if (isvaliddatabase(database_name)) {
		document.forms[0].indexed_db.value = database_name + ".hdr";
	} else {
		document.forms[0].indexed_db.value = "Not a .fasta database";
	}
}

// Continues a previous run for the currently selected database
function continuePrev()
{
	var selected = document.forms[0].Database.options.selectedIndex;
	var curr_dbase = document.forms[0].Database.options[selected].value;
	var paramsfile = escape("C:/Sequest/" + curr_dbase + "/sequest.params");
	var gotoURL = "$webcgi/$ourshortname";

	location.href=gotoURL;
}


onload = generateindexname;

//-->
</script>
EOF
}

####################################### End Javascript #################################################


# return 1 if the database is a nucleotide database, 0 otherwise
#
# Check if the database is more than 80% ACTG over the first 500 lines.  If so, we will assume it is nucleotide.
# Otherwise, assume it is protein.
#
# Adapted from sequest_launcher.pl
sub get_dbtype {
	my ($db) = $_[0];

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


#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
# If second argument is specified and non-null/non-zero, the standard header is printed as well.
sub error {
	if ($_[1]) {
		&MS_pages_header("MakeDB4","#8800FF");
		print "<hr><p>\n";
	}
	print "<h3>Error:</h3>\n";
	print "<div>$_[0]</div>\n";
	print "</body></html>";
	exit 1;
}
