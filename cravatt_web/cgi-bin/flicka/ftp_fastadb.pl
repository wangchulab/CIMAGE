#!/usr/local/bin/perl

# ============================================================
# Project       : FTP_DB
# Description   : database download
# Includes      : seqcomm_include_remote.pl (on remote server)
# Requires      : ----
# Authors       : Piotr Dollar, C. M. Wendl, P. Djeu, W. Lane
# Date Created  : 03/99
# Version       : v3.1a
# Copyright     : (C)1999 Harvard University
# Comments      : 
# ============================================================


{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1!;
	unshift (@INC, "$path/etc", "$path/seqcomm", "$path/seqcomm/remote");
	require "microchem_include.pl";
}

$old_incdir = $incdir;						# save this for future substitutions

if ($multiple_sequest_hosts) {
	require "seqcomm_include.pl";

	if ($ENV{'COMPUTERNAME'} ne "$webserver") {
		require "seqcomm_include_remote.pl";	# If on a remote host
	} else {
		require "seqcomm_var_$webserver.pl";
	}
} else {
	# Local webserver run not tested, but the majority of the script probably would work, just need to define
	# the variables found in seqcomm_var_$Machine.
	# Error for now.
	print ("Error: AutoDownload Script requires multiple Sequest hosts, exiting.");
	exit;
}

# Include this file after we determine if we are running remotely or locally, so that the variable $incdir (used in $fastaidx_lib)
# is set correctly based on either the local or remote var file
require $fastaidx_lib;

use File::Copy;


## The estimated unzipped db size multipliers.  In order to estimate the size of an unzipped db before we unzip it,
## the constant defined in this hash for a given database is multiplied onto the zip file size.  This product is
## used to guess if there is enough disk space for an unzip.  Since different databases have different compression
## ratios, unique multipliers need to be determined for each db.  Define these unique multipliers here, keeping in
## mind that they should slightly overestimate the unzipped size.
%zip_multiplier = (
	"nr"		=>	"2.2",
	"est"		=>	"3.7",
	"mito_aa"	=>	"2.3"
);


# this script downloads a FASTA database from NCBI, unzips it to all our Sequest servers, indexes it, and a few other things
# In almost all cases when the script should exit, be sure to use "goto EXIT;" so that the file lock is removed
#
# this code is called by db_autodownload.pl when run manually and by seqcomm_q.pl automatically when the db should be downloaded
# as per the seqcomm q params
# the code resides on the webserver, but it's intended to be run from a remote server, i.e. $DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER
# it can be run on ANY remote SeqComm server without code changes, probided that the Machine defines the necessary SeqComm
# machine specific local paths
#
# The code has two distinct phases:
# (1) A Processing phase, where all work is done in the scratch directory on the default download server.  This phase
# includes the ftp'ing of the zip file, the unzip, and the creation of one copy of each of the different
# indices, all within the the scratch directory.
# (2) A Distribution phase, where all work of the indices created in the processing phase are distributed to
# the machines that need them.  Note that since all indices prior to this point were kept in the
# scratch directory, it may be necessary to distribute to this machine's (default download server's)
# regular db directory as well.
#
# These changes were made so that the new downloaded database and its indices are assured to be correct
# and consistent before distributing.
#
#
# NOTE on the command line arguments:
# The four Processing routines are executed based on the presence of flags on the command line that is passed in.
# For instance, the Download Process is triggered by the precence of the since -d flag on the command line.
# Here's a table of the flags and the processes they relate to:
#
# -d		Download
# -z		Unzip
# -p		Protein Prospector
# -i		FastaIdx
# -m		MakeDB4
#
# The Distribution flag -u can appear multiple time and has the following format:
# -u[MachineName]__[0|1]__[0|1]__[0|1]
#                   (a)    (b)    (c)
#
# The MachineName is the target machine.  If (a) is 1, the regular .fasta database will be distributed to MachineName.
# If (b) is 1, the turbo index (from MakeDB4) will be distributed.  If (c) is 1, the .flatidx (from FastaIdx) will
# be distributed.  A value of 0 for (a)-(c) means "do not distribute that particular file or set of files".
#
# Note that the order of the -u flags as they appear in the command line is very important because ftp_fastadb.pl
# will process these in the order it sees them
# -- P.Djeu 8-13-01


##################################################################################################
# variable definitions
##################################################################################################

########################################
# constants for remote servers and paths
# --------------------------------------
# @notify (from site-wide include files) - servers that need to be notified when process is complete
#
# The remote machines are defined in the -u command line argument(s) that are passed in.
#
# The remote paths (for just the machine running this script) are defined in the SeqComm
# Machine specific include file, so check there if you're curious.  The remaining remote
# paths are specified by network directory share names, which are standardized.


########################################
# local variable definitions
# --------------------------
# set the path to FTP and GZip executables

$FTP_EXE="c:/progra~1/Ws_ftp32/WS_FTP95.exe";
$GZIP_EXE="c:\\progra~1\\gnuzip\\bin\\gzip";

