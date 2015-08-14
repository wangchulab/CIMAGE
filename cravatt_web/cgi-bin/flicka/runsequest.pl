#!/usr/local/bin/perl

#-------------------------------------
#	Run Sequest,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


## runsequest.pl

## this script is spawned by sequest_launcher.pl in order to run Sequest and
## subsequently keep tabs on it until the Sequest process completes.
##
## this is version 3
##
## a given Sequest process can only be
## suspended/resumed/killed by its respective "manager process", i.e. this script.
## the script interprets instructions from Sequest Status in the form of files in the seqprocdir.

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

use Win32::Process;
use Win32::ChangeNotify;

# interpret command line arguments
foreach (@ARGV) {
	($pmtr,$value) = split /=/;
	$$pmtr = $value;
}

$cwd = "$seqdir/$dir";
$db = $DEFAULT_DB if ($db eq "sequestparams");
$status = ($start_suspended) ? "SUSPENDED" : "RUNNING";

&error("Database $db is not available on $ENV{'COMPUTERNAME'}") unless (-e "$dbdir/$db");

if ($check_index) {
	($db_index = $db) =~ s/\.fasta$/.inx/;
	&error("Sequest index for $db not available on $ENV{'COMPUTERNAME'}") unless (-e "$dbdir/$db_index");
}

&establish_connection;


# run Sequest
$myproc = &run_in_background($cmdline,$cwd);


# suspend shortly after startup if requested
if ($start_suspended) {
	sleep 1;
	$myproc->Suspend();
	&seqlog("$ENV{'COMPUTERNAME'}:$procID\t".localtime()."\t$dir STARTED in SUSPENDED state.\n");
} else {
	&seqlog("$ENV{'COMPUTERNAME'}:$procID\t".localtime()."\t$dir STARTED.\n");
}



while (1) {

	&reestablish_connection unless ($connected);

	foreach $signal (@signals) {

		if ($signal eq "kill") {

			# look for operator name in contents of signal file
			if (open(MSG, "<$mysignaldir/$signal")) {
				$operator = <MSG>;
				close MSG;
			} else {
				&seqlog("$ENV{'COMPUTERNAME'}:$procID\t".localtime()."\tkill signal received from unknown operator.\n");
			}

			$myproc->Kill(1);

			&seqlog("$ENV{'COMPUTERNAME'}:$procID\t".localtime()."\t$dir KILLED by runsequest.pl\n");

			# write this also to the directory log (added 8-10-98)
			&write_log($dir, "Sequest killed on $ENV{'COMPUTERNAME'}  " . localtime() . "  $operator");

			&cleanup;
			exit;

		} elsif (($signal eq "pause") && ($status ne "SUSPENDED")) {

			$status = "SUSPENDED";
			$myproc->Suspend();
			&seqlog("$ENV{'COMPUTERNAME'}:$procID\t".localtime()."\t$dir $status.\n");
			&update_status_info;

		} elsif (($signal eq "continue") && ($status ne "RUNNING")) {

			$status = "RUNNING";
			$myproc->Resume();
			&seqlog("$ENV{'COMPUTERNAME'}:$procID\t".localtime()."\t$dir $status.\n");
			&update_status_info;

		}

		unlink("$mysignaldir/$signal");

	}

	# listen: wait for signal from Status, or for Sequest process to finish
	@wait_objects = ($myproc, $cnobj);
	$retval = Win32::ChangeNotify::wait_any(@wait_objects);
	$cnobj->reset();

	# check to see if Sequest is still running
	&abort if ($retval == 1);

	# replace the .status file if it's gotten deleted
	&update_status_info unless (-e "$mysignaldir/.status");

	($connected,@signals) = &scan_for_signals;

}



# put status and vital info in signature file
sub update_status_info {
	open STATUS, ">$mysignaldir/.status";
	flock STATUS, $LOCK_EX;
	print STATUS "$dir&$db&$status\n";
	close STATUS;
}


sub abort {

	&seqlog("$ENV{'COMPUTERNAME'}:$procID\t".localtime()."\t$dir found DEAD\n");
	&cleanup;
	exit;

}


sub cleanup {

	close MYSTAMP;
	&deltree($mysignaldir);

}


sub establish_connection {

	mkdir($seqprocdir, 0777) unless (-d "$seqprocdir");
	mkdir("$seqprocdir/$ENV{'COMPUTERNAME'}", 0777) unless (-d "$seqprocdir/$ENV{'COMPUTERNAME'}");

	# create a directory to receive pause/continue/kill signals
	$mysignaldir = "$seqprocdir/$ENV{'COMPUTERNAME'}/$procID";
	mkdir($mysignaldir, 0777) unless (-d "$mysignaldir");

	&update_status_info;

	# create signature ("stamp") file for this process in directory $mysignaldir
	$mystampfile = "$mysignaldir/.running";
	open(MYSTAMP, ">$mystampfile");
	# this should prevent duplicate runs
	flock (MYSTAMP, ($LOCK_EX | $LOCK_NB)) || exit;

	# create ChangeNotify object to monitor $mysignaldir
	$cnobj = Win32::ChangeNotify->new($mysignaldir, 0, FILE_NAME) || exit;

	($connected,@signals) = &scan_for_signals;

}


sub scan_for_signals {

	opendir(MYDIR, $mysignaldir) || return (0);
	my @allfiles = readdir(MYDIR);
	closedir MYDIR;

	# a signal could be any file whose name doesn't start with a "."
	my @signals = grep(((/^[^\.]/) && (-f "$mysignaldir/$_")), @allfiles);

	return (1,@signals);

}


# this is run in the event that the main server crashes; it attempts every $interval seconds to reestablish contact
sub reestablish_connection {

	my $interval = 30;

	close MYSTAMP;
	$cnobj->close();

	until ((-d "$seqprocdir") || (mkdir($seqprocdir,0777))) {
		sleep $interval;
	}

	&establish_connection;

}


sub error {

	mkdir($seqprocdir, 0777) unless (-d "$seqprocdir");
	mkdir("$seqprocdir/$ENV{'COMPUTERNAME'}", 0777) unless (-d "$seqprocdir/$ENV{'COMPUTERNAME'}");
	$mysignaldir = "$seqprocdir/$ENV{'COMPUTERNAME'}/$procID";
	mkdir($mysignaldir, 0777) unless (-d "$mysignaldir");

	open(ERRORMSG, ">$mysignaldir/error");
	print ERRORMSG "$_[0]";
	close ERRORMSG;
	rename("$mysignaldir/error", "$mysignaldir/.error");

	exit;

}


sub seqlog
{
	open(LOGFILE,">>$seqlog");
	print LOGFILE "@_";
	close(LOGFILE);
}
