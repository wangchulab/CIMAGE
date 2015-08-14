#!/usr/local/bin/perl

#-------------------------------------
#	MuQuest
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#	11/08/01 - A. Chang/E. Perez: added FUZzy ions, ReTest output links
#-------------------------------------



################################################
# find and read in standard include file
{
	
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
	require "status_include.pl";
	require "html_include.pl";
}
################################################

# array for getting diff's from delta mass values
%diffList = (	
	0  => 'identical',
	14 => 'methylation',
	16 => 'oxidation',
	17 => 'pyroglutamate',
	42 => 'acetylation',
	57 => 'carboxyamidomethyl-',
	80 => 'phosphorylation',
	160 => 'phosphorylation (2)',
);

&cgi_receive;

&MS_pages_header("MuQuest", "#800080");  # former green: #3F9F5F
print "<HR>\n";

$DEFAULT_SHOW_MATCHES_GREATER_THAN = $DEFS_MUQUEST{"Muqest: Show Matches Greater Than"};
$MUQUEST_DEFAULT_SHOW_MATCHES_GREATER_THAN = $DEFS_MUQUEST{"Muqest: Show Matches Greater Than"};
$MASSDIFF_DEFAULT_SHOW_MATCHES_GREATER_THAN = $DEFS_MUQUEST{"MassDiff: Show Matches Greater Than"};
$COMPAREDTAS_DEFAULT_SHOW_MATCHES_GREATER_THAN = $DEFS_MUQUEST{"Compare DTAs: Show Matches Greater Than"};
$MUQUEST_MINXCORR = $DEFS_MUQUEST{"Muquest: Show Xcorr Greater Than"};
$MASSDIFF_MINXCORR = $DEFS_MUQUEST{"MassDiff: Show Xcorr Greater Than"};
$MUQUEST_MASSDIFF = $DEFS_MUQUEST{"Muquest maximum offset"};
$MASSDIFF_MASSDIFF = $DEFS_MUQUEST{"MassDiff default offset"};
$def_tolerance = $DEFS_MUQUEST{"Tolerance"};

$percent_to_highlight = 5;

# Used for DTA VCR
@dtavcr_links = ();
@dtavcr_infos = ();

# grab options
$mydtas = $FORM{'dtafile'};
$dir = $FORM{'directory'};
$tolerance = $FORM{'tolerance'} || $def_tolerance;
$compareAll = (defined $FORM{'compareAll'}) ? $FORM{'compareAll'} : 1;
$algorithm = $FORM{'algorithm'} || $muquest;
#$showNonZero = $FORM{'showNonZero'};														Sorry if this has some unintended consequences
$showNonZero = "true";
$greaterThan = defined $FORM{'greaterThan'} ?  $FORM{'greaterThan'} : $MUQUEST_DEFAULT_SHOW_MATCHES_GREATER_THAN;
$compareWith = $FORM{'compareWith'} || "all";
$otherdir = $FORM{'otherdir'} ;
$writePTAs = $FORM{"writePTAs"};
$sortby = $FORM{'sortby'};
$prevsortby = $FORM{'prevsortby'};
$dataname = $FORM{'dataname'};
$temp_file_index = $FORM{'tempfileindex'};
$xcorrCutoff = defined $FORM{'xcorrCutoff'} ? $FORM{'xcorrCutoff'} : $MUQUEST_MINXCORR;
$massDiff = $FORM{'massDiff'} || $MUQUEST_MASSDIFF;
$greaterThan = 0 if( $algorithm =~ /another/);
$alternateChargeStates = $FORM{'alternateChargeStates'};
if ($FORM{"spectrum_type"} eq "dtas"){
	delete $FORM{'sequences'};
	delete $FORM{'selected_sequences'};
}elsif ($FORM{"spectrum_type"} eq "selected_ion_ladders"){
	delete $FORM{'dtafile'};
	$FORM{'sequences'} = $FORM{'selected_sequences'};
	$FORM{'sequences'} =~ s/\,\s/\n/g;
}

$sequences = $FORM{'sequences'};
$sequences =~ s/\s+/\n/g;



# this is necessary if we're coming from Sequest
if ($FORM{'chosen'}) {
	my(@sel) =  split /,\s*/, $FORM{'chosen'};
	map {$_ = $_ . ".dta"} @sel;
	$mydtas = join ",", @sel;
} elsif($FORM{'selected'}){
	my(@sel) =  split /,\s*/, $FORM{'selected'};
	map {$_ = $_ . ".dta"} @sel;
	$mydtas = join ",", @sel;
}



@args = ();
push(@args, "-r") if ($FORM{"removePrec"});
push(@args, "-n") if ($FORM{"skipPreprocessing"});
push(@args, "-p") if ($FORM{"writePTAs"});
push(@args, "-o") if ($FORM{"zeroOffset"});
$args = join(" ",@args);
$cmdline = "$algorithm $args";
$cmdline = $compare_dtas if ($algorithm =~ /compare_dtas.exe$/i);



#debugging
#foreach  (keys %FORM) {
#	print "$_ $FORM{$_} <BR>";
#}
#die;


if (defined $FORM{"deletePTAs"}) {
	&delete_PTAs;
}

$otherdir = $dir unless ($compareWith eq "different");

if ((!defined $mydtas and !defined $sequences and !defined $sortby) or $FORM{"goto_dta_select_page"}){
	if (!defined $dir) {
		&output_form;
	} else {
		&getdta_form;
	}
}

