#!/usr/bin/env perl
# SeqCov
# A script written to develop a CGI linked to DTASelect output and representing the peptide sequence coverage of a given locus
# Version 0.6, 07/02/2002 + changes 08/08/02 (Hayes)
# Copyright 2002 Johannes Graumann, California Institute of Technology
# Contact: graumann@its.caltech.edu
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
$! =1;

# check for QUERY_STRING truncation ...
	$truncalarm = 0;
	unless ($ENV{QUERY_STRING} =~ /\*[\s]*?/) {
		++$truncalarm;
	}
# take input from CGI call ...
	my $input = $ENV{QUERY_STRING};
# Hayes - get input for next URL call
	my $nextURL = $input;
# remove URL-encoding ...
	$input =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
# Stop people from using subshells to execute commands ...
	$input =~ s/~!/ ~!/g;
# split the query input at "&" ...
	my @inputs = split ("&",$input);
	chomp (@inputs);
# extract data base path ...
	$dbase = shift (@inputs);
# extract locus name ...
	$locus = shift (@inputs);
# go and get locus sequence from data base ...
	open (DBASE,"$dbase") or die "Can't open $dbase: $!\n";
	$dbcb = 0;
	my $alignstring;			#!
	while ($dbline = <DBASE>) {
		if ($dbcb == 0) {
			if ($dbline =~ /^>(.*)\Q$locus\E[\s]/ || $dbline =~ /^>(.*)\Q$locus\E/) {
				# initiate mode shift for sequence grabbing ...
				$dbcb = 1;
				# grab complete ORF annotation from data base (after removing ">") ...
				$dbline =~ s/^>//;
				$locuscomplete = $dbline;
				chomp ($locuscomplete);					#!
			}
		}
		elsif ($dbcb == 1) {
			# encountering proper FASTA ORF end ...
			if ($dbline =~ /\*/) {
				$dbcb = 2;
			}
			# no proper FASTA ORF end: terminate at next locus name (">") ...
			if ($dbline =~ /^>/) {
				$dbcb = 2;
			}
			else {
				# pack the sequence into one big string ...
				chomp ($dbline);
				$alignstring = "$alignstring$dbline";
		       }
		}
		else {
			last;
		}
	}
# remove any characters aside from \w and \* from the $alignstring
	$alignstring =~ s/[^\w\*]//g;
# counting residues of the ORF aligning to ...
	while ($alignstring =~ /\w/g) {
		$residueno++;
	}
# counting all characters in $alignstring (including ORFending "*") ...
	while ($alignstring =~ /[\w\*]/g) {
		$completeno++;
	}
# positioning the coverage bars ...
	my @outputs;
	for $a (0 .. $#inputs) {
		# remove trailing "*" ...
		$inputs[$a] =~ s/\*//;
		# split seqence coverage into seperate streches ...
		@workarray = split (/\^/,$inputs[$a]);
		chomp (@workarray);
		$spacerlength = 0;
		for $b (0 .. $#workarray) {
			# extract coverage data if it is complete ...
			if ($workarray[$b] =~ /^([\d]+)\+([\d]+)?/) {
				$startno = $1 - 1;
				$strech = $2;
				# calculate numbers for proper stacking of coverage streches and assemble them ...
				$spacer = $startno - $spacerlength;
				$outputs[$a] = $outputs[$a] . " " x $spacer . "-" x $strech;
				$spacerlength = length($outputs[$a]);
			}
		}
		@workarray = ();
	}
# chop sequence and coverage bars into pieces of $piecelength and group it in blocks of 10 for presentation ...
	$piecelength = 80; # should be multiple of 10 ...
	my @alignstringformated = $alignstring =~ /(.{1,$piecelength})/g;
		for $c (0 .. $#alignstringformated) {
			@workarray = $alignstringformated[$c] =~ /(.{1,10})/g;
			chomp (@workarray);
			#more Hayes mucking to make highlight optional
			if ($inputs[-1] =~ /trypsin/) {
				for $d (0 .. $#workarray) {
					$workarray[$d] =~ s/R/<font color=\"red\">R<\/font>/g;
					$workarray[$d] =~ s/K/<font color=\"red\">K<\/font>/g;
				}
			}
			$alignstringformated[$c] = "@workarray";
			@workarray = ();
		}
	my @outputsformated;
	for $c (0 .. $#outputs) {
		@workarray = $outputs[$c] =~  /(.{1,$piecelength})/g;
		for $d (0 .. $#workarray) {
			@workarraytwo = $workarray[$d] =~ /(.{1,10})/g;
			$workarray[$d] = "@workarraytwo";
			@workarraytwo = ();
		}
		@outputsformated = (
			@outputsformated,
			[@workarray]
		);
		@workarray = ();
	}
	@outputs = ();