# be careful when setting database name: omit the .Z suffix
# also note that if db name has a "." in it, such as month.aa.Z that
# gzip will not accept it. gzip will accept dos 8.3 format though
$DB=$ARGV[$#ARGV];
$DB =~ s/\.Z$//i;		# Strip off the unneeded extension
$DB =~ s/\.fasta$//i;	# Strip off the unneeded extension

##################################################################################################
# end of variable definitions
##################################################################################################


if (!(defined $DB)) {
	print ("Error: No database specified, exiting on " . localtime() . "\n");
	exit;
}


# create a file $mystamp and flock it so that processes on other servers will know we're running
$mystamp = "\\\\$webserver/database/.ftp_fastadb_running";
open(MYSTAMP, ">$mystamp");
unless (flock MYSTAMP, ($LOCK_EX | $LOCK_NB)) {
	# File locked by ftp_fastadb.pl, which means it is running
	foreach $recipient (@notify) {
		system("net send $recipient \"ERROR: Autodownload is already running.  Please wait until it completes before initiating another session.\"");
	}
	# BREAK IF LOCK CANNOT BE ACQUIRED
	exit;
}

$Machine = $ENV{"COMPUTERNAME"};	# The host running this script

# initialize log after we have the exclusive lock or else pre-existing log file will be overwritten
&create_logfile;
$results = "$DB.fasta -- ";		# Log of results that eventually appears in the NT net send pop-up

if ($DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER ne $Machine) {
	&write_logfile_ftp("\nWarning: The current machine $Machine, is not the default MakeDB machine $DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER; attempting to run Autodownload anyways at " . localtime() . "\n\n");
}

#######################################
# Interpret command line arguments
# See the comments in the header of this file for a description of each of the args
$skip_download = 1;
$skip_unzip = 1;
$skip_prospector = 1;
$skip_fastaidx = 1;
$skip_makedb = 1;
@distribution = ();		# A task queue for the Distribution phase, first in, first out

# This script will execute the -u params in the order in which it sees them
foreach (@ARGV) {
	if (($c,$more) = m/^-(.)(.*)/) {
		if ($c eq "d") {
			$skip_download = 0;
		} elsif ($c eq "z") {
			$skip_unzip = 0;
		} elsif ($c eq "p") {
			$skip_prospector = 0;
		} elsif ($c eq "i") {
			$skip_fastaidx = 0;
		} elsif ($c eq "m") {
			$skip_makedb = 0;
		} elsif ($c eq "u") {
			push (@distribution, $more);
		} else {
			# Just give a warning
			&write_logfile_ftp("\nWarning: unrecognized flag -$c$more\n\n");
		}
	}
}

#######################################
# INITIALIZATION
$error = 0;							# A var for catching return values of functions
$errors = 0;						# A more long term flag, once a $error is caught, set this to 1
$prospector_error = 0;				# A flag for any prospector error in particular
$fastaidx_error = 0;				# A flag for any fastaidx error in particular
$makedb_error = 0;					# A flag for any makedb error in particular
$cp_errors = 0;						# A flag for file copy errors

if (($scratch_dbdir eq "") or (!(defined $scratch_dbdir))) {
	&write_logfile_ftp("\nError: No database processing directory specified, exiting on " . localtime() . "\n\n");
	$results .= "FAILED to find database Processing dir (unspecified?)  --  ";
	$errors = 1;
	# BREAK IF UNZIP NOT POSSIBLE
	goto EXIT;
}

chdir "$scratch_dbdir" or &write_logfile_ftp("\nCould not find the local database directory $scratch_dbdir on $Machine at " . localtime() . "\n\n");

&write_logfile_ftp("\nBEGINNING THE PROCESSING PHASE:\n");

########################################
# DOWNLOAD
unless ($skip_download) {
	$error = &ftp_download;
	if ($error) {
		$results .= "Download FAILED  --  ";
		$errors = 1;
	} else {
		$results .= "Download SUCCESSFUL  --  ";
	}
}


################################################################################################
# UNZIP
# Unzip to the default download server so that it can do all of the processing in its
# temporary storage directory.  If download procedure is not specified, this should still
# be fine because the old zip file will be used to recreate the old database.
#
# The reason why this is not part of download is because the zip file provides a base for all later
# actions.  All of the indices are made from the contents of this zip file and even get its modification
# date.  If the user skips download, the unzipping will be the first thing that happens so that
# we are guaranteed to have a fasta to work with.
unless ($skip_unzip) {
	if (!(-e "$DB.Z")) {
		&write_logfile_ftp("\nError: no zip file on $Machine at " . localtime() . ", aborting\n\n");
		$results .= "ABORTING; zip file could not be found  --  ";
		$errors = 1;
		# BREAK IF UNZIP NOT POSSIBLE
		goto EXIT;
	}

	$error = &unzip_file_to_machine;
	if ($error) {
		&write_logfile_ftp("\nCould not unzip to $Machine on " . localtime() . ", aborting\n\n");
		$results .= "Unzip FAILED  --  ";
		$results .= "ABORTING due to critical unzip failure  --  ";
		$errors = 1;
		# BREAK IF UNZIP UNSUCCESSFUL
		goto EXIT;
	} else {
		$results .= "Unzip SUCCESSFUL  --  ";
	}
}


# Set all products of the script from this point onwards to have the same access and modification times
# as the original fasta.  If this file does not exist, we can't continue any processing, so exit.
# This may be a problem if someone wants to use this script just as a copy routine for indices, but we
# have other programs to do that.
if (-e "$DB.fasta") {
	(undef,undef,undef,undef,undef,undef,undef,undef,$atime,$mtime,undef,undef,undef) = stat "$DB.fasta";
} else {
	&write_logfile_ftp("\nError: no unzipped fasta file on $Machine at " . localtime() . ", aborting\n\n");
	$results .= "ABORTING; unzipped fasta file could not be found  --  ";
	$errors = 1;
	# BREAK IF UNZIP NOT POSSIBLE
	goto EXIT;
}



########################################
# FASTAIDX
unless ($skip_fastaidx) {
	$error = &ftp_fastaidx;
	if ($error) {
		$results .= "FastaIdx FAILED  --  ";
		$errors = 1;
		$fastaidx_error = 1;
	} else {
		$results .= "FastaIdx SUCCESSFUL  --  ";
	}
}


########################################
# MAKEDB4
unless ($skip_makedb) {
	$error = &ftp_makedb;
	if ($error) {
		$errors = 1;
		$makedb_error = 1;
		$results .= "MakeDB4 FAILED  --  ";
		# sub ftp_makedb() changes the directory, in case of an error, try to change the directory back to the original one and continue
		chdir "$scratch_dbdir" or &write_logfile_ftp("\nCould not find the local database directory $scratch_dbdir on $Machine at " . localtime() . "\n\n");
	} else {
		$results .= "MakeDB4 SUCCESSFUL  --  ";
	}
}


################################################################################################
# ERROR CHECK
# If any of the critical processes above fail, then just exit with an informative error message.
# This is to avoid propagating an inconsistent set of dbases, indexed dbases, and fastaidx's.
# If a process above is not run, then there will naturally be no error, and an inconsistent
# state may be spread (skip MakeDB, but copy the (pre-)existing index to all hosts, for example).
# But the user was already warned about this on the web-page, so just let them do exactly what
# they request.
#if ($prospector_error || $fastaidx_error || $makedb_error) {
if ($fastaidx_error || $makedb_error) {		# For now, don't worry about Prospector failure because it is not relevant to distribution
	&write_logfile_ftp("\nABORTING Distribution due to Processing error(s) on " . localtime() . "\n\n");
	$results .= "ABORTING Distribution due to Processing error(s)  --  ";
	$errors = 1;
	# BREAK IF DISTRIBUTION WILL LEAD TO A CORRUPT STATE
	goto EXIT;
}

################################################################################################
# DISTRIBUTION
# Second phase of the download script, copy the resulting files to specific machines.
# The order of events is determined by the order in which  flags were specified on
# the control line.  Which files to transfer to which machine are determined by the command
# line flag and its paramaeter.  For instance, . . . -r$Machine1 -t$Machine2 . . . 
# will distribute a copy of the regular fasta to $Machine1 and a copy of the turbo index
# to $Machine2.
#
# The one exception to the above rules is that if any remote server is to be given a copy of
# the turbo index, then a copy of the .hdr is copied to the web once, so that the index is accessible
# in Sequest runs via the dropbox.

&write_logfile_ftp("\n\nBEGINNING THE DISTRIBUTION PHASE:\n");

$copied_hdr_to_web = 0;

foreach (@distribution) {
	my ($dist_fasta, $dist_turbo, $dist_fastaidx);
	($remserver, $dist_fasta, $dist_turbo, $dist_fastaidx) = m/^(.+)__(\d)__(\d)__(\d)$/;

	&write_logfile_ftp("\n*** $remserver ***\n");

	($dest_dir = "\\\\$remserver\\Database") =~ s/\//\\/g;	# Make the dir name DOS compatible since we will be using the 'dir' command for disk space

	# ascertain disk space available
	# Algorithm:
	# (1) First check if there is enough free space, if so begin copy
	# (2) If there is not enough free space for all of the files, then check if there is enough room if we were to delete
	# all of the existing, to-be-overwritten files.  This does not mean that all of them will be deleted, the greedy solution
	# of backing up as much as possible will be found when the copy_check_size routines are called sequesntially later
	# (3) If there is still not enough room, move on to the next machine
	$_ = `dir $dest_dir`;
	($bytes_free) = /([\d,]+) bytes free/;
	$bytes_free =~ s/,//g;
	$bytes_free = 0 if ($bytes_free eq "");

	# Step (1)
	$bytes_needed = 0;
	$bytes_delete = 0;
	if ($dist_fasta) {
		$bytes_needed += &dos_file_size("$scratch_dbdir/$DB.fasta");
		$bytes_delete += &dos_file_size("\\\\$remserver/Database/$DB.fasta");
	}
	if ($dist_turbo) {
		$bytes_needed += &dos_file_size("$scratch_dbdir/$DB.fasta.hdr");
		$bytes_needed += &dos_file_size("$scratch_dbdir/$DB.fasta.dgt");
		$bytes_needed += &dos_file_size("$scratch_dbdir/$DB.fasta.idx");
		$bytes_delete += &dos_file_size("\\\\$remserver/Database/$DB.fasta.hdr");
		$bytes_delete += &dos_file_size("\\\\$remserver/Database/$DB.fasta.dgt");
		$bytes_delete += &dos_file_size("\\\\$remserver/Database/$DB.fasta.idx");
	}
	if ($dist_fastaidx) {
		$bytes_needed += &dos_file_size("$scratch_dbdir/$DB.flatidx");
		$bytes_delete += &dos_file_size("\\\\$remserver/Database/$DB.flatidx");
	}
	
	# Move on to Step (2)
	if ($bytes_needed > $bytes_free) {
		if ($bytes_needed > ($bytes_free + $bytes_delete)) {
			# Step (3)
			$results .= "$remserver Distribution FAILED --  ";
			$errors = 1;
			&write_logfile_ftp("$bytes_needed bytes needed, $bytes_free bytes free, $bytes_delete bytes in deleteable files\n");
			&write_logfile_ftp("Error: not enough space on $remserver\n");
			next;
		}
	}

	&write_logfile_ftp("$bytes_needed bytes needed, $bytes_free bytes free, $bytes_delete bytes in deleteable files\n");

	# Begin the actual distribution
	#
	# If a copy fails, make a note of it, but just keep going.  By this point, it is probably a network
	# failure and there is nothing we can do about it.
	$temp_errors = $cp_errors;

	if ($dist_fasta) {
		# Distribute the regular index
		$cp_errors += copy_check_size("$scratch_dbdir/$DB.fasta", "\\\\$remserver/Database/$DB.fasta");
	}
	if ($dist_turbo) {
		# Distribute turbo index
		$cp_errors += copy_check_size("$scratch_dbdir/$DB.fasta.hdr", "\\\\$remserver/Database/$DB.fasta.hdr");
		$cp_errors += copy_check_size("$scratch_dbdir/$DB.fasta.dgt", "\\\\$remserver/Database/$DB.fasta.dgt");
		$cp_errors += copy_check_size("$scratch_dbdir/$DB.fasta.idx", "\\\\$remserver/Database/$DB.fasta.idx");

		# Add .hdr file to webserver if it does not exist so that it is accessible for sequest runs
		if (!$copied_hdr_to_web) {
			$cp_errors = copy_check_size("$scratch_dbdir/$DB.fasta.hdr", "\\\\$webserver/Database/$DB.fasta.hdr");
			# Even if copy fails, don't try it again because the destination is the same
			$copied_hdr_to_web = 1;
		}
	}
	if ($dist_fastaidx) {
		# Distribute the flatidx from FastaIdx
		$cp_errors += copy_check_size("$scratch_dbdir/$DB.flatidx", "\\\\$remserver/Database/$DB.flatidx");
	}
	# Skip unknown flags

	if ($temp_errors == $cp_errors) {
		$results .= "$remserver Distribution SUCCESSFUL --  ";
	} else {
		$results .= "$remserver Distribution FAILED --  ";
	}
}

if ($cp_errors > 0) {
	$errors = 1;
	$results .= "Distribution Errors: $cp_errors File(s)  --  ";
}


EXIT:
# writes logline
$end_result = ($errors) ? ("\nUpdate of $DB.fasta encountered PROBLEMS; exiting on " . localtime() . "\n\n") : ("\nUpdate of $DB.fasta *** SUCCESSFUL ***  completed on " . localtime() . "\n\n");

&write_logfile_ftp($end_result);

# delete the temporary locked file
flock MYSTAMP, $LOCK_UN;
close MYSTAMP;
unlink "$mystamp";


# notify all relevant people of the result
$message = "$results  ----  $end_result";

foreach $recipient (@notify) {
	system("net send $recipient \"$message\"");
}

exit;


############### END OF MAIN PROGRAM ###################

############### Begin Helper Functions ################
# Create new log if old does not exist, appending to old if old log exists
sub create_logfile {
	$header = "\n-------------------------------------- \n";
	$header = $header . "ftp_fastadb.pl is being run on $ENV{'COMPUTERNAME'} at " . localtime() . "\n";

	print "$header";

	# Log is kept on webserver for easy access from a web-page
	$file = "\\\\$webserver/database/$DB.download.log";

	open (LOGFILE, ">>$file");
	print LOGFILE $header;
	close LOGFILE;
}


# Appends information onto LOGFILE
sub write_logfile_ftp {

	$line = $_[0];

	print $line;

	# Log is kept on webserver for easy access from a web-page
	$file = "\\\\$webserver/database/$DB.download.log";

	open (LOGFILE, ">>$file");
	print LOGFILE $line;
	close LOGFILE;

	# A bit of a hack, return 1 here so statements like "write_logfile_ftp($mesg) && return 1"
	# are guaranteed to fully execute, rather than get truncated by short-circuit evaluation -- P.Djeu, 7-16-01
	return 1;
}


# return 1 if the database is a nucleotide database, 0 if the database is a protein datbase, and -1 on error
#
# If the database is more than 80% ACTG over the first 500 lines;
# we will assume it is nucleotide. Otherwise, assume it is
# protein.

sub get_dbtype {
  my ($db) = $_[0];
  my ($line, $numchars, $numnucs, $numlines);

  open (DB, "$db") or (&write_logfile_ftp("Could not open database $db for auto-detecting database type.") && return -1);
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


# Uses FILE:COPY, and checks to make sure that the destination file is as large as the source file.
# Also, checks for diskspace.  If the dest file already exists and there is enough room for the new
# dest file, the old one is packed up with the suffix .previous appended to it.  If disk space is
# low, the old dest file is deleted if that frees up enough room.  Finally, nothing happens if
# deleting the old file does not provide enough room.
#
# 2 Args: src file, dst file, dst directory name (should be the prefix of dst file)
# Returns 0 on success, 1 on copy error or if the destination size does not match up
#
sub copy_check_size {
	my ($src_file, $dest_file, $sizeof_src, $sizeof_dest);
	$src_file = $_[0];
	$dest_file = $_[1];
	if (!(-e $src_file)) {
		&write_logfile_ftp("\nError: copy filed, could not find $src_file on " . localtime() . "\n\n");
		return 1;
	}
	$sizeof_src = &dos_file_size("$src_file");

	# Get everything before the last backslash (or foward slash), which is presumably the directory
	($dest_dir) = ($dest_file =~ m!^(.*)[\\/][^\\/]+$!);
	$dest_dir =~ s/\//\\/g;		# Make the dir name DOS compatible since we will be using the 'dir' command for disk space

	# ascertain disk space available
	$_ = `dir $dest_dir`;
	($bytes_free) = /([\d,]+) bytes free/;
	$bytes_free =~ s/,//g;
	if ($sizeof_src > $bytes_free) {
		# Not enough room, check if the dest file can be erased
		if (-e $dest_file) {
			$sizeof_dest = &dos_file_size("$dest_file");
			if ($sizeof_src < $bytes_free + $sizeof_dest) {
				# Copy should succeed if the destination file is overwritten, so unlink it and fall out to copy()
				&write_logfile_ftp("Deleting $dest_file to make room for copy ($sizeof_src needed, $bytes_free available) on " . localtime() . "\n");
				unlink "$dest_file";
			} else {
				&write_logfile_ftp("\nNot enough disk space in $dest_dir ($sizeof_src needed, $bytes_free available), $src_file NOT copied on " . localtime() . "\n\n");
				return 1;
			}
		} else {
			# No write_logfile
			&write_logfile_ftp("\nNot enough disk space in $dest_dir ($sizeof_src needed, $bytes_free available), $src_file NOT copied on " . localtime() . "\n\n");
			return 1;
		}
	} else {
		# There is enough room to make backups
		if (-e $dest_file) {
			rename("$dest_file", "$dest_file.previous");
		}
	}

	# copy()
	copy("$src_file", "$dest_file");
	if (&dos_file_size("$dest_file") == $sizeof_src) {
		# Touch the file
		utime $atime,$mtime, "$dest_file";
		&write_logfile_ftp("$src_file copy to $dest_file SUCCESS on " . localtime() . "\n");
		return 0;
	} else {
		&write_logfile_ftp("\n$src_file copy to $dest_file FAILED on " . localtime() . "\n\n");
		return 1;
	}
}

############### End Helper Functions ################


############### Begin Primary Functions ################

# This routine encapsulates the entire download (ftp'ing) portion of the autodownload process.
#
# Returns 0 on success, 1 on error
sub ftp_download {
	# Abe--added because the script was not working for mito_aa (NIH calls it mito.aa)
	# replace "_" with "." in database name (for ftping the database; NIH uses ".")
	($DB_NIH = $DB) =~ s/_/\./g;

	# make a direct copy of the db name (for locally saving the database; we use "_")
	$DBname = $DB;

	# MUST REMOVE OLD Z FILE or logfile will lie, saying that the download
	# was succesful regradless of whether it was.
	if (-e "$DBname.Z") {
		# Make a backup of the original zip file in case of problems
		rename "$DBname.Z", "$DBname.Z.previous" or (&write_logfile_ftp("\n$DBname.Z could not be renamed to $DBname.Z.previous on " . localtime() . "\n\n") && return 1);
		&write_logfile_ftp("Successfully copied the old zip file $scratch_dbdir/$DBname.Z to $scratch_dbdir/$DBname.Z.previous on " . localtime() . " \n");
	}

	&write_logfile_ftp("Ftping $DB_NIH.Z to $scratch_dbdir on " . localtime() . " \n");
	# get the compressed db file from ncbi. This requires an ncbi session in ws_ftp95.exe
	# ncbi_db -p is the name of the profile in ws_ftp95
	system ("$FTP_EXE -p ncbi_db -binary -quiet ftp.ncbi.nih.gov:/blast/db/$DB_NIH.Z");

	if ($DBname ne $DB_NIH) {
		rename "$DB_NIH.Z", "$DBname.Z";
	}

	# writes logline
	my $success1;
	$success1 = (-e $DB . ".Z");

	if ($success1) {
		&write_logfile_ftp("$DB.Z was successfully downloaded to $scratch_dbdir on " . localtime() . "\n\n");
	} else {
		&write_logfile_ftp("\nAn ERROR occurred when downloading $DB.Z on ". localtime() . "\n\n");
		$errors = 1;
		# BREAK IF DOWNLOAD UNSUCCESSFUL
		goto EXIT;
	}

	# Success
	return 0;
}


# Unzips the zip file into the scratchwork directory.  This routine is called whenever this script is run because the
# zip file acts as the "starting point" of all of the indexing and distribution that follows.
#
# Returns: 0 on success, 1 on error
sub unzip_file_to_machine {
	my $Machine = $ENV{"COMPUTERNAME"};		# The host running this script

	$zipsize = &dos_file_size("$DB.Z");

	($Mach_DB = "$scratch_dbdir\\$DB") =~ s!/!\\!g;

	# estimate disk space needed, using the hard-coded db-specific multipliers
	$dbsize_estimate = $zipsize * $zip_multiplier{"$DB"};
	&write_logfile_ftp("dbsize_estimate is: $dbsize_estimate\n");

	# ascertain disk space available
	$_ = `dir \\\\$Machine\\Database`;
	($bytes_free) = /([\d,]+) bytes free/;
	$bytes_free =~ s/,//g;
	# delete previous version of database if necessary
	if ($dbsize_estimate > $bytes_free) {
		$size_old_db = &dos_file_size("$Mach_DB.fasta");
		if ($dbsize_estimate > $bytes_free + $size_old_db) {
			&write_logfile_ftp("Insufficient disk space on $Machine (" . $dbsize_estimate . " needed, " . ($bytes_free+$size_old_db) . " available); unzip FAILED on " . localtime() . " \n");
			$errors = 1;
			return 1;
		} else {
			&write_logfile_ftp("Deleting previous version of $Mach_DB.fasta to make disk space (" . $dbsize_estimate . " needed, " . $bytes_free . " available). " . localtime() . " \n");
			unlink "$Mach_DB.fasta";
		}
	}

	&write_logfile_ftp("Unzipping $DB.Z to $Mach_DB.tmp on " . localtime() . " \n");
	# gnuzip our newly ftp'd .Z db to the destination dir
	# if GZIP fails, then it prints an error message and program exits
	system("$GZIP_EXE -dNvac $DB.Z > $Mach_DB.tmp");

	$tmpsize = &dos_file_size("$Mach_DB.tmp");
	&write_logfile_ftp("Unzipped size is: $tmpsize\n");

	if ((-e "$Mach_DB.tmp") && ($tmpsize >= $zipsize)) {

		&write_logfile_ftp("Unzipping to $Machine SUCCESSFUL. " . localtime() . " \n");

		# if necessary, find out whether the database is protein or nucleotide
		if (!defined $prot_or_nuc) {
			$temp_type = &get_dbtype("$Mach_DB.tmp");
			if ($temp_type == -1) {
				&write_logfile_ftp("\nUnzipping to $Machine FAILED because db autodetect failed on " . localtime() . " \n\n");
				$errors = 1;
				return 1;
			}
			$prot_or_nuc = ($temp_type) ? "nuc" : "prot";
		}

		# if it's a protein db, append contaminants_not_in_db.fasta
		if ($prot_or_nuc eq "prot") {
			$dbDirOnWebServer = "\\\\$webserver$webdbdir\\";
			$dbDirOnWebServer =~ s!\/!\\!g; # Switch all forward slashes with backslashes for DOS compatibility.
			
			&write_logfile_ftp("Appending ${dbDirOnWebServer}contaminants_not_in_db.fasta to $Mach_DB.tmp on " . localtime() . " \n");

			# add a new line 
			open (FILE, ">>$Mach_DB.tmp");
			print FILE "\n";
			close FILE; 

			system("type ${dbDirOnWebServer}contaminants_not_in_db.fasta >> $Mach_DB.tmp");
			$tmpsize = &dos_file_size("$Mach_DB.tmp");	# Updating the file size
		}

		&write_logfile_ftp("Renaming $Mach_DB.tmp to $Mach_DB.fasta on " . localtime() . " \n");
		unlink "$Mach_DB.fasta";
		rename "$Mach_DB.tmp", "$Mach_DB.fasta";

		if ((!-e "$Mach_DB.fasta") || (&dos_file_size("$Mach_DB.fasta") != $tmpsize)) {
			&write_logfile_ftp("\nFAILED to create $Mach_DB.fasta, but $Mach_DB.tmp might be ok. " . localtime() . " \n\n");
			$errors = 1;
			return 1;
		} else {
			&write_logfile_ftp("New $Mach_DB.fasta READY on " . localtime() . " \n");
			return 0;
		}

	} else {

		&write_logfile_ftp("\nUnzipping to $Machine FAILED, no unzipped file OR unzipped file smaller than zip file. " . localtime() . " \n\n");
		$errors = 1;
		return 1;
	}

	return 1 if $errors;
	return 0;
}


# This routine encapsulates the entire Prospector portion of the autodownload process.
#
# Returns 0 on success, 1 on error
sub ftp_prospector {
	if ($DB eq "nr") {
		$errors = system($prospector_indexer);
		unless ($errors) {
			# debug: add utime $atime,$mtime, "output file"; command here when prospector is up and running?
			&write_logfile_ftp("\nProtein Prospector indexing program ran successfully on $Machine at " . localtime() . "\n");
		} else {
			&write_logfile_ftp("\nProtein Prospector indexing program failed on $Machine: $errors, " . localtime() . "\n\n");
			return 1;
		}
	} else {
		&write_logfile_ftp("\nProtein Prospector not run because database is not nr, " . localtime() . "\n");
	}

	return 0;
}


# This routine encapsulates the entire FastaIdx portion of the autodownload process.
#
# Returns 0 on success, 1 on error
sub ftp_fastaidx {
	($Mach_DB = "$scratch_dbdir\\$DB") =~ s!/!\\!g;

	&write_logfile_ftp("\nRunning FastaIdx on $Mach_DB.fasta on $Machine, " . localtime() . "\n");

	# run indexing code

	# Routine from the require'd file $fastaidx_lib
	&createidx("$Mach_DB.fasta");

	$sizeof_index = &dos_file_size("$Mach_DB.flatidx");
	if ($sizeof_index > 0) {
		&write_logfile_ftp("FastaIdx Indexing successful on " . localtime() . "\n");
	} else {
		&write_logfile_ftp("\nFastaIdx Indexing failed on " . localtime() . "\n\n");
		return 1;
	}
	# make sure the flatidx has the same access and modification times
	utime $atime,$mtime, "$Mach_DB.flatidx";

	return 0;
}


# This routine encapsulates the entire MakeDB portion of the autodownload process.  Just call it
# and it should run makedb on the current database.  The copying of the completed index is done
# later.
#
# All output goes into the scratch directory, but the params file needs to be modified and placed in
# whereever runmakedb4.pl expects it, which is most likely the regular makedb4 work directory.
#
# Returns 0 on success, 1 on error
sub ftp_makedb {
	my ($age1, $age2, $age3);

	if (($scratch_dbdir eq "") or (!(defined $scratch_dbdir))
		or ($makedb_dir eq "") or (!(defined $makedb_dir))) {
		# Assume this machine is not a makedb4 machine
		&write_logfile_ftp("\n\nError: No local MakeDB4 scratch work dir specified for $Machine; this machine is most likely NOT a MakeDB4 machine; aborting MakeDB4 at " . localtime() . "\n\n");
		return 1;
	}

	# Change the path to the template, this works for both running remotely and running locally (in the latter case, nothing
	# changes)
	$default_makedbparams =~ s/$old_incdir/$incdir/i;
	$scratch_dbdir =~ s!/!\\!g;
	$makedb_dir =~ s!/!\\!g;

	&write_logfile_ftp("\nRunning MakeDB4. . .\n");

	#################################
	# Begin modifying the params file
	# Change the directory to find the params file, it is changed back to $scratch_dbdir at the end of this sub
	chdir "$makedb_dir" or (&write_logfile_ftp("\nCould not find the local MakeDB4 directory $makedb_dir at " . localtime() . "\n\n") && return 1);
	# Using default params file in include dir, edit this file to change the behavior of makedb in the autodownload sequence
	open MAKEDB_PARAMS, "$default_makedbparams" or (&write_logfile_ftp("\nError: Could not find the MakeDB4 template file $default_makedbparams at " . localtime() . "\n\n") && return 1);
	@lines = <MAKEDB_PARAMS>;
	close MAKEDB_PARAMS;

	$db_type = &get_dbtype("$scratch_dbdir/$DB.fasta");
	if ($db_type == -1) {
		# Problem auto-detecting
		&write_logfile_ftp("\nError: auto-detecting on $scratch_dbdir/$DB.fasta failed; aborting MakeDB4 at " . localtime() . "\n\n");
		return 1;
	}
	$db_nrf = ($db_type == 0) ? 0 : 3;
	$db_lines_found = 0;
	foreach $line (@lines) {
		# edit the line: database_name = C:\Database\nr.fasta
		if ($line =~ /^database_name/) {
			$line =~ s/^(database_name\s*=\s*)(.+?)(\s*;|\s*$)/$1$scratch_dbdir\\$DB.fasta$3/;
			$db_lines_found++;
		}

		# edit the line: sort_directory = C:\Database\Temp
		if ($line =~ /^sort_directory/) {
			$line =~ s/^(sort_directory\s*=\s*)(.+?)(\s*;|\s*$)/$1$makedb_sortdir$3/;
			$db_lines_found++;
		}

		# edit the line: sort_program = C:\Databae\makedb\sort.exe
		if ($line =~ /^sort_program/) {
			$line =~ s/^(sort_program\s*=\s*)(.+?)(\s*;|\s*$)/$1$makedb_dir\\sort.exe$3/;
			$db_lines_found++;
		}

		# edit the line: protein_or_nucleotide_dbase = 0     ; 0=proteinDB, 1=nucleotideDB
		if ($line =~ /^protein_or_nucleotide_dbase/) {
			$line =~ s/^(protein_or_nucleotide_dbase\s*=\s*)(.+?)(\s*;|\s*$)/$1$db_type$3/;
			$db_lines_found++;
		}

		# edit the line: nucleotide_reading_frames = 0       ; 0=none, 1=3 forward, 2=3 reverse, 3=both
		if ($line =~ /^nucleotide_reading_frames/) {
			$line =~ s/^(nucleotide_reading_frames\s*=\s*)(.+?)(\s*;|\s*$)/$1$db_nrf$3/;
			$db_lines_found++;
		}

		last if ($db_lines_found >= 5);
	}
	# All 3 lines must be edited or else makedb will fail
	if ($db_lines_found != 5) {
		&write_logfile_ftp("\nError: The file $default_makedbparams is not in the correct format; aborting MakeDB4 at " . localtime() . "\n\n");
		return 1;
	}

	# Change the "open" line below if the executable for makedb4 ever changes the name of the params file it takes
	open MAKEDB_PARAMS, ">makedb.params" or (&write_logfile_ftp("\nError: Could not write to the makedb.params file at " . localtime() . "\n\n") && return 1);
	print MAKEDB_PARAMS @lines;
	close MAKEDB_PARAMS;

	&write_logfile_ftp("Update of makedb.params successful at " . localtime() . "\n");

	# End modifying the params file
	###############################


	# Edit command line preferences to makedb here
	# These args should be left out of the command line:
	# stayon=1			-- this will stall the script by making the process sleep
	# webcopy=1			-- this will copy the hdr to the webserver, but we will save that until the Distribution Phase
	$final_hdr = "$DB.fasta.hdr";
	$makedb_args = "-F -I -T";

	# Since .dgt files are so large, just overwrite any existing files.  This may need to be changed in the future -- 7-6-01 P.Djeu
	&write_logfile_ftp("Running $perl $cgidir/$runmakedb4 -O$scratch_dbdir/$final_hdr $makedb_args at " . localtime() . "\n");
	system("$perl $cgidir/$runmakedb4 -O$scratch_dbdir/$final_hdr $makedb_args");

	# Ensure that the files created are safe and correct.  Check if the .dgt file is larger than the original database (it should
	# be) and that all of the output files are within a day old.
	$sizeof_makedb = &dos_file_size("$scratch_dbdir/$DB.fasta.dgt");
	$sizeof_makedb2 = &dos_file_size("$scratch_dbdir/$DB.fasta");

	if ($sizeof_makedb < $sizeof_makedb2) {
		&write_logfile_ftp("\nError: The .dgt output file is $sizeof_makedb bytes, while original dbase is $sizeof_makedb2 bytes, file smaller than expected at " . localtime() . "\n\n");
		return 1;
	}

	$age1 = -M "$scratch_dbdir/$DB.fasta.hdr";
	$age2 = -M "$scratch_dbdir/$DB.fasta.dgt";
	$age3 = -M "$scratch_dbdir/$DB.fasta.idx";

	# If -M returns a negative number, then this means that the file was created after this process (ftp_fastadb.pl) was started.  In
	# this case, we can assume that makedb4 did indeed create the file when we asked it to.
	if (($age1 < 0) && ($age2 < 0) && ($age3 < 0)) {
		# Do nothing, the files are all recent
	} else {
		&write_logfile_ftp("\nError: The MakeDB4 output files were not created by this process, indexing was not successful at " . localtime() . "\n\n");
		return 1;
	}

	# make sure all indices of the database have same access and modification times
	utime $atime,$mtime, "$scratch_dbdir/$DB.fasta.hdr";
	utime $atime,$mtime, "$scratch_dbdir/$DB.fasta.dgt";
	utime $atime,$mtime, "$scratch_dbdir/$DB.fasta.idx";

	# Change back to dir before this function
	chdir "$scratch_dbdir" or (&write_logfile_ftp("\nCould not find the local database directory $scratch_dbdir on $Machine at " . localtime() . "\n\n") && return 1);

	return 1 if $errors;

	&write_logfile_ftp("MakeDB4 indexing SUCCESSFUL on " . localtime() . "\n");
	return 0;
}

############### End Primary Functions ################

# End of file