if ((defined $mydtas or defined $sequences) && !defined $sortby) {

	&watch_over_me();						# run in a killable way
	# sort out whether we're using ionladders or dta files
	if($sequences){
		my(@seqs) = split /\n/, $sequences;
		foreach  (@seqs) {
			chomp;
			$_ =~ s/\s+//g;
		}
		@mydtas = &make_ladders(@seqs);
		@mydtas = map {"$tempdir/$_"} @mydtas;
	}else{
		@mydtas = split /,\s*/, $mydtas;
		@mydtas = map {"$seqdir/$dir/$_"} @mydtas;
	}

	if ($compareWith eq "selected") {
		@alldtas = @mydtas;
	} else {
		opendir(DIR,"$seqdir/$otherdir");
		@alldtas = grep /\.dta$/, readdir(DIR);
		closedir DIR;
		@alldtas = map {"$seqdir/$otherdir/$_"} @alldtas;

		#in the case where we made ionladders, we need to add them to the alldtas list
		push @alldtas, @mydtas if($sequences and $compareWith ne "different");
	}
	%PTA_written = ();
@rowdata = ();

$ii = 0;
print qq(<span id="progress">);
foreach $mydta (@mydtas) {


	my($print_dta_name) = $mydta;
	$print_dta_name =~ s/.*\///;
	$ii++;

	@rowdataBuffer = ();
	@dtavcr_linksBuffer = ();
	@dtavcr_infosBuffer = ();

	$mydta_display = $mydta;
	$mydta_display =~ s!.*\/!!;
	$muq_comp_for = "<a href=\"$fuzzyions?dtafile=$mydta\" target=\"blank\"><span style=\"color:#000000; font-weight:bold\">$mydta_display<\/span><\/a>";

	## (symbol ">>" indicates divider; used for sorting table)
	push @rowdataBuffer, ">>$muq_comp_for";

	# find mass and precursor of $mydta
	open (FILE, "$mydta");
	$mhplus_z = <FILE>;
	close FILE;
	chomp $mhplus_z;
	($mhplus, $z) = split (' ', $mhplus_z);
	$mass = &precision ($mhplus - $Mono_mass{"Hydrogen"}, 2, 4, " ");
	$prec = &precision ( (($mhplus - 1) / $z) + 1, 2, 4, " ");

	
	
	if ($compareWith eq "different") {
		$seq = "";
		($out = "$mydta") =~ s/\.dta$/\.out/;
		if (open(OUTFILE, "<$out")) {
			while (<OUTFILE>) {
				last if (($seq) = /^\s*1\.\s.*\s\(.\)(\S+)\s*$/);
				last if (($seq) = /^\s*1\.\s.*\s\S\.([^\s\.]+)\.\S\s*$/);
			}
			close OUTFILE;
		}
		$seq = qq(<a href="$showout?&OutFile=$out" target="_blank">$seq</a>);

		$shellCmd = "$cmdline $mydta $mydta";
		unless($algorithm =~ /compare_dtas/){
			if($massDiff >= 0){
				$shellCmd = $shellCmd . " $massDiff";
			}else{
				my($mymassdiff) = $massDiff * -1;
				$shellCmd = $shellCmd . " $mymassdiff";
			}
		}

		$XCorr{$mydta} = `$shellCmd`;

		if ($algorithm =~ /another/) {
			$shellCmd = "$cmdline -l $mydta $mydta";
			if($massDiff >= 0){
				$shellCmd = $shellCmd . " $massDiff";
			}else{
				my($mymassdiff) = $massDiff * -1;
				$shellCmd = $shellCmd . " $mymassdiff";
			}
			$XCorr_left{$mydta} = `$shellCmd`;
		}

		$maxXCorr = $XCorr{$mydta} > $XCorr_left{$mydta} ? $XCorr{$mydta} : $XCorr_left{$mydta};


		# include here for fuz (comparison of two dirs)- note this is for $dir not $otherdir - AARON

		($fuzout = "$mydta") =~ s/\.dta$/\.fuz.html/;

		if (-e $fuzout) {
			($fuzpath = "$mydta") =~ s/\.dta$/\.fuz.html/;
			$fuzpath =~ s/.*\://;												#change from directory name to url, erase C:
			$fuzcheck = qq(<a target="_blank" href="$fuzpath">+</a>);
		}
		else {
			$fuzcheck = "&nbsp;";
		}

		# add links to each DTA file for single re-processing of the DTA for header case (compare against own dir) - AARON
		%MYFORM=%FORM;
		delete($MYFORM{'selected'});			# in the event that we came from runsummary, there are a billion useless form elements that exhaust the space for the url in the retest link.
		$MYFORM{'otherdir'} = $dir;
		$MYFORM{'compareWith'} = "all";

		$ReTestPath = make_query_string(%MYFORM);

		$ReTestLink = qq(<a target="_blank" href="$ourname?$ReTestPath">Muquest</a>);
		

		# $asdf is a very clearly named variable that includes the gray header row values and links
		
		# very clear my foot!

		my($XCorr_display) = ($XCorr_left{$mydta} > $XCorr{$mydta} ? $XCorr_left{$mydta} : $XCorr{$mydta});
		$XCorr_display = "<b>$XCorr_display</b>";
		$blf = "";
		$asdf = join '::::', "header>$muq_comp_for","<b>$mass</b>","<b>$prec</b>",$blf,"<b>0.0</b>",$XCorr_display,"<b>100</b>","<b>0</b>",$blf,$blf,$seq,$fuzcheck,$ReTestLink;
		push @rowdataBuffer, $asdf;
	} else {
		$maxXCorr = 0;
	}

	@muquest_done = ();

	#### progress bar
	$progress = 0;
	$next_percent = 0.02;
	$max_progress = ($#alldtas);
	$ofof = $#mydtas + 1;

	my($progbar) = &create_progress_bar(incrementpercent => 2, description => "Progress on $print_dta_name \($ii of $ofof\):", id => "$ii");
	print $progbar->{bar};
	&kill_switch();

	foreach $dta (@alldtas) {
		$max_progress = 1 unless($max_progress);	# yes, this is a sad hack, but I don't want to spend more of my day on this bug
		#### progress bar
		$progress++;
		while (($progress / $max_progress) >= $next_percent) {
			$next_percent += 0.02;
			print $progbar->{inc};
		}
		####
		
		# find mass and precursor of $dta
		unless ($mass{$dta}) {
			open (FILE, "$dta");
			$mhplus_z = <FILE>;
			close FILE;
			chomp $mhplus_z;
			($mhplus, $z) = split (' ', $mhplus_z);
			$mass{$dta} = &precision ($mhplus - $Mono_mass{"Hydrogen"}, 2, 4, " ");
			$prec{$dta} = &precision ( (($mhplus - 1) / $z) + 1, 1, 4, " ");
		}

		$massmatchstring{$dta} = "";
		# we may need to see if the mass matches
		@testMasses = ();
		unless ($compareAll) {
			$massMatches = 0;
			if($algorithm =~ /another/){
				if( $alternateChargeStates){
					foreach(1..5){
						push @testMasses , ($massDiff / $_);
					}
					foreach (@testMasses) {
					   $massMatches = 1 if( (abs( abs($prec - $prec{$dta}) - $_) <= $tolerance) or (abs( abs($mass - $mass{$dta}) - $_) <= $tolerance));
					}
				} else{
					$massMatches = 1 if( (abs( abs($mass - $mass{$dta}) - $massDiff ) <= $tolerance) || (abs(  abs($prec - $prec{$dta}) - $massDiff  ) <= $tolerance) );
				}
			} else{
				$massMatches = 1 if ((abs($mass - $mass{$dta}) <= $tolerance) || (abs($prec - $prec{$dta}) <= $tolerance));
			}
		}
		
		# if called for, do muquest only if masses or precursors match
		if ( ($mydta eq $dta) || ($compareAll) || $massMatches){
			if ($cmdline eq $compare_dtas) {
				$XCorr{$dta} = `$compare_dtas Dta=$mydta  Dta=$dta`;
				chomp $XCorr{$dta};
				$XCorr{$dta} =~ s!^(\d+)% ions.*!$1!g;		# just the percentage (without %)
			} elsif($algorithm =~ /muquest/){

				my($result) = `$cmdline $mydta $dta $massDiff`;
				($XCorr{$dta},$skew{$dta}) = split / /, $result;

			} else {
				# algorithm == anotherquest

				# don't write the same PTA more than once:
				$cmd = $cmdline;
				if ($writePTAs) {
					if(0){
					#if ($PTA_written{$dta}) {
						$cmd =~ s/-p//;
					} else {
						$PTA_written{$dta} = 1;
						$PTA_written{$mydta} = 1;
					}
				}
				$shellCmd = "$cmd $mydta $dta";
				if($massDiff >= 0){
					$shellCmd = $shellCmd . " $massDiff";
				}else{
					$mymassdiff = -1 * $massDiff;
					$shellCmd = "$cmd $dta $mydta $mymassdiff";
				}
				$XCorr{$dta} = `$shellCmd`;
				$shellCmd = "$cmd -l $mydta $dta";
				if($algorithm =~ /another/){
					if($massDiff >= 0){
						$shellCmd = $shellCmd . " $massDiff";
					}else{
						$mymassdiff = -1 * $massDiff;
						$shellCmd = "$cmd -l $dta $mydta $mymassdiff";
					}
				}
				$XCorr_left{$dta} = `$shellCmd`;
				# Put the max of the left and right xcorr values into the XCorr hash, and use the other to calculate skew.
				my( $denom) = $XCorr_left{$dta} > $XCorr{$dta} ? $XCorr_left{$dta}  : $XCorr{$dta};
				$skew{$dta} = $denom == 0 ? 0 : (($XCorr{$dta} - $XCorr_left{$dta}) / $denom);
				$XCorr{$dta} = $XCorr_left{$dta} > $XCorr{$dta} ? $XCorr_left{$dta}  : $XCorr{$dta};
			}

			$maxXCorr = $XCorr{$dta} if ($XCorr{$dta} > $maxXCorr);

			push(@muquest_done,$dta);
		}
	}

	my($numHits) = $compareWith eq "different" ? 1 : 0;
	foreach $dta (@muquest_done) {
		$dta_name_display = $dta;
		$highlight = "no";	#can be changed by the maybe_highlight functions
		$dta_name_display =~ s!.*\/!!;
		$dta_to_display = ($dta eq $mydta) ? "header><span style=\"color:#000000; font-weight:bold\">$dta_name_display</span>" : $dta_name_display;
		$dta_to_display = qq(<a href="$fuzzyions?Dta=$dta" target="_blank">$dta_to_display</a>);
		$mass_to_display = (abs($mass{$dta} - $mass) <= $tolerance) ? "<b>$mass{$dta}</b>" : $mass{$dta};
		$prec_to_display = (abs($prec{$dta} - $prec) <= $tolerance) ? "<b>$prec{$dta}</b>" : $prec{$dta};
		$skew_to_display = (not ($algorithm =~ /another/)) ? &precision($skew{$dta}, 0) : &precision( $skew{$dta}, 2);
		$percent =  $maxXCorr ? int(($XCorr{$dta} / $maxXCorr) * 100) : 0;
		$delM = &precision($mass{$dta} - $mass,1);
		$skew_to_display = &maybe_highlight_skew($delM,$skew_to_display, \$highlight) unless ($algorithm =~ /another/);
		my($diff) = &get_diff($delM) unless ($dta eq $mydta);
		$delM = &maybe_highlight_delm($delM,$skew{$dta}, \$highlight);
		$delM = &link_delm($delM);
		
		if (($dta eq $mydta) || !$showNonZero || (($percent >= $greaterThan || $percent_left >= $greaterThan) and (($XCorr_left{$dta} >= $xcorrCutoff) || ($XCorr{$dta} >= $xcorrCutoff))) ) {
	
			$numHits++;
			$percent_to_display = ($percent >= $percent_to_highlight) ? "<b>$percent</b>" : "$percent";
			$percent_to_display = qq(<a href="$thumbnails?Dta=$mydta&Dta=$dta" target="_blank">$percent_to_display</a>);
			$XCorr_to_display = ($percent >= $percent_to_highlight) ? "<b>$XCorr{$dta}</b>" : "$XCorr{$dta}";

			push (@dtavcr_linksBuffer, "$thumbnails?Dta=$mydta&Dta=$dta");
			push (@dtavcr_infosBuffer, qq(<table cellspacing=0 cellpadding=0 border=0><tr><td align="center"><span class="smallheading">Dta 1</span></td><td align="center"><span class="smallheading">Dta 2</span></td><tr><td><span class="smalltext">&nbsp;$dir/$mydta&nbsp;</span></td><td><span class="smalltext">&nbsp;$otherdir/$dta&nbsp;</span></td></table>));
	
			($mydta_root = $mydta) =~ s/\.dta$//;
			($dta_root = $dta) =~ s/\.dta$//;
			$pta = "$dta_root.pta";
			$mypta = "$mydta_root.pta";
			$lpta = "$dta_root.$mydta_root.lpta";
			$mylpta = "$mydta_root.$dta_root.lpta";
			#$lpta = "$dta_root.lpta";
			#$mylpta = "$mydta_root.lpta";
	
			$PTADTAcompare = "";
			if (-e "$seqdir/$otherdir/$pta") {
				if (-e "$seqdir/$otherdir/$lpta") {
					$PTADTAcompare = qq(<a href="$thumbnails?Dta=$mydta&Dta=$dta&Dta=$seqdir/$otherdir/$pta&Dta=$seqdir/$otherdir/$lpta" target="_blank">DTA/DTA/PTA/LPTA</a>);
				} else {
					$PTADTAcompare = "<a href=\"$thumbnails?Dta=$dta&Dta=$seqdir/$otherdir/$pta\" target=\"_blank\">DTA/PTA</a>";
				}
			}
	
			$PTAcompare_temp = "";
			$PTAcompare_temp = qq(&nbsp;<a href="$thumbnails?Dta=$seqdir/$dir/$mylpta&Dta=$seqdir/$otherdir/$lpta" target="_blank">LPTAs</a>&nbsp;) if ((-e "$seqdir/$otherdir/$lpta") && (-e "$seqdir/$dir/$mylpta"));
			$PTAcompare_temp .= ((-e "$seqdir/$otherdir/$pta") && (-e "$seqdir/$dir/$mypta")) ? "&nbsp;<a href=\"$thumbnails?Dta=$seqdir/$dir/$mypta&Dta=$seqdir/$otherdir/$pta\" target=\"_blank\">PTAs</a>&nbsp;" : "";
			$PTAcompare = $PTAcompare_temp;
	
			# find top ranked sequence in OUT file if any
			unless ($seq{$dta}) {
				$seq = "";
				($out = "$dta") =~ s/\.dta$/\.out/;
				if (open(OUTFILE, "<$out")) {
					while (<OUTFILE>) {
						last if (($seq) = /^\s*1\.\s.*\s\(.\)(\S+)\s*$/);
						last if (($seq) = /^\s*1\.\s.*\s\S\.([^\s\.]+)\.\S\s*$/); #wsl changed s*2 in this line to s*1. he doesn't know whether this is right.
						last if (($seq) = /^\s*1\.\s.*\s\S\.(\S+)\.\S{0,1}\s*$/); # I don't see why the ([^\s\.]+) in the line above. Perhaps that line should be erased. For now, the only reported bug is having $seq undefined when it should have a value, so there is nothing to incrimenate the above line
					}
					close OUTFILE;
				}
				$seq = qq(<a href="$showout?&OutFile=$out" target="_blank">$seq</a>) if ($seq);
				$seq{$dta} = $seq;
			}

			$prec_to_display =~ s/^ //;
			$mass_to_display =~ s/ //;

			$trsequence = $seq{$dta};

			# check to see if fuz.html file exists for the current DTA, if so, have it appear on the table - AARON

			($fuzout = "$dta") =~ s/\.dta$/\.fuz.html/;

			if (-e $fuzout) {
				($fuzpath = "$dta") =~ s/\.dta$/\.fuz.html/;
				$fuzpath =~ s/.*\://;												#change from directory name to url, erase C:
				$fuzcheck = qq( <a target="_blank" href="$fuzpath">+</a>);
			}
			else {
				$fuzcheck = "&nbsp;";
			}


			# reset form values for current dta and directory for each dta's ReTest link for non-header case - AARON
			# compare against comparison "otherdir" directory in this case

			%MYFORM = %FORM;
			delete($MYFORM{'selected'});			# in the event that we came from runsummary, there are a billion useless form elements that exhaust the space for the url in the retest link.
			my($sscanNo,$dta_name);
			$dta =~ /\.(\d\d\d\d)\./;
			$sscanNo = $1;
			if($sscanNo ne "0000"){
				$MYFORM{'spectrum_type'} = "dtas";
				$dta_name = $dta;
				$dta_name =~ s!.*\/!!;
			}else{
				$MYFORM{'spectrum_type'} = "ion_ladders";
				$dta =~ /.*\/([A-Za-z]+)\./;
				$MYFORM{'sequences'} = $1;
			}
			$MYFORM{'dtafile'} = $dta_name;
			$MYFORM{'directory'} = $otherdir;
			$MYFORM{'compareWith'} = "all";

			# add links to each DTA file for single re-processing of the DTA, spawn new window - AARON

			$ReTestPath = make_query_string(%MYFORM);
			$ReTestLink = qq(<a target="_blank" href="$ourname?$ReTestPath">Muquest</a>);


			# current list of column elements to print out row by row - AARON

			$currentrow = join '::::', $dta_to_display,$mass_to_display,$prec_to_display,$diff,$delM,$XCorr_to_display,$percent_to_display,$skew_to_display,$PTAcompare,$PTADTAcompare,$trsequence, $fuzcheck, $ReTestLink;

			#add highlight tag
			$currentrow .= "??";
			$currentrow .= $highlight;

			push @rowdataBuffer, $currentrow;

		}
	}
#exit;
	push @rowdata, @rowdataBuffer;
	push @dtavcr_links, @dtavcr_linksBuffer;
	push @dtavcr_infos, @dtavcr_infosBuffer;
}

print "<span class=smallheading><br>Preparing table...</span></span>\n\n";

#### save @rowdata, @dtavcr_links, @dtavcr_infos to temp file
$temp_file_index = time;
$temp_file = "$tempdir/muquest-$dir-$temp_file_index.txt";
open(SAVETO, ">$temp_file");
foreach $line (@rowdata) {
	print SAVETO "rows-$line\n";
}
foreach $line (@dtavcr_links) {
	print SAVETO "links-$line\n";
}
foreach $line (@dtavcr_infos) {
	print SAVETO "infos-$line\n";
}
close(SAVETO);
####
	&create_output_header;
} else {
	&create_output_header;
	goto SORT_AND_MAKE_TABLE;
}

sub create_output_header {

	my($alg_to_display) = $algorithm;
	$alg_to_display =~ s/\.exe$//;
	$alg_to_display =~ s/.*\///g;
	$alg_to_display = ucfirst($alg_to_display);

	if ($compareAll == 1) {
		$nonechecked = "checked";
	}
	else {
		$otherchecked = "checked";
	}
	if ($algorithm eq "$cgidir/muquest.exe") {
		$muquestalg = "checked";
	}
	elsif ($algorithm eq "$cgidir/compare_dtas.exe") {
	    $compare_dtasalg = "checked";
	}
	else {
		$anotheralg = "checked";
	}
	if ($alternateChargeStates eq "true") {
		$alterchecked = "checked";
	}
	&get_alldirs;

print <<EOF;

<table cellspacing=0 cellpadding=0 border=0 id="output_header" style="display:none">
<FORM NAME="muquest" ACTION="$ourname" METHOD="post">
<input type="hidden" name="directory" value="$dir">
<input type="hidden" name="dtafile" value="$mydtas">
<input type="hidden" name="compareWith" value="different">
	<tr><td valign=top>
	<table cellspacing=0 cellpadding=0 border=0>
	<tr height=20><td bgcolor="e8e8fa" colspan=3><span class="smallheading">&nbsp;&nbsp;Directory:&nbsp;&nbsp;</span><span class="smalltext"><a href="$webcgi/runsummary.pl?directory=$dir&sort=consensus">$fancyname{$dir}</a></span></td>
	<tr height=25><td class="smallheading" bgcolor="e8e8fa" colspan=3>&nbsp;&nbsp;Comparison Directory:</td></tr>
	<tr height=35><td valign=top bgcolor="e8e8fa" colspan=3>
	&nbsp;&nbsp;<span class=dropbox><SELECT name=\"otherdir\">
EOF
  foreach $compdir (@ordered_names) {
    $selected = ($otherdir eq $compdir) ? " selected" : "";
    print qq(<option value="$compdir"$selected>$fancyname{$compdir}\n);
  }
 print <<EOF;
   </select></span>&nbsp;&nbsp;</td></tr>

   <tr height=25><td valign=bottom align=right width=55%><input type="submit" class="outlinebutton button" value="Compare"></td>
				 <td align=center width=25%><span class=smallheading style="cursor:hand; color:#0000cc" id="help" onmouseover="this.style.color='red';return true;" onmouseout="this.style.color='#0000cc';return true;" onclick="window.open('$webhelpdir/help_$ourshortname.html', '_blank')">Help</span</td>
				 <td width=20%>&nbsp;</td></tr> 
   </table></td>
  <td width=30>&nbsp;</td>
  <td valign=top><table cellspacing=0 cellpadding=0 border=0>
		<tr>
			<td height=20 align=right bgcolor=e8e8fa class="smallheading">Mass tolerance:&nbsp;&nbsp;</td>
			<td height=20 class="smalltext" bgcolor=f2f2f2 ><input type=radio name="compareAll" value="1" $nonechecked>None</td>
			<td height=20 class="smalltext" bgcolor=f2f2f2 colspan=2><input type=radio name="compareAll" value="0" $otherchecked><input name="tolerance" value="$tolerance" size=3 class="smalltext">&nbsp;Da</td>
		</tr>
		<tr>
			<td height=20 align=right bgcolor=e8e8fa class="smallheading">Algorithm:&nbsp;&nbsp;</td>
			<td height=20 class="smalltext" bgcolor=f2f2f2 ><input type=radio name="algorithm" value="$cgidir/muquest.exe" onClick="document.forms[0].greaterThan.value = $MUQUEST_DEFAULT_SHOW_MATCHES_GREATER_THAN; document.forms[0].xcorrCutoff.value = $MUQUEST_MINXCORR; document.forms[0].massDiff.value = $MUQUEST_MASSDIFF" $muquestalg>MuQuest&nbsp;&nbsp;</td>
			<td height=20 class="smalltext" bgcolor=f2f2f2 ><input type=radio name="algorithm" value="$cgidir/compare_dtas.exe" onClick="document.forms[0].greaterThan.value = $COMPAREDTAS_DEFAULT_SHOW_MATCHES_GREATER_THAN" $compare_dtasalg>CompareDTAs&nbsp;</td>
			<td height=20 class="smalltext" bgcolor=f2f2f2><input type=radio name="algorithm" value="$cgidir/anotherquest.exe" onClick="document.forms[0].greaterThan.value = $MASSDIFF_DEFAULT_SHOW_MATCHES_GREATER_THAN; document.forms[0].xcorrCutoff.value = $MASSDIFF_MINXCORR; document.forms[0].massDiff.value = $MASSDIFF_MASSDIFF" $anotheralg>MassDiff&nbsp;&nbsp;</td>
		</tr>
		<tr>
			<td height=20 align=right bgcolor=e8e8fa class="smallheading">Show matches:&nbsp;&nbsp;</td>
			<td height=20 class="smalltext" bgcolor=f2f2f2>&nbsp;>=&nbsp;<input type=hidden name="showNonZero" value="true"><input name="greaterThan" value=$greaterThan class="smalltext" size=2 maxlength=2>%</td>
			<td height=20 class="smalltext" bgcolor=f2f2f2 colspan=2>&nbsp;Xcorr >=&nbsp;<input name="xcorrCutoff" value=$xcorrCutoff size=3 maxlength=3 class="smalltext"></td>
		</tr>
		<tr>
			<td height=20 align=right bgcolor=e8e8fa class="smallheading">Mass Difference:&nbsp;&nbsp;</td>
			<td height=20 bgcolor=f2f2f2 class="smalltext"><input name="massDiff" value=$massDiff size=3 maxlength=5 class="smalltext"></td>
			<td height=20  bgcolor=f2f2f2 colspan=2><span class="smallheading">Alt Chg States:</span>		
			<input type=checkbox name="alternateChargeStates" value="true" $alterchecked></td>
		</tr>
		<tr height=25><td colspan=4 align=center><span class=smallheading id="firstToggle" act="expandall" style="cursor:hand; color:#0000cc" onmouseover="this.style.color='red';return true;" onmouseout="this.style.color='#0000cc';return true;" onclick="toggleAll(this);">Show All Matches</span>
				<span class=smallheading id="secondToggle" act="contractall" style="cursor:hand; color:#0000cc; display:none" onmouseover="this.style.color='red';return true;" onmouseout="this.style.color='#0000cc';return true;" onclick="toggleAll(this);">Show Good Matches</span>
				<input type="hidden" name="show" value="contractall">
					&nbsp;&nbsp;&nbsp;<span class=smallheading style="cursor:hand; color:#0000cc" onmouseover="this.style.color='red';return true;" onmouseout="this.style.color='#0000cc';return true;" onclick="javascript:openDTA_VCR();">DTA VCR</span></td> 
	   </tr>
			</table>
	 </td>
</tr></form></table><p>
EOF
&load_java_toggle_progress;
}

SORT_AND_MAKE_TABLE: {
	if (defined $sortby) {
		# read from temp file
		$temp_file = "$tempdir/muquest-$dir-$temp_file_index.txt";
		open(READFROM, "$temp_file") or &could_not_open;
		@tempfiledata = <READFROM>;
		close(READFROM);

		# recreate appropriate variables from @tempfiledata
		@rowdata = grep { s/^rows-// } @tempfiledata;
		@dtavcr_links = grep { s/^links-// } @tempfiledata;
		@dtavcr_infos = grep { s/^infos-// } @tempfiledata;

		# sort forward or reverse? -- used in &sort_rowinfo
		$sortorder = 0;
		if ($sortby == $prevsortby) {
			$sortorder = 1;
		}
	} else {
		# this is the default column by which to sort:
		$sortby = 5;
		# default sort order is biggest to smallest:
		$sortorder = 0;
	}
	


	#### sort everything BETWEEN individual dta dividers, add results to @rowoutput :
	## (symbol ">>" indicates section divider, "header>" indicates which line is the header to be included in final table)
	@rowinfo = ();
	foreach $row (@rowdata) {
		if ($row =~ />>/) {
			push @rowoutput, $currentheader;
			sort_rowinfo($sortby,$sortorder,\@rowinfo);
			push @rowoutput, @rowinfo;
			@rowinfo = ();
		} else {
			if ($row =~ /header>/) {
				$currentheader = $row;
			} else {
				push @rowinfo, $row;
			}
		}
	}
	#### then, sort and add remaining (from the part of table below the last division) @rowinfo to @rowoutput :
	push @rowoutput, $currentheader;
	sort_rowinfo($sortby,$sortorder,\@rowinfo);
	push @rowoutput, @rowinfo;
	####
		

	# send sorted data to function to print out the large table 

	$totaloutput = &create_table_from_rowoutput(\@rowoutput);

	if ($sortorder == 1) {
		$sortby = -1;
	}

	# modified the table headings for fuz and retest - AARON

	print <<EOF;
<script language="Javascript">
	var expandAndContract = 0;

	function toggleAll(buttonPressed)
	{
		var buttonFirst = document.getElementById("firstToggle");
		var buttonSecond = document.getElementById("secondToggle");

		for (var i = 0; i < expandAndContract; i++) {
			var groupSpanId = "expandAndContract_" + i;
			var groupSpan = document.getElementById(groupSpanId);
		
			if (buttonPressed.act=="contractall") {
				groupSpan.style.display = "none";
			} else {
				groupSpan.style.display = "";
			}
		}

		if (buttonPressed.act=="contractall") {
			buttonSecond.style.display = "none";
			buttonFirst.style.display = "";
		} else {
			buttonSecond.style.display = "";
			buttonFirst.style.display = "none";
		}
	}		

	function sortBy(type) {
	   document.sort.sortby.value=type;
	   document.sort.submit();
	}
</script>
<table border=0 cellspacing=0 cellpadding=0>
<tr>	
	<td align=center id="dtaname" style="cursor:hand;border-width:1px 1px 1px 1px;border-style:solid;border-color:#b0c4de" onclick="sortBy(0);" onmouseover="this.bgColor='#ffff99';window.status='Sort by DTA filename';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>DTA to compare</span></td>
	<td align=center id="mass" style="cursor:hand;border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de" onclick="sortBy(1);" onmouseover="this.bgColor='#ffff99';window.status='Sort by Mass';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>Mass</span></td>
	<td align=center id="precursor" style="cursor:hand;border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de" onclick="sortBy(2);" onmouseover="this.bgColor='#ffff99';window.status='Sort by  precursor';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>Precursor</span></td>
	<td align=center id="diff" style="cursor:hand;border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de" onclick="sortBy(3);" onmouseover="this.bgColor='#ffff99';window.status='Sort by predicted diff';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>Diff Predicted</span></td>
	<td align=center id="delM" style="cursor:hand;border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de" onclick="sortBy(4);" onmouseover="this.bgColor='#ffff99';window.status='Sort by delta Mass';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>delM</span></td>
	<td align=center id="xcorrL" style="cursor:hand;border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de" onclick="sortBy(5);" onmouseover="this.bgColor='#ffff99';window.status='Sort by Xcorr';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>XCorr</span></td>
	<td align=center id="percentmax" style="cursor:hand;border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de" onclick="sortBy(6);" onmouseover="this.bgColor='#ffff99';window.status='Sort by \%max';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>\%max</span></td>
	<td align=center id="average" style="cursor:hand;border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de"  onclick="sortBy(7);" onmouseover="this.bgColor='#ffff99';window.status='Sort by offset';this.style.color='#000000';return true;" 
	onmouseout="this.bgColor='#ffffff';window.status='';return true;"; this.style.color='#ffffff';"><span class=smallheading>offset</span></td>
	<td style='border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de'>&nbsp;</td>
	<td style='border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de'>&nbsp;</td>
	<td align="center" style='border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de'><span class="smallheading">Top-ranked Sequence</span></td>
	<td align="center" style='border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de'><span class="smallheading">Fuz</span></td>
	<td align="center" style='border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de'><span class="smallheading">Retest</span></td>
</tr>
$totaloutput
</table>
<FORM NAME="sort" ACTION="$ourname" METHOD="post">
	<input type="hidden" name="dtafile" value="$mydtas">
	<input type="hidden" name="prevsortby" value="$sortby">
	<input type="hidden" name="dataname" value="$datafilename">
	<input type="hidden" name="tempfileindex" value="$temp_file_index">
	<input type="hidden" name="otherdir" value="$otherdir">
	<input type="hidden" name="directory" value="$dir">
	<input type="hidden" name="compareWith" value="$compareWith">
	<input type="hidden" name="compareAll" value="$compareAll">
	<input type="hidden" name="tolerance" value="$tolerance">
	<input type="hidden" name="algorithm" value="$algorithm">
	<input type="hidden" name="greaterThan" value="$greaterThan">
	<input type="hidden" name="xcorrCutoff" value="$xcorrCutoff">
	<input type="hidden" name="massDiff" value="$massDiff">
	<input type="hidden" name="alternateChargeStates" value="$alternateChargeStates">
	<input type="hidden" name="sortby">
</form>
EOF
}

opendir(DIR, "$seqdir/$dir");
$numPTAs = grep /\.l?pta$/, readdir(DIR);
closedir(DIR);
if ($otherdir ne $dir) {
	opendir(DIR, "$seqdir/$otherdir");
	$numPTAs += grep /\.l?pta$/, readdir(DIR);
	closedir(DIR);
}
print qq(<FORM NAME="delptas" ACTION="$ourname" METHOD="get">);
if ($numPTAs) {
	print <<EOF;
<INPUT TYPE=hidden NAME="directory" VALUE="$dir">
<INPUT TYPE=hidden NAME="otherdir" VALUE="$otherdir">
<INPUT TYPE=hidden NAME="deletePTAs" VALUE="true">
<span class="smallheading">These directories contain a total of $numPTAs PTA and/or LPTA files.&nbsp;&nbsp;To delete these, click <a href="javascript:document.delptas.submit()">here</a>.
<!--<INPUT TYPE=submit class=button NAME="deletePTAs" VALUE="Delete All PTAs/LPTAs">-->
</span>
EOF
}

# Load DTA VCR code
&dta_vcr_code;

print <<EOF;
<input type=hidden name="DTAVCR:conserve_space" value="1">
</FORM>
<!--
<br><br>
<span class="smallheading">Command line:&nbsp;</span><tt>$cmdline</tt>
-->
</body></html>
EOF

exit;











#########################################


sub output_form {

  print qq(<div><FORM ACTION="$ourname" METHOD=post>);

  &get_alldirs;
  print "<span class=\"smallheading\">Pick a directory:</span><br>\n";
  print "<span class=dropbox><SELECT name=\"directory\">\n";
  
  foreach $dir (@ordered_names) {
    print qq(<option value="$dir">$fancyname{$dir}\n);
  }
  print "</select></span>\n";
  print qq(<input type="submit" class=button value="Continue">&nbsp;);
  print qq(&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<span class="smallheading"><a href="$webhelpdir/help_$ourshortname.html">Help</a></span>\n);

  # if we arrived at this page from an outside source, there may be other form inputs to pass on 
  foreach  (keys %FORM) {
	  print qq(<input type=hidden name="$_" value="$FORM{$_}">\n);
  }

  print "</form></div></body></html>\n";

  exit;

}

#########################################


sub getdta_form {

  opendir(DIR,"$seqdir/$dir") || &error("Cannot access directory $dir.");
  @dtas = grep /\.dta$/, readdir(DIR);
  closedir DIR;

  # get some defaults lined up
  if($sequences){
		$checked_select_sequences = "checked";
		$checked_otherdir = "checked";
		$seq_box_display = "none";
		$seq_select_display = "";
		$dta_box_display = "none";
  }else{
		$checked_dtas = "checked";
		$checked_thisdir = "checked";
		$seq_box_display = "none";
		$seq_select_display = "none";
		$dta_box_display = "";
  }

  print <<EOF;

<script language="Javascript">
<!--
	var i;

	function SelectAll() {
		for (i = 0; i < document.forms[0].dtafile.options.length; i++)
			document.forms[0].dtafile.options[i].selected = true;
			document.all.selectedfiles.innerText = document.forms[0].dtafile.options.length;
	}
	function SelectNone() {
		for (i = 0; i < document.forms[0].dtafile.options.length; i++)
			document.forms[0].dtafile.options[i].selected = false;
			document.all.selectedfiles.innerText = 0;
	}

	function CountSelected() {
		var numberselected = 0;
		for (i = 0; i < document.forms[0].dtafile.options.length; i++) {
			if (document.forms[0].dtafile.options[i].selected == true) {
				numberselected++;
			}
		}
		document.all.selectedfiles.innerText = numberselected;
	}
	
	function SelectAllSeqs() {
		for (i = 0; i < document.forms[0].selected_sequences.options.length; i++)
			document.forms[0].selected_sequences.options[i].selected = true;
			document.all.selectedfiles.innerText = document.forms[0].selected_sequences.options.length;
	}
	function SelectNoSeqs() {
		for (i = 0; i < document.forms[0].selected_sequences.options.length; i++)
			document.forms[0].selected_sequences.options[i].selected = false;
			document.all.selectedfiles.innerText = 0;
	}

	function CountSelectedSeqs() {
		var numberselected = 0;
		for (i = 0; i < document.forms[0].selected_sequences.options.length; i++) {
			if (document.forms[0].selected_sequences.options[i].selected == true) {
				numberselected++;
			}
		}
		document.all.selectedfiles.innerText = numberselected;
	}

	function ClickHandle() {
		if (document.forms[0].skip.checked == false) {
			document.forms[0].removePrec.disabled = false;
			document.forms[0].writePTAs.disabled = false;
		} else {
			document.forms[0].removePrec.disabled = true;
			document.forms[0].writePTAs.disabled = true;
		}
	}
	function DisableChkBoxes() {
		document.forms[0].removePrec.disabled = true;
		document.forms[0].writePTAs.disabled = true;
	}
	function EnableChkBoxes() {
		document.forms[0].removePrec.disabled = false;
		document.forms[0].writePTAs.disabled = false;
	}
	function recreatepage() {
		CountSelected();
		ClickHandle();
	}
	
//-->
</script>

<div>
EOF
&print_sample_name ($dir);

  print qq(&nbsp;&nbsp;&nbsp;&nbsp;<span class="smallheading"><a href="$viewheader?directory=$dir" target="_blank">View Info</a></span>);
  print qq(<FORM ACTION="$ourname" METHOD=post>);

  opendir(DIR,"$seqdir/$dir") || &error("Cannot access directory $dir.");
  @dtas = grep /\.dta$/, readdir(DIR);
  closedir DIR;

  opendir(DIR,"$cgidir") || &error("Cannot access directory $cgidir");
  @algorithms = grep /^muquest.*\.exe$/, readdir(DIR);
  closedir DIR;
  push(@algorithms,"compare_dtas.exe");

  print <<EOF;

<script language="javascript">
<!--
onload = recreatepage;
//-->
</script>

<table border=0 cellspacing=0 cellpadding=0>
<tr>
<td valign=top>
	<table border=0 cellspacing=0 cellpadding=5 height=100%>
	<tr>
		<td valign=top align=center bgcolor="#c0c0c0">
			&nbsp;<image src="$webimagedir/circle_1.gif">&nbsp;</td>
		<td bgcolor="#E2E2E2" valign=top>
			<span id="dta_selection" style="display:$dta_box_display">
				<span class="smallheading">Pick one or more spectra (dtafiles):</span><br>
				<INPUT TYPE=hidden NAME="directory" VALUE="$dir">
				<span class=dropbox><SELECT name="dtafile" size=16 multiple onBlur="CountSelected()" onClick="this.blur(); this.focus()" onKeyUp="CountSelected()">  <!-- Probably not very efficient -->
			
EOF
					  foreach $dta (@dtas) {
						print "<option>$dta";
					  }
					  print <<EOF;
				</select></span>
				<br><span class="smallheading">Select: </span>
				<input type=button class=button value=" All " onClick="SelectAll()">&nbsp;
				<input type=button class=button value="None" onClick="SelectNone()"><BR>
			</span>
			<span id="enter_sequences" style="display:$seq_box_display">
				<span class="smallheading">Enter one or more sequences:</span><br>
				<TEXTAREA name="sequences" rows=16 cols=22 wrap=off>$sequences</TEXTAREA>
			</span>
			<span id="select_sequences" style="display:$seq_select_display">
				<span class="smallheading">Select one or more sequences:</span><br>
				<span class=dropbox><SELECT name="selected_sequences" size=16 multiple  onBlur="CountSelectedSeqs()" onClick="this.blur(); this.focus()" onKeyUp="CountSelectedSeqs()">
EOF
				  foreach (split /\n/, $sequences) {
					print "<option>$_";
				  }
				  print <<EOF;
				</select></span>
				<br><span class="smallheading">Select: </span>
				<input type=button class=button value=" All " onClick="SelectAllSeqs()">&nbsp;
				<input type=button class=button value="None" onClick="SelectNoSeqs()"><BR>
			</span>
	</td></tr></table>
	<br><span class="smallheading">Select:&nbsp;<input type=radio name="spectrum_type" value="dtas" onclick="window.document.all['dta_selection'].style.display='';window.document.all['select_sequences'].style.display='none';window.document.all['enter_sequences'].style.display='none';CountSelected()" $checked_dtas>Dtas&nbsp;
			<input type=radio name="spectrum_type" value="selected_ion_ladders" onClick="window.document.all['dta_selection'].style.display='none';window.document.all['select_sequences'].style.display='';window.document.all['enter_sequences'].style.display='none';CountSelectedSeqs();" $checked_select_sequences>Seqs
			<input type=radio name="spectrum_type" value="ion_ladders" onClick="window.document.all['dta_selection'].style.display='none';window.document.all['select_sequences'].style.display='none';window.document.all['enter_sequences'].style.display='';" $checked_enter_sequences>Entered Seqs

</td>
<td width=50></td>
<td valign=top>
	<table border=0 cellspacing=0 cellpadding=5>
	<tr>
		<td valign=top align=center bgcolor="#c0c0c0">
			&nbsp;<image src="$webimagedir/circle_2.gif">&nbsp;
		</td>
		<td bgcolor="#E2E2E2">
			&nbsp;<b><span style="color:#FF0000" id="selectedfiles">0</span></b>&nbsp;<span class="smallheading" id="numsel">Spectra selected.
			Compare each of these with:</span><br>
			<input type=radio name="compareWith" value="all" $checked_thisdir>All spectra in same directory<br>
			<input type=radio name="compareWith" value="selected">Selected spectra in same directory<br>
			<input type=radio name="compareWith" value="different" $checked_otherdir>All spectra in the following directory:<br>&nbsp;&nbsp;&nbsp;
EOF
  &get_alldirs;

  print "<span class=dropbox><SELECT name=\"otherdir\">\n";
  foreach $otherdir (@ordered_names) {
    $selected = ($otherdir eq $dir) ? " selected" : "";
    print qq(<option value="$otherdir"$selected>$fancyname{$otherdir}\n);
  }
  print "</select></span>\n";
  print <<EOF;
		</td>
	</tr>
	<tr>
		<td height=45>&nbsp;</td><td></td>
	</tr>

	<tr>
		<td valign=top align=center bgcolor="#c0c0c0">
			&nbsp;<image src="$webimagedir/circle_3.gif">&nbsp;
		</td>
		<td bgcolor="#E2E2E2">
			<table border=0 cellspacing=0 cellpadding=0>
				<tr>
					<td><span class="smallheading">Mass tolerance:</span>&nbsp;&nbsp;</td>
					<td><input type=radio name="compareAll" value="1" checked>None</td>
					<td><input type=radio name="compareAll" value="0"><input name="tolerance" value="$def_tolerance" size=3>&nbsp;Da</td>
				</tr><tr><td height=5></td></tr><tr>
					<td><span class="smallheading">Algorithm:</span></td>
					<td><input type=radio name="algorithm" value="$cgidir/muquest.exe" onClick="document.forms[0].greaterThan.value = $MUQUEST_DEFAULT_SHOW_MATCHES_GREATER_THAN; document.forms[0].xcorrCutoff.value = $MUQUEST_MINXCORR; document.forms[0].massDiff.value = $MUQUEST_MASSDIFF" checked>MuQuest&nbsp;&nbsp;</td>
					<td><input type=radio name="algorithm" value="$cgidir/compare_dtas.exe" onClick="document.forms[0].greaterThan.value = $COMPAREDTAS_DEFAULT_SHOW_MATCHES_GREATER_THAN">CompareDTAs&nbsp;</td>
					<td><input type=radio name="algorithm" value="$cgidir/anotherquest.exe" onClick="document.forms[0].greaterThan.value = $MASSDIFF_DEFAULT_SHOW_MATCHES_GREATER_THAN; document.forms[0].xcorrCutoff.value = $MASSDIFF_MINXCORR; document.forms[0].massDiff.value = $MASSDIFF_MASSDIFF">MassDiff&nbsp;&nbsp;</td>
				</tr><tr><td height=5></td></tr><tr>
					<td><span class="smallheading">Show matches:</span></td>
					<td>&nbsp;>=&nbsp;<input type=hidden name="showNonZero" value="true"><input name="greaterThan" value=$DEFAULT_SHOW_MATCHES_GREATER_THAN size=2 maxlength=2>%</td>
					<td>&nbsp;Xcorr >=&nbsp;<input name="xcorrCutoff" value=$MUQUEST_MINXCORR size=3 maxlength=3></td>
				</tr>
				</tr><tr><td height=5></td></tr><tr>
					<td><span class="smallheading">Mass Difference:</span></td>
					<td><input name="massDiff" value=$MUQUEST_MASSDIFF size=3 maxlength=5></td>
					<td><span class="smallheading">Alt Chg States:</span>
					<input type=checkbox name="alternateChargeStates" value="true"></td>
				</tr>
			</table>
			<input type=hidden name="showNonZero" value="true">
		</td>
	</tr>
	<tr>
		<td height=35>&nbsp;</td><td></td>
	</tr>
	<tr><td></td>
		<td>
			<input type="submit" class=button value="Compare">&nbsp;&nbsp;
			<span class="smallheading"><a href="$webhelpdir/help_$ourshortname.html">Help</a></span>
		</td>
	</tr>
	</table>



</td></tr></table>
<br>
<hr><br>
<table border=0 cellspacing=0 cellpadding=5>
<tr>
	<td valign=top>
		<span class="smallheading">Advanced options:</span><br>
	</td>
	<td bgcolor="#E2E2E2">
		<span class=smalltext>
		<input type=checkbox name="skipPreprocessing" value=1 onClick="ClickHandle()" id=skip>Skip DTA preprocessing? (-n)<br>
		<input type=checkbox name="removePrec" value=1 id=removePrec>Remove precursor? (-r) (only relevant if <i>skip preprocessing</i> is unchecked)<br>
		<input type=checkbox name="writePTAs" value=1 id=writePTAs>Write PTA files? (-p) (only relevant if <i>skip preprocessing</i> is unchecked)<br>
		<input type=checkbox name="zeroOffset" value=1 id=writePTAs onClick="document.forms[0].massDiff.value = 0">Zero offSet only (-o) (only applicable to MuQuest)<br>
		</span>
	</td>
</tr></table>

</form></div>
</body></html>
EOF

  exit;

}

###########################################################
# Subroutines

sub sort_rowinfo {
	# column to sort by:
	$cts = $_[0];
	# sort order: ( 1 = small to big, 0 = big to small)
	$sortorder = $_[1];
	# do the sort:
	@rowinfo = sort {
					$mya = $a;
					$myb = $b;
					@newa = split /::::/, $mya;
					@newb = split /::::/, $myb;
					$mya = $newa[$cts];
					$myb = $newb[$cts];
					$mya =~ s/<[^>]+>//g;
					$myb =~ s/<[^>]+>//g;
					if ($cts == 0) {
						# string sort
						if ($sortorder == 1) {
							$mya cmp $myb;
						} else {
							$myb cmp $mya;
						}
					} else {
						# numerical sort
						if ($sortorder == 1) {
							$mya <=> $myb;
						} else {
							$myb <=> $mya;
						}
					}

					} @rowinfo;
}

sub create_table_from_rowoutput {
	# creates table content, not including outside <table> tags
	$thetable = "";
	my $expandandcontract = 0;
	my $whiterows = 0;
	my $firstheader = "yes";
	foreach $rowdata (@rowoutput) {
		my $header = "no";
		if ($rowdata =~ /header>/) {
			$rowdata =~ s/header>//;
			$header = "yes";
			if ($whiterows != 0) {
				$thetable .= "</tbody>";
				$whiterows = 0;
			}	
			if ($firstheader ne "yes") {
				$thetable .= "<tr height=12><td colspan=13 >&nbsp;</td></tr>";
			}
			$firstheader = "no";
			# R. Dezube took this out from the beginning of next line: <tr><td colspan=12><br><\/td><\/tr> (created blank line)
			$thetable .= "<tr bgcolor=#e8e8fa height=25>";
			if ($rowdata =~ /::::/) {
				# next two lines added by R. Dezube 5/14/02 to fix ??yes in output
				@celldata = split/\?\?/, $rowdata;
				$rowdata = @celldata[0];
				goto MAKE_CELLS;
			} else {
				# (this case happens when comparing with other directories)
				$thetable .= "<td align=left colspan=12 nowrap style='border-width:0px 1px 1px 1px;border-style:solid;border-color:#b0c4de'><span class=smalltext>&nbsp;&nbsp;$rowdata<\/span><\/td><\/tr>";
				next;
			}
	
	#$thetable .= "<\/tr>";
		} else{
			# parse out the highlight tag and adjust background accordingly
			@celldata = split /\?\?/, $rowdata;
			$rowdata = @celldata[0];
			$highlight = @celldata[1];
			$highlight =~ s/^\s*(\S+)\s*$/$1/;	
			if ($highlight eq "yes") {	
				# highlighting color (currently yellow, changed by R. Dezube 5/14/02)
				if ($whiterows != 0) {
					$whiterows = 0;
					$thetable .= "</tbody>";
				}
				$thetable .= "<tr bgcolor=#ffff99>";
			} else {
				if (($whiterows == 0) &&($firstheader ne "yes")) {
					$thetable .= "<script language='Javascript'>expandAndContract++;</script>";
					$thetable .= "<tbody id=expandAndContract_$expandandcontract style=display:none>";
					$expandandcontract++;						
				}
				$thetable .= "<tr>";
				$whiterows++;
			}
			goto MAKE_CELLS;
						
	#		$thetable .= "<\/tr>"; 
		}
		MAKE_CELLS: {
			@cells = split /::::/, $rowdata;
			for ($i=0; $i<=$#cells; $i++) {
				if (($i==0) && ($header ne "yes")){
					$style = "style='border-width:0px 1px 1px 1px;border-style:solid;border-color:#b0c4de'";
				}
				elsif ($header ne "yes") {
					$style = "style='border-width:0px 1px 1px 0px;border-style:solid;border-color:#b0c4de'";
				}
				elsif (($i==0) && ($header eq "yes")){
					$style = "style='border-width:1px 1px 1px 1px;border-style:solid;border-color:#b0c4de'";
				}
				elsif ($header eq "yes") {
					$style = "style='border-width:1px 1px 1px 0px;border-style:solid;border-color:#b0c4de'";
				}
				#### the horizontal alignment of the column contents:
				if ($i==0 || $i==10) {
					$thetable .= "<td align=left nowrap ";
					$thetable .= $style;
					$thetable .= "><span class=smalltext>&nbsp;@cells[$i]&nbsp;<\/span><\/td>";
				}
				elsif ($i==4 || $i==5 || $i==6 || $i==7) {
					$thetable .= "<td align=right nowrap ";
					$thetable .= $style;
					#round XCorrs value (use the microchem-include precision function)
					if ($i == 5) {
						my $xcorr = $cells[$i];
						$xcorr =~ s/<[^>]+>//g;
						$xcorr = &precision($xcorr, 1);
						$cells[$i] =~ s/(^.*)\d+\.\d+(.*)/$1$xcorr$2/;
					}
					$thetable .= "><span class=smalltext>&nbsp;&nbsp;@cells[$i]&nbsp;&nbsp;<\/span><\/td>";
				}
				elsif ($i==3) {
					$thetable .= "<td align=center nowrap ";
					$thetable .= $style;
					$thetable .= "><span class=smalltext>&nbsp;<b>@cells[$i]<\/b>&nbsp;<\/span><\/td>";
				}
				else {
					$thetable .= "<td align=center nowarp ";
					$thetable .= $style;
					$thetable .= "><span class=smalltext>&nbsp;@cells[$i]&nbsp;<\/span><\/td>";
				}
			}
			$thetable .= "<\/tr>";
			#$firstheader = "no";
		}
	
	}
	if ($whiterows != 0) {
		$thetable .= "</tbody>";
	}
	if ($match eq "no") {
		$thetable .= "<script language='Javascript'>noMatches++;</script>";
		$thetable .= "<tr id=noMatches_$nomatches><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td class=smallheading align=center>None</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>";
	}
	return $thetable;
}

sub could_not_open {
	print "Could not find temp file. Try running MuQuest again.";
	exit;
}

# maybe_highlight_delm
# inputs are delm and skew, it returns delm either with a bold tag or not
sub maybe_highlight_delm{
	my($delm,$skew, $highlight) = @_;
	my($bold) = 0;

	foreach $val (keys %diffList){
			if ( abs(abs($delm) - abs($val)) < 0.8) {
				$bold = 1;
			}
	}
	if( abs(abs($skew) - abs($delm))< 1.5){
		$bold = 1;
	}

	if ($bold eq 1) {
		$$highlight = "yes";
	}

	return $bold ? "<b>$delm</b>" : "$delm";
}

# maybe_highlight_skew
# inputs are delm and skew, it returns skew either with a bold tag or not
sub maybe_highlight_skew{
	my($delm_maybe_bold,$skew, $highlight) = @_;
	
	my $delm;
	$delm_maybe_bold =~ /.*?(\-?\d+\.?\d*|\d+).*/;  #extract numbers
	$delm = $1; 
	
	my($bold) = 0;

	my(@highlight_values) = (-1,0,1);
	foreach(@highlight_values){
			if ( abs(abs($skew) - abs($_)) < 0.8) {
				$bold = 1;
			}
	}
	if( abs(abs($skew) - abs($delm))< 1.5){
		$bold = 1;
	}
	
	if ($bold eq 1) {
		$$highlight = "yes";
	}

	return $bold ? "<b>$skew</b>" : "$skew";
}

# link_delm
# input is $delm, perhaps with bold tags, but keep text black
# returns $delm as passed in surrounded by <a> tags with a link to the appropriate delta mass website.
# requires external $ABRFdm variable.
sub link_delm{
	my $delm_maybe_bold = shift;

	my $unbolded_dm;
	my $link;

	$delm_maybe_bold =~ /.*?(\-?\d+\.?\d*|\d+).*/;  #extract numbers
	$unbolded_dm = $1; 
	$link = "$ABRFdm$unbolded_dm&Margin=2";
	my $color = "style=\"color:#000000\"";

	return "<a href=$link $color>$delm_maybe_bold</a>";
}

# get_diff
# descript: gets the textual description of the delta-mass obtained (eg. phosphorylation, etc.)
# input is delm
# returns the string corresponding to that (rounded) delm in the diffList hash
sub get_diff{
	my $delm_maybe_bold = shift;
	my $dm;
	$delm_maybe_bold =~ /.*?(\-?\d+\.?\d*|\d+).*/;  #extract numbers
	$dm = $1; 

	foreach $val (keys %diffList) {
		if (abs (abs($dm) - abs($val)) < 0.8) {	
			return $diffList{$val};
		}
	}
}

sub make_ladders{

	my(@ladderseqs) = @_;
	my(@rv) = ();

	print qq(<span class="smallheading" id="ionladder_msg"><br>Creating ionladder files...<p></span>);

	# Let's make some ladders!
	foreach(@ladderseqs){

		my($fname) = "$_.0000.0000.2.dta";
		push @rv, $fname;

		# If it exists, no need to create it
		next if (-e "$tempdir/$fname" );

		# prepare list of arguments to run ionladder in the background
		$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string( "sequence" => $_, "charge_state" => 2, "box1" => "on", "box2" => "on", "MHplus" => "", "a_ions" => "true", "b_ions" => "true", "y_ions" => "true", "h2o" => "true", "nh3" => "true", "addmass" => "", "modlocations" => "", "cys_alkyl" => "CAM", "low_cut_value" => 30, "high_cut_value" => 2000, "filename" => "$fname", "directory" => "$tempdir");
		
		
		$procobj = &run_silently_in_background("$perl $cgidir/ionladder.pl USE_QUERY_STRING_INTRACHEM");
		until ($procobj->Wait(1000)) {
			print "" or &abort($procobj);
		}	

	}

	print qq(<script language=javascript> document.all.ionladder_msg.style.display="none"</script>);
	return(@rv);

}

sub print_sample_name {
  my ($directory, $padding) = @_;
  
  my (%dir_info) = &get_dir_attribs ($directory);
  $dir_info{"Fancyname"} = &get_fancyname($directory,%dir_info);

  print qq(<span class="smallheading">Dir:</span>\n);

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



sub delete_PTAs {

	opendir(DIR,"$seqdir/$dir") || &error("can't open directory $seqdir/$dir");
	@ptas = map "$seqdir/$dir/$_", grep /\.l?pta$/, readdir(DIR);
	closedir(DIR);
	if ($otherdir ne $dir) {
		opendir(DIR,"$seqdir/$otherdir") || &error("can't open directory $seqdir/$otherdir");
		push(@ptas, map "$seqdir/$otherdir/$_", grep /\.l?pta$/, readdir(DIR));
		closedir DIR;
	}

	$deleted = unlink @ptas;

	print "$deleted files deleted.</body></html>";

	exit;
}


# This function is adapted from runsummary.pl
# See also load_java_DTA_funcs in the Javascript section for the remainder of the DTA VCR code.
# Creates a popup window using dta_vcr.pl.  The checkbox feature is modeled after the example in
# dta_chromatogram, except this version uses dta_vcr.pl directly rather than imports the code
#
sub dta_vcr_code
{
	my $i;
	# create a unique name for the dta_vcr window (includes both pid and start time of this Perl process)
	my $dta_vcr_name = "dtavcr" . $$ . $^T;
	my $linkvalue = join("<DTAVCR>", @dtavcr_links);
	my $infovalue = join("<DTAVCR>", @dtavcr_infos);
#	my $includeifvalue = join("<DTAVCR>", @dtavcr_include_ifs);
	
	# get rid of line breaks
	foreach ($linkvalue, $infovalue, $includeifvalue) {
		s/\n/ /g;
	}

	# modified 10/24/99 to prevent major Javascript and caching problems on large pages:
	# instead of including a huge amount of info in hidden form elements on the page, put it in a temp file
	$vcr_file = "$tempdir/$dta_vcr_name.txt";
	open(VCRFILE, ">$vcr_file");
	print VCRFILE "DTAVCR:link=$linkvalue\n";
	print VCRFILE "DTAVCR:info=$infovalue\n";
#	print VCRFILE "DTAVCR:include_if=$includeifvalue\n";
	close VCRFILE;

	# use a hidden form element to tell DTA VCR window where that file is
	print qq(<input type=hidden name="DTAVCR:tempfile" value="$vcr_file">\n);

	&load_java_DTA_funcs($dta_vcr_name);
}

# These Javascript functions are adapted from run_summary.pl and dta_chromatogram.pl
# Args: dta_vcr_name - Consists of 'dta_vcr' . $$ . $^T -- or in other words
#                                  'dta_vcr' and processID and basetime concatenated together
sub load_java_DTA_funcs
{
	my $dta_vcr_name = "dta_vcr" . $$ . $^T;
	$vcr_file = "$tempdir/$dta_vcr_name.txt";

	print <<EOF;
<script language="Javascript">
<!--

// declare reference to DTA-VCR window as a global variable
var dta_vcr_muquest;

// global index that holds the place of the current form element in MuQuest, updated when DTA VCR shifts to a new dta
var i;

function openDTA_VCR()
{
	if (dta_vcr_muquest && !dta_vcr_muquest.closed) {
	
		dta_vcr_muquest.focus();

	} else {		
		oldaction = document.delptas.action;
		oldtarget = document.delptas.target;

		document.delptas.action="$webcgi/dta_vcr.pl";
		document.delptas.target="$dta_vcr_name";

		self.onfocus = DTA_VCR_cleanup;

		dta_vcr_muquest = open("javascript:opener.document.delptas.submit()","$dta_vcr_name","resizable");
	}
}

// After DTA VCR window is opened, restore settings
function DTA_VCR_cleanup()
{
	// put things back as they were
	document.delptas.action = oldaction;
	document.delptas.target = oldtarget;
	self.onfocus = null;
}

// close DTA VCR window if main window is changed
function close_popups()
{
	if (dta_vcr_muquest)
		if (!dta_vcr_muquest.closed)
			dta_vcr_muquest.close();
}
onunload = close_popups;

//-->
</script>

EOF
}


sub error {

	print "<h3>Error:</h3>" . join("<BR>",@_) . "</body></html>";

}

sub kill_switch{

	$num_kill_switches++;
	$this_kill = "kill_" . "$num_kill_switches";
	$this_killed  = "killed_" . "$num_kill_switches";
	print <<DONE;
	<span id="$this_kill">
	   &nbsp;&nbsp;<span class="smallheading" style="color:red;cursor:hand" onClick="window.open('$webcgi/assasin.pl?pid=$$','_blank'); document.all['$this_kill'].style.display='none'; document.all['$this_killed'].style.display='';">Stop</span>
	</span>
	<span id="$this_killed" style="display:none;">
		&nbsp;&nbsp;<span class="smallheading" style="color:red">Process Killed</span>
	</span>
	<br><br style="font-size:5">
DONE
}

# Get the type of browser for Perl use via a form element
sub	load_java_get_browser
{
print <<EOF;
<script language="Javascript">
<!--
if (isIE) {
	document.forms[0].browser.value = "IE";
	document.forms[1].browser.value = "IE";
	document.forms[2].browser.value = "IE";
}
//-->
</script>
EOF
}
# When page is loaded, gets rid of the progress bar
sub load_java_toggle_progress
{
print <<EOF;
<script language="Javascript">
<!--
function toggle_progress() {
	var progress = document.getElementById("progress");
	if (progress != null) {
		progress.style.display ="none";
	}
	var header = document.getElementById("output_header");
	header.style.display ="";
}
// Netscape does not support the innerHTML element, so this only works on IE currently.
onload = toggle_progress;

//-->
</script>
EOF
}