# start giving out html ...
	print "Content-type: text/html\n\n";
	print "<html>\n";
	print "<HEAD>\n";
	print "<TITLE>SeqCov: $locus</TITLE>\n";
	print "</HEAD>\n";
	print "<body>\n";# background=\"http://squatch.scripps.edu/images/marble.jpg\" ALIGN=\"CENTER\">\n";
	print "<table border>\n";# ALIGN=\"CENTER\">\n";
	print "<TR><TD colspan=\"2\"><B><font color=\"red\">$locuscomplete</font></B></TD>\n";
	print "<TR><TD>Residues: $residueno\n</TD>";
# Hayes-added for NCBI blast
	print "<TD><a target=\"Win2\" HREF=\"http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?PROGRAM=blastp&LAYOUT=OneWindows&AUTO_FORMAT=Fullauto&QUERY=$alignstring\">NCBI BLAST</a></TD>\n";

# was the coverage data truncated?
	if ($truncalarm > 0) {
		print "<TR><TD><B><font color=\"red\">Careful: coverage data was truncated due to CGI character limitations!</font></B></TD>\n";
	}
# print alignments + bells and whistles ...
	print "<TR><TD colspan=\"2\"><pre>\n\n";
	for $c (0 .. $#alignstringformated) {
		$increment = $c * $piecelength;
		$printincrement = $increment + 1;
		if ($completeno < 100){
			if ($increment < 10) {
				print "      $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "        $outputsformated[$d][$c]     \n";
					}
				}
			}
			else {
				print "     $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "        $outputsformated[$d][$c]     \n";
					}
				}
			}
		print "\n";
		}
		elsif ($completeno < 1000){
			if ($increment < 10) {
				print "       $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "         $outputsformated[$d][$c]     \n";
					}
				}
			}
			elsif ($increment < 100 && $increment >= 10) {
				print "      $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "         $outputsformated[$d][$c]     \n";
					}
				}
			}
			else {
				print "     $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "         $outputsformated[$d][$c]     \n";
					}
				}
			}
		print "\n";
		}
		else {
			if ($increment < 10) {
				print "        $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "          $outputsformated[$d][$c]     \n";
					}
				}
			}
			elsif ($increment < 100 && $increment >= 10) {
				print "       $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "          $outputsformated[$d][$c]     \n";
					}
				}
			}
			elsif ($increment < 1000 && $increment >= 100) {
				print "      $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "          $outputsformated[$d][$c]     \n";
					}
				}
			}
			else {
				print "     $printincrement $alignstringformated[$c]     \n";
				for $d (0 .. $#outputsformated) {
					if (exists($outputsformated[$d][$c]) && $outputsformated[$d][$c] =~ /-/) {
						print "          $outputsformated[$d][$c]     \n";
					}
				}
			}
		print "\n";
		}
	}

print "\n</pre></td>\n";

# more Hayes code to add a section that can be cut and pasted into other search.... #
my $cutstring = $alignstring;
$cutstring =~ s/\G(\w{100})/$1\n/g;

print "\n</td><tr><td width=\"500\" colspan=\"2\"><pre>$cutstring</pre></td></tr>";

if ($nextURL =~ s/(.+)trypsin$/$1/)
	{
	print "<tr><td colspan=\"2\" ALIGN=\"center\"><a target=\"Win1\" HREF=\"http://localhost/cgi-bin/SeqCov.pl?$nextURL\">No trypsin highlight</a></td></tr>";
	}
elsif ($nextURL =~ s/(.+)/$1trypsin/)
	{
	print "<tr><td colspan=\"2\" ALIGN=\"center\"><a target=\"Win1\" HREF=\"http://localhost/cgi-bin/SeqCov.pl?$nextURL\">Trypsin highlight</a></td></tr>";
	}


print "</table>\n";
#print "<p>$alignstring</p>\n";
print "</body>\n";
print "<html>\n";
exit;

# Hayes's changes Version 0.?, 08/06/02
#	- Added NCBI BLAST link
#	- changed column formating a bit

# Version 0.6, 07/04/2002
#	- properly copyrighted and GPLed;
# Version 0.5, 04/23/2002
#	- proper handling of html-encoding ($input =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;)
#	- proper dealing with "|" containing strings (if ($dbline =~ /^>\Q$locus\E[\s]/ || /^>\Q$locus\E/) {)
# Version 0.4, 03/25/2002
#	- fixed locus recognition in database: to "$locus[\s*]";
# Version 0.3, 03/22/2002
#	- script now more robust towards trailing spaces and other weiredness in databases
#	  ($alignstring =~ s/[^\w\*]//g;);
# Version 0.2, 02/17/2002
#	- sequence is now being displayed in blocks of 10 residues;
#	- "<HEAD><TITLE>" changed to "SeqCov: $locus";
#	- output now in table form;
#	- R/K residues now colored;
# Version 0.1, 02/13/2002
#	- basic bar positioning mechanism in place;
#	- output formating needs to be discussed with Dave;

