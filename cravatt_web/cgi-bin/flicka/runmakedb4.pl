#!/usr/local/bin/perl

#-------------------------------------
#	RunMakeDB4,
#	(C)1999 Harvard University
#	
#	W. S. Lane / P. Djeu
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 7/21/00 by Peter Djeu
# Description: When fired off on the database indexer, this script runs the executable and creates a logfile.
#
# For input, it takes the arguments:
# * all command line args for makedb.exe, which must include the -O[indexed database name.tmp] flag in order
# to create logfiles.
# * stayon=[0|1]				-- 1 means keep the window open via sleep, 0 means close the window when done
# * webcopy=[0|1]				-- 1 means copy the hdr to the webserver when done, 0 means don't copy
#
# NOT a CGI program.
################################################
# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1!;
	unshift (@INC, "$path/etc", "$path/seqcomm", "$path/seqcomm/remote");
	require "microchem_include.pl";					# Always need this
	require "fasta_include.pl";

	if ($multiple_sequest_hosts) {
		require "seqcomm_include.pl";				# Using multiple sequest hosts, so we need this

		if ($ENV{'COMPUTERNAME'} ne "$webserver") {
			require "seqcomm_include_remote.pl";	# If on a remote host
		}
	} else {
		# these are the variables that need to be defined for a run on the webserver
		# should be the Machine specific variables (local paths)
		print "Error: no support yet for running without multiple sequest hosts\n";
		exit;
	}
}

use File::Copy;

$path_to_local_params = "$makedb_dir/makedb.params";

# create a file $mystamp and flock it so that processes on other servers will know we're running
$mystamp = "\\\\$webserver/database/.runmakedb_running";
open(MYSTAMP, ">$mystamp") or &net_die("Unable to acquire the file lock, runmakedb4 is already running\n", 1);
unless (flock MYSTAMP, ($LOCK_EX | $LOCK_NB)) {
	&net_die("Could not acquire the file lock, runmakedb4 is already running", 1);
}

# Parse args
# MakeDB4 args
# -Ostring -- the indexed database to be created, where string is the name
# -F -- if specified, use multiple temp files during indexing
# -I -- if specified, display additional information about indexing
# -U -- if specified, use a unique sequence sort (database will be smaller, but no duplicates)
# -C -- if specified, the database will be considered to be chromosome data
# -T -- if specified, timestamps will be printed during each step
# -D -- if specified, the outfiles will be automatically distributed to other computers
# -Bnumber -- number can be 1-4, inclusive; if specified, certain stages of the makedb process will be bypassed
#	-B1 - skip generating the digest header
#	-B2 - skip generating the digest index
#	-B3 - skip generating the peptide txt files
#	-B4 - skip sorting the peptide txt files
#
# Perl script args
# * stayon=[0|1]				-- 1 means keep the window open via sleep, 0 means close the window when done
# * webcopy=[0|1]				-- 1 means copy the hdr to the webserver when done, 0 means don't copy

$args = "";
$final_db = "";
$stayon_val = 0;
$webcopy_val = 0;
$auto_distribute = 0;
foreach (@ARGV) {
	if (($c,$more) = m/^-(.)(.*)/) {
		if ($c eq "o" || $c eq "O") {
			$final_db = $more;
			$args .= " -O$final_db";
		} elsif ($c eq "f" || $c eq "F") {
			$args .= " -F";
		} elsif ($c eq "i" || $c eq "I") {
			$args .= " -I";
		} elsif ($c eq "u" || $c eq "U") {
			$args .= " -U";
		} elsif ($c eq "c" || $c eq "C") {
			$args .= " -C";
		} elsif ($c eq "t" || $c eq "T") {
			$args .= " -T";
		} elsif ($c eq "d" || $c eq "D") {
			$auto_distribute = 1;
		} elsif ($c eq "b" || $c eq "B") {
			$args .= " -$c$more";
		} else {
			# Just give a warning
			print("Warning: unrecognized flag -$c$more\n\n");
		}
	# Not a flag, check the Perl script args
	} elsif (($temp) = m/stayon\s*=\s*(\d)/) {
		$stayon_val = $temp;
	} elsif (($temp) = m/webcopy\s*=\s*(\d)/) {
		$webcopy_val = $temp;
	} else {
		# Just give a warning
		print("Warning: unrecognized flag $_\n\n");
	}
}

if (!$final_db) {
	# Die because without a database, we can't write to a logfile
	&net_die("No database was specified by the caller");
}

if (!($final_db =~ m/\.hdr$/)) {
	&net_die("Database header $final_db is incompatible, indexed database headers must end with .hdr");
}

