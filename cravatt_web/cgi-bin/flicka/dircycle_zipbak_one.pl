#!/usr/local/bin/perl

#-------------------------------------
#	Dircycle Zipbak,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
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

require "dirzip_include.pl";

#perl script to zip sequest dirs to zipfiles of the same name.
#requires newest PkZip25.exe for cmdline and preservation of 95/NT longfilenames.

chdir "$seqdir";
if ( defined $ARGV[0] ) {
	$switch = $ARGV[0];
	shift;
}
if ($switch eq "-d"){
	foreach $dir (@ARGV)
	{	
		next unless (-d "$seqdir/$dir");
		next if (($dir eq ".") || ($dir eq ".."));
		&delete_dir;
	}
}
if (($switch eq "-da")or($switch eq "-a")){

	$delete_dir = 1 if ($switch eq "-da");
	foreach $dir (@ARGV)
	{
		next unless (-d "$seqdir/$dir");
		next if (($dir eq ".") || ($dir eq ".."));
		system("echo ------ $dir -------");
		# Added -excl=runsummary_cache.tmp to exclude that file, as it is large and can be derived from the .dta files again (sdr 08/24/01)
		system("echo $zipexe -add=update -excl=runsummary_cache.tmp -dir=current -zipdate=newest $seqzip/$dir.zip $dir/");
		#zip adding new, updating existing, store path from current $seqdir, set zipdate to oldest in dir, zipfile in $seqdir/$seqzip (wsl 9/26/99)
		system("$zipexe -add=update -excl=runsummary_cache.tmp -dir=current -zipdate=oldest $seqzip/$dir.zip $dir/*");

		#delete directory ONLY if user asked to AND if zip file of nonzero size was successfully created
		&delete_dir if (($delete_dir) && (-s "$seqdir/$seqzip/$dir.zip"));
	}
}

sub delete_dir {

	opendir (DIR, "$seqdir/$dir");
	@allfiles = grep !/^\.\.?$/, readdir DIR;
	closedir DIR;
	unlink map "$seqdir/$dir/$_", @allfiles;
	$errcode = (rmdir "$seqdir/$dir") ? 0 : $!;
	(@return) = &removefrom_flatfile ($dir);
	$return = shift (@return);

}