# Set up the trio of files that will be created
$header_db = $final_db;
($digest_db = $final_db) =~ s/\.hdr/\.dgt/i;
($index_db = $final_db) =~ s/\.hdr/\.idx/i;

# The base database should be in the default database dir, without the .hdr extension
($db_base_dir, $db_base_name) = ($final_db =~ m!(^.*)[\\/]([^\\/]+)$!);		# Remove the directory
$db_base_name =~ s/\.hdr$//i;								# Remove .hdr at the end
$db_base_name = "$dbdir\\$db_base_name";					# Prepend the default directory

$db_size = (-e $db_base_name) ? &dos_file_size("$db_base_name") : 0;

$logfile = $final_db . ".log";
&create_logfile;

&write_logfile("Creating index for $db_base_name ($db_size bytes).\n");


open (PARAMS, "$path_to_local_params") or &error_logfile("Error: Perl script cannot open $path_to_local_params file");
@lines = <PARAMS>;
close PARAMS;

# Make a record of the params used in this run for the logfile
$wholefile = join ("", ("\n----- Begin makedb.params file -----\n\n", @lines, "\n----- End makedb.params file -----\n\n"));
&write_logfile("$wholefile");

$cmdline = "$makedb_exe $args";

# chdir to find the makedb.params file
chdir "$makedb_dir";

# Actually run makedb.exe
print "Running: $cmdline\n";
&write_logfile("Running: $cmdline\n");
system $cmdline;
print "\n";

# All three output files must exit6
if ((!(-e "$header_db")) || (!(-e "$digest_db")) || (!(-e "$index_db"))) {
	# If any of these headers do not exist, exit with error message
	&error_logfile("\nERROR: MakeDB4 did not produce all 3 index files, EXITING.\n\n");
}

# Get the file sizes to record in the log
$db_size_product1 = &dos_file_size("$digest_db");
$db_size_product2 = &dos_file_size("$header_db");
$db_size_product3 = &dos_file_size("$index_db");

&write_logfile("Finished indexing $final_db.\n\t.hdr size:\t$db_size_product2 bytes\n\t.dgt size:\t$db_size_product1 bytes\n\t.idx size:\t$db_size_product3 bytes\n");

# Check to see if we ran out of diskspace, when this happens, ususally the final_db is very small
# Current algorithm: if indexed db is smaller than original, give warning
if ($db_size_product1 < $db_size) {
	print "WARNING: The indexed database is smaller than expected.  The disk may have run out of space during the indexing.\n";
	&write_logfile("WARNING: The indexed database is smaller than expected.  The disk may have run out of space during the indexing.\n");
}

# Age check
$age1 = -M "$header_db";
$age2 = -M "$digest_db";
$age3 = -M "$index_db";
# If -M returns a negative number, then this means that the file was created after this process (ftp_fastadb.pl) was started.  In
# this case, we can assume that makedb4 did indeed create the file when we asked it to.
if (($age1 < 0) && ($age2 < 0) && ($age3 < 0)) {
	# Do nothing, the files are all recent
} else {
	# Exit with error message
	&error_logfile("\nERROR: The MakeDB4 output files are older than this process, EXITING.\n\n");
}

# automatically distribute the database and three outfiles to other computers
if ($auto_distribute){	
	@dest_hosts = &GetListFromString($DEFAULT_COPY_HOSTS);
	my @distributedbs = ($db_base_name, $header_db, $digest_db, $index_db);		
	foreach $host (@dest_hosts) {
		LINE: foreach $basedb (@distributedbs) {
			my $destdb = &GetFilename($basedb);
			$destdb = "//$host/Database/$destdb";
	
			my $backup = "$destdb" . ".previous";
			if (($host eq $DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER) && ($basedb eq $db_base_name)) {}
			else {
				# If file exists, make a backup version, rename it to $destdb.previous
				if (-e "$destdb") {
					if (rename "$destdb", "$backup") {
						print "Rename $basedb to $backup\n";
						&write_logfile("Rename $basedb to $backup\n");	
					}
					else {
						print "$destdb exists, unable to make a backup version, and unable to copy $basedb to $destdb\n";
						&write_logfile("$destdb exists, unable to make a backup version, and unable to copy $basedb to $destdb\n");
						next LINE;
					}
				}
				# Copy the database files to other hosts
				if (&copy("$basedb", "$destdb")) {
					print "$basedb copied to $destdb\n";
					&write_logfile("$basedb copied to $destdb\n");
				}
				else {
					print "Unable to copy $basedb to $destdb\n";
					&write_logfile("Unable to copy $basedb to $destdb\n");
				}
			}
		}
	}
}

# If the caller of this command line requested, copy the .hdr file over to the webserver directly so that the newly
# indexed database can be used with Sequest.  Do not worry about overwriting because the .hdr index is small
# and easily reconstructable.
#
# Note: when Sequest Launcher autodetects an indexed database, it uses the info from this .hdr file to
# determine what type of db the original is.  So keep in mind that if this .hdr is wrong, Sequest
# will autodetect incorrectly.
if (($ENV{'COMPUTERNAME'} ne "$webserver") && ($webcopy_val)) {	# If we are remote, copy if the caller asks
	# the indexed db's are in the $db_base_dir
	($db_base_dir) =~ s!\\!\\\\!;	# Duplicate all backslashes so that they read correctly on the left side of a s///
	($dest_index = $final_db) =~ s!$db_base_dir[\\/]!!i;

	# Copy header file to the webserver so that it is accessible for Sequest runs
	$dest_index = "\\\\$webserver/Database/" . $dest_index;
	if (copy("$final_db", "$dest_index")) {
		print "$final_db copied to $dest_index.\n";
		&write_logfile("$final_db copied to $dest_index.\n");
	} else {
		print "Unable to copy placeholder $final_db to $dest_index.\n";
		&write_logfile("Unable to copy placeholder $final_db to $dest_index.\n");
	}
} elsif ($webcopy_val) {		# On the webserver, check if we need to copy to the default directory
	$db_base_dir =~ s!\/!\\!g;
	$dbdir =~ s!\/!\\!g;
	# Check if the target from the command line is the same as the default, if not, we need to copy
	if ($db_base_dir ne $dbdir) {
		if (copy("$final_db", "$dest_index")) {
			print "$final_db copied to $dest_index.\n";
			&write_logfile("$final_db copied to $dest_index.\n");
		} else {
			print "Unable to copy placeholder $final_db to $dest_index.\n";
			&write_logfile("Unable to copy placeholder $final_db to $dest_index.\n");
		}
	}
}

&write_logfile("MakeDB completed SUCCESSFULLY.");

# delete the temporary locked file
flock MYSTAMP, $LOCK_UN;
close MYSTAMP;
unlink "$mystamp";

if ($stayon_val) 
{
	print "\n\nMakeDB COMPLETE.  You can close this window with ctrl-c ***after*** Admin has seen the results.\n";
	sleep;
}

# We're done!
exit 0;


# Creates the logfile and overwrites the existing file.  The one and only arg is the file name.
# $logfile must be defined before this function is called.
sub create_logfile {
	my $curr_time = localtime();
	open (LOGFILE, ">>$logfile") or &net_die("Unable to create logfile $logfile");
	print LOGFILE "\n----------------------------------------------------------------\n";
	print LOGFILE "Starting MakeDB4 run at $curr_time.\n";
}
	

# Write a line to the logfile, one and only arg is the line to write
# $logfile must be defined before this function is called.
sub write_logfile {
	my $curr_time = localtime();
	open (LOGFILE, ">>$logfile") or &net_die("Unable to access logfile $logfile");
	print LOGFILE "$curr_time: $_[0]\n";
	close LOGFILE;
}


# Error routine writes date and error message to logfile because die error messages don't last, call this routine only
# after the logfile has been created.
# Because this routine exits, also delete the locked file.
sub error_logfile {
	my $curr_time = localtime();
	open (LOGFILE, ">>$logfile") or &net_die("Unable to access logfile $logfile");
	print LOGFILE "$curr_time: $_[0]\n";
	close LOGFILE;

	flock MYSTAMP, $LOCK_UN;
	close MYSTAMP;
	unlink "$mystamp";

	exit 1;
}

# Last ditch error routine, instead of dying, send a netsend message to the server so that the error is
# actually displayed on screen.
# Args: the string to display
# 2nd arg, if specified and true, says not to delete the file lock, helpful when dying before the
# lock can be acquired
sub net_die {
	my ($mesg, $skip_lock_release) = @_;

	print "runmakedb4.pl Error: $mesg";
	$dest_machine = $ENV{"COMPUTERNAME"};
	system("net send $dest_machine \"runmakedb4.pl Error: $mesg\"");

	if (!$skip_lock_release) {
		flock MYSTAMP, $LOCK_UN;
		close MYSTAMP;
		unlink "$mystamp";
	}

	exit 1;
}

# End of runmakedb4.pl