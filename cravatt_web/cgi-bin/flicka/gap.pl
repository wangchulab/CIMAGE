#!/usr/local/bin/perl

#-------------------------------------
#	Gap Launcher,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/Ulas/Georgi Matev
#
#	v3.1a
#	
#	launches Gap -- copyright MTU
#	
#	07/03/2000(Georgi) -- changed form submission to "POST" in order for the
#   script to handle arbitrarily large sequences.
#-------------------------------------


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
	
}
require "fastaidx_lib.pl"; # We need this for the database lookup

$gapexe = "$cgidir/gap.exe";
$gapfiledir = $incdir;

#######################################
# Fetching data
&cgi_receive;

#getting program defaults as well as retreiving form values
if(exists $FORM{'database1'}) {
	# Strip off path from database name
	($FORM{'database1'}) = ($FORM{'database1'} =~ m!([^/]+)$!);
} else {
	$FORM{'database1'} = $DEFAULT_DB;
}
if(exists $FORM{'database2'}) {
	# Strip off path from database name
	($FORM{'database2'}) = ($FORM{'database2'} =~ m!([^/]+)$!);
} else {
	$FORM{'database2'} = $DEFAULT_DB;
}

# get database type
$db1 = $FORM{'database1'};
$path_to_db1 = "$dbdir/$db1";
$is_nucleo1 = &get_dbtype("$path_to_db1");

# get database type
$db2 = $FORM{'database2'};
$path_to_db2 = "$dbdir/$db2";
$is_nucleo2 = &get_dbtype("$path_to_db2");

# type_of_query1
$FORM{'type_of_query1'} = ($DEFS_GAP{'Please enter protein'} eq 'sequence'?0:1) if(!exists $FORM{'type_of_query1'});
$checked{"type_of_query1=$FORM{'type_of_query1'}"} = ' CHECKED';

# type_of_query2
$FORM{'type_of_query2'} = ($DEFS_GAP{'Please enter protein'} eq 'sequence'?0:1) if(!exists $FORM{'type_of_query2'});
$checked{"type_of_query2=$FORM{'type_of_query2'}"} = ' CHECKED';

# gap_size
$FORM{'gap_size'} = $DEFS_GAP{'Gap Size'} if (!exists $FORM{'gap_size'});
$gap_size = $FORM{'gap_size'};
$gap_size = 1 unless ($gap_size > 0);

# mismatch
$FORM{'mismatch'} = $DEFS_GAP{'Mismatch'} if (!exists $FORM{'mismatch'});
$mismatch = $FORM{'mismatch'};

# gap_open_penalty
$FORM{'gap_open_penalty'} = $DEFS_GAP{'Gap Open Penalty'} if (!exists $FORM{'gap_open_penalty'});
$gap_open_penalty = $FORM{'gap_open_penalty'};
$gap_open_penalty = 0 unless ($gap_open_penalty >= 0);

# gap_extend_penalty
$FORM{'gap_extend_penalty'} = $DEFS_GAP{'Gap Extend Penalty'} if (!exists $FORM{'gap_extend_penalty'});
$gap_extend_penalty = $FORM{'gap_extend_penalty'};
$gap_extend_penalty = 1 unless ($gap_extend_penalty > 0);

#formatting
if ($FORM{"frame1"} == 1) { $FORM{'frame1'} = "+1"; }
if ($FORM{"frame1"} == 2) { $FORM{'frame1'} = "+2"; }
if ($FORM{"frame1"} == 3) { $FORM{'frame1'} = "+3"; }
if ($FORM{"frame2"} == 1) { $FORM{'frame2'} = "+1"; }
if ($FORM{"frame2"} == 2) { $FORM{'frame2'} = "+2"; }
if ($FORM{"frame2"} == 3) { $FORM{'frame2'} = "+3"; }

$sel{"frame1=$FORM{'frame1'}"} = ' SELECTED';
$sel{"frame2=$FORM{'frame2'}"} = ' SELECTED';

$running = $FORM{'running'};

#######################################
# Flow control
#

#data not submitted yet
if (!$running)
{
	#output form with no data
	&get_sequences();
	&output_form($seq1, $fasta_info1, $seq2, $fasta_info2);
	exit;
}
else
{
	#output results in a seperate frame
	&output_frames();
	exit;
}

exit;
#######################################
# subroutines (other than &output_form and &error, see below)
sub get_dbtype 
{
	my ($db) = $_[0];
	my ($line, $numchars, $numnucs, $numlines);

	open (DB, "$db") || &error ("Could not open database $db for auto-detecting database type.");
	while ($line = <DB>) 
	{
		next if ($line =~ m!^>!);

		chomp $line;
		$numchars += length ($line);
		$numnucs += $line =~ tr/ACTG/ACTG/;

		$numlines++;
		last if ($numlines >= 500);
	}
	close DB;

	 return (1) if ($numnucs > .8 * $numchars);

	return (0);
}

sub get_sequences()
{
	#we are checking if the sequence is a database identifier regardless of the query method
	#this enables us to do an automatic switch to db query if we have an identifier
	# Ask database -- based on etc/sequence_lookup.pl
	my $database = $FORM{"database1"};
	my $seqid = $FORM{"peptide1"};
	my @seq;

	$database=~s/\.fasta//g;
	$seqid = parseentryid($seqid);

	chdir($dbdir);

	if (not &openidx($database)) {
	    if ($FORM{'type_of_query1'}) {
			# we are specifically doing a db lookup so there is nothing to be done but fail 
		    &MS_pages_header ("Gap", '008000', $nocache, '<BASE TARGET="_parent">');
			print"<hr>\n";
			print ("<p><span class=\"normaltimes\"><i>\nNo flatidx file was found for the $database.fasta database, generate one before running Gap\n</i></span><p>");
			@text = ("Index $database.fasta", "Goto Gap");
			@links = ("$fastaidx_web?running=ja&Database=$database.fasta", "$ourname");
			&WhatDoYouWantToDoNow(\@text, \@links);
			exit;
		}
	} else {
		(@seq) = lookupseq($seqid);
		&closeidx();
	}

	if ($is_nucleo1) 
	{
		$transl_table = 1;
		$transl_name = &calculateTranslationTable($transl_table);
		   
		if ($seq[0] =~ /^>/) 
		{
			$fasta_info1 = shift @seq;
			$fasta_info1 =~ s/^>(.*)$/\1/gi;
		}
			
		$frame1 = $FORM{"frame1"};
		$DBseq1 = join "\n", @seq;
		$DBseq1 =~ s/\n//g;
		$DBseq1 =~ s/\s*//g;
		($DBseq1) = &translate ($DBseq1, $frame1);
		$DBseq1 =~ s/&nbsp;//g;
			
		$DBseq1 =~ s/<.*?>|\s//g;  # Strip HTML tags
			
		#commented out by Georgi 07/01/2000 to allow * in sequences
		#$DBseq1 =~ s/\*//g;
	}
	else
	{
		$DBseq1 = join "\n", @seq;
	}


	if ($FORM{'type_of_query1'} or $DBseq1)
	{
		$seq1 = $DBseq1;

		# Check for unsuccessful lookup if method is explicitly by DB
		if ((length $DBseq1) == 0)
		{
			if (!$FORM{'peptide1'})
			{
				$error2 = "Sequence 1 is empty!";
			}
			else
			{
				$error2 = "Error in sequence 1: Identifier <B>$seqid</B> not found in database <B>$database</B>.";
			}
		} 
	
		#autoswitch to DB if needed
		$type_of_query1 = $FORM{'type_of_query1'} = 1;
		$checked{"type_of_query1=$type_of_query1"} = ' CHECKED';
	} else {
		$seq1 = $FORM{"peptide1"};
	}

	#do same for sequence2

	#we are checking if the sequence is a database identifier regardless of the query method
	#this enables us to do an automatic switch to db query if we have an identifier
	# Ask database -- based on etc/sequence_lookup.pl
	my $database = $FORM{"database2"};
	my $seqid = $FORM{"peptide2"};
	my @seq;

	$database=~s/\.fasta//g;
	$seqid = parseentryid($seqid);

	chdir($dbdir);

	if (not &openidx($database)) {
	    if ($FORM{'type_of_query2'}) {
			# we are specifically doing a db lookup so there is nothing to be done but fail 
		    &MS_pages_header ("Gap", '008000', $nocache, '<BASE TARGET="_parent">');
			print"<hr>\n";
			print ("<p><span class=\"normaltimes\"><i>\nNo flatidx file was found for the $database.fasta database, generate one before running Gap\n</i></span><p>");
			@text = ("Index $database.fasta", "Goto Gap");
			@links = ("$fastaidx_web?running=ja&Database=$database.fasta", "$ourname");
			&WhatDoYouWantToDoNow(\@text, \@links);
			exit;
		}
	} else {
		(@seq) = lookupseq($seqid);
		&closeidx();
	}

	if ($is_nucleo2) 
	{
		$transl_table = 1;
		$transl_name = &calculateTranslationTable($transl_table);
		   
		if ($seq[0] =~ /^>/) {
			$fasta_info2 = shift @seq;
			$fasta_info2 =~ s/^>(.*)$/\1/gi;
		}

		$frame2 = $FORM{"frame2"};
		$DBseq2 = join "\n", @seq;
		$DBseq2 =~ s/\n//g;
		$DBseq2 =~ s/\s*//g;
		($DBseq2) = &translate ($DBseq2, $frame2);
		$DBseq2 =~ s/&nbsp;//g;
					
		$DBseq2 =~ s/<.*?>|\s//g;  # Strip HTML tags
			
		#commented out by Georgi 07/01/2000 to allow * in sequences
		#$DBseq2 =~ s/\*//g;

	} 
	else 
	{
		$DBseq2 = join "\n", @seq;
	}

	#actually assign sequence 
	if ($FORM{'type_of_query2'} or $DBseq2)
	{
		$seq2 = $DBseq2;

		# Check for unsuccessful lookup if method is explicitly by DB
		if ((length $DBseq2) == 0)
		{
			if (!$FORM{'peptide2'})
			{
				$error2 = "Sequence 2 is empty!";
			}
			else
			{
				$error2 = "Error in sequence 2: Identifier <B>$seqid</B> not found in database <B>$database</B>.";
			}
		} 
	
		#autoswitch to DB if needed
		$type_of_query1 = $FORM{'type_of_query2'} = 1;
		$checked{"type_of_query2=$type_of_query2"} = ' CHECKED';
	} else {
		$seq2 = $FORM{"peptide2"};
	}

	# strip first line if in FASTA database format
	$fasta_info1 = $1 if ($seq1 =~ s/^>+(.*)\n//);
	$fasta_info2 = $1 if ($seq2 =~ s/^>+(.*)\n//);

	$seq1 =~ tr/a-z/A-Z/;
	$seq1 =~ s/\s//g;

	$seq2 =~ tr/a-z/A-Z/;
	$seq2 =~ s/\s//g;
}


sub output_frames
{
	&get_sequences();

	$now = &get_unique_timeID();

	#get unique file names for the two frames
	my $interface_file = "$ourshortname" . "_interface" . "_$now.html";
	my $results_file = "$ourshortname" . "_results" . "_$now.html";

	#write interface file
	&output_form ($seq1, $fasta_info1, $seq2, $fasta_info2, "$tempdir/$interface_file");

	#remove line 'Content-type: text/html' (needed when pages are created on the fly) from the interface file
	#This is not the most efficient way of dealing with the problem but is the easiest. Otherwise the 
	#MS_pages_header function in michrochem_include has to be changed a bit.
	my $tmp;
	open INTERFACE, "$tempdir/$interface_file" or die "Cannot open $tempdir/$interface_file!!!";
	
	#discard first line which is 'Content-type: text/html'
	<INTERFACE>;
	while ($line = <INTERFACE>)
	{
		$tmp.= $line;
	}
	close INTERFACE;

	#rewrite file
	open INTERFACE, ">$tempdir/$interface_file" or die "Cannot open $tempdir/$interface_file!!!";
	print INTERFACE $tmp;
	close INTERFACE;


	#write results file
	&output_results("$tempdir/$results_file");

	#write interface to a tempfile for upper frame
	
	print <<FRAMES;
Content-type: text/html

<html>
<head>
<title>Gap</title>
$stylesheet_html
$nocache
</head>
<script language='JavaScript'>
	//When created the frames are properly sized fo NN.
	//This adjusts them for IE
	function resizeforIE(mainWin)
	{
		mainWin.document.all.gap_frames.rows="54%,*";
	}
</script>
<frameset id='gap_frames' rows="62%, *" border=0 framespacing=0 frameborder=no onload="resizeforIE(self.parent.parent)">
	<frame src="$webtempdir/$interface_file" name="interface" scrolling="no">
	<frame src="$webtempdir/$results_file#result" name="results" scrolling="yes" marginHeight=0 marginWidth=14>
</frameset>
</html>
FRAMES
}


sub output_results()
{
	#argument(s): temporary html file to save results
	my $results_file = shift @_;

	my $results;
	$results.= <<EOP;
<html>
<head>
$stylesheet_html
</head>
<body>
EOP
	#$seq1 =~/\s//g;
	#$seq2 =~/\s//g;
	
	if ($seq1 =~ /[^A-Z^\*]/) 
	{
		$seq1 =~ s/[^A-Z^\*]//g;
		$warning1 = "Some non-letter characters have been removed from sequence1!!!";
	}

	if ($seq2 =~ /[^A-Z^\*]/) 
	{
		$seq2 =~ s/[^A-Z^\*]//g;
		$warning2 = "Some non-letter characters have been removed from sequence2!!!";
	}
	
	if ($error1 or $error2)
	{
		&error ($error1."<BR>\n".$error2, $results_file);
		return;
	}

	if (!$seq1 and !$seq2)
	{
		&error ('Both sequences are empty!', $results_file);
		return;
	}

	if (!$seq1)
	{
		&error ('Sequence 1 is empty!', $results_file);
		return;
	}

	if (!$seq2)
	{
		&error ('Sequence 2 is empty!', $results_file);
		return;
	}

	# Dump output of gap.exe on $seq1 and $seq2
	$now = &get_unique_timeID();
	$seq1file = "$tempdir/$ourshortname.seq1" . "_$now.fasta";
	$seq2file = "$tempdir/$ourshortname.seq2" . "_$now.fasta";
	open SEQ1, ">$seq1file" or die "Could not write $seq1file";
	print SEQ1 ">", $fasta_info1, "\n", $seq1, "\n";
	close SEQ1;
	open SEQ2, ">$seq2file" or die "Could not write $seq2file";
	print SEQ2 ">", $fasta_info2, "\n", $seq2, "\n";
	close SEQ2;

	$results.= "<span style='color:red'>$warning1</span><BR>\n" if (defined $warning1);
	$results.= "<span style='color:red'>$warning2</span><BR>\n" if (defined $warning2);
	$results.= "<BR>\n" if ((defined $warning1) or (defined $warning2));

	#uncomment the following to see command line for debug
	#print "Running $gapexe $seq1file $seq2file $gap_size $gapfiledir/$mismatch $gap_open_penalty $gap_extend_penalty<BR>\n";
	$gap_out = `$gapexe $seq1file $seq2file $gap_size $gapfiledir/$mismatch $gap_open_penalty $gap_extend_penalty`;
	$gap_out =~ s/\n/<BR>\n/g;
	$gap_out =~ s/ /&nbsp;/g;

	#setup RE for parsing tags in gap.exe's output
	my $RE = '';
	my @tag_list = ('Parameters', 'Sequences', 'Stats', 'Match');

	foreach $tag (@tag_list)
	{
		$RE.= "<!-Start-".$tag."-!>(.*)<!-End-".$tag."-!>";
	}

	$gap_out =~ /$RE/ogs;

	my %output_hash = ();

	my $i=0;
	foreach ($1, $2, $3, $4)
	{
		my $tag = shift @tag_list;
		$output_hash{$tag} = $_;
		push @tag_list, $tag;
	}

	my ($max_match, $min_mism, $gapopen_p, $gapext_p) = split ('<BR>\n', $output_hash{'Parameters'}, 4);
	my ($header1, $seq1_len, $header2, $seq2_len) = split ('<BR>\n', $output_hash{'Sequences'}, 4);

	
	
	#put an anchor 3<BR>s above first match #a really poor way to do it 
	$output_hash{'Match'}=~ m!^(.*?)(\|.*)$!ims;
	my ($b_mark, $a_mark) = ($1, $2);
	$b_mark =~ m!^(.*)(<BR>.*)$!ims;
	my ($bb_mark, $aa_mark) = ($1, $2);
	$bb_mark =~ m!^(.*)(<BR>.*)$!ims;
	my ($bbb_mark, $aaa_mark) = ($1, $2);
	$bbb_mark =~ s!^(.*)(<BR>.*)$!\1<a name='result'></a>\2!ims;
	$output_hash{'Match'}= $bbb_mark.$aaa_mark.$aa_mark.$a_mark;
	
	#display matching diagram
	$results.= <<MATCHING;
	<tt class='small'>$output_hash{'Match'}</tt>
MATCHING

	print "<tt>\n";

	#display footer
	my ($sim_score, $match_per, $num_match, $num_mism, $total_gap, $note) = split('<BR>\n', $output_hash{'Stats'}, 6);

	$results.= <<FOOTER;
	<br>
FOOTER
	
	
	
	if ($header1 ne 'Sequence1:&nbsp;' or $header2 ne 'Sequence2:&nbsp;')
	{
		$header1=~ s/&nbsp;/ /sg;
		$header1=~ s!Sequence1:(.*$)!<b>Sequence&nbsp;1:</b>$1!sg;

		$header2=~ s/&nbsp;/ /sg;
		$header2=~ s!Sequence2:(.*$)!<b>Sequence&nbsp;2:</b>$1!sg;

		$results.= <<FOOTER;
	<table cellspacing=0 cellpadding=0 border=0>
	<tr>
		<td colspan=8 width=750><span class='smalltext'>$header1</span></td>
	</tr>
	</table>

	<table cellspacing=0 cellpadding=0 border=0>
	<tr>
		<td colspan=8 width=750><span class='smalltext'>$header2</span></td>
	</tr>
	</table>
FOOTER
	}

	$results.= <<FOOTER;
	<table cellspacing=0 cellpadding=0 border=0>
	<tr>
		<td colspan=8><span class='smalltext'><B>Gap Results:</B></span></td>
	</tr>
	<tr>
		<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
		<td><span class='smalltext'>$sim_score</span></td>
		<td></td>
		<td><span class='smalltext'>$total_gap</span></td>
		<td></td>
		<td><span class='smalltext'>$seq1_len</span></td>
		<td></td>
		<td><span class='smalltext'>$seq2_len</span></td>
	</tr>
	<tr>
		<td></td>
		<td><span class='smalltext'>$match_per</span></td>
		<td></td>
		<td><span class='smalltext'>$num_match</span></td>
		<td></td>
		<td><span class='smalltext'>$num_mism</span></td>
		<td colspan=2>
	</tr>
	<tr>
		<td></td>
		<td colspan=7><span class='smalltext'>$note</span></td>
	</tr>
	<tr>
		<td colspan=8><span class='smalltext'><B>Gap Parameters:</B></span></td>
	</tr>
	<tr>
		<td></td>
		<td><span class='smalltext'>$max_match</span></td>
		<td>&nbsp;&nbsp;&nbsp;</td>
		<td><span class='smalltext'>$min_mism</span></td>
		<td>&nbsp;&nbsp;&nbsp;</td>
		<td><span class='smalltext'>$gapopen_p</span></td>
		<td>&nbsp;&nbsp;&nbsp;</td>
		<td><span class='smalltext'>$gapext_p</span></td>
	</tr>
	</table>
FOOTER

	$results.= "</tt>\n";
	#print "<script>self.scrollBy(0, -20);</script>\n";
	$results.= "</body>\n</html>";

	#write actual file
	open RESULTS, ">$results_file" or die "Cannot open $results_file for input!!!";
	print RESULTS $results;
	close RESULTS;
}

sub output_form 
{  
	my ($peptide1, $fasta_info1, $peptide2, $fasta_info2, $interface_file) = @_;
	
	my $clear_seq1 = 'JavaScript:';
	$clear_seq1.="self." if ($running);
	$clear_seq1.= "clearTextbox('peptide1');";

	my $clear_seq2 = 'JavaScript:';
	$clear_seq2.="self." if ($running);
	$clear_seq2.= "clearTextbox('peptide2');";

	if (defined $fasta_info1) 
	{	
		$fasta_info1=~ s/\r//g;
		$peptide1 = "&gt;$fasta_info1\n" . $peptide1;
	}
	#else
	#{
	#	#readio button back to sequence if necessary
	#	$checked{"type_of_query1=0"} = ' CHECKED';
	#	$checked{"type_of_query1=1"} = '';
	#}
		


	if (defined $fasta_info2) 
	{
		$fasta_info2=~ s/\r//g;
		$peptide2 = "&gt;$fasta_info2\n" . $peptide2;
	}
	#else
	#{
	#	#readio button back to sequence if necessary
	#	$checked{"type_of_query2=0"} = ' CHECKED';
	#	$checked{"type_of_query2=1"} = '';
	#}

	if ($FORM{"clear"}) 
	{
	    $peptide1 = "";
		$peptide2 = "";
		$running = '';
    }

	@seq1_buttons, @seq1_ncbi, @seq2_buttons, @seq2_ncbi;
	my $ncbi_header = "<span class=smallheading>NCBI:&nbsp;</span>";
	
	$send1 = "<span class=smallheading>Send to:&nbsp;</span>" if ($seq1);
	$send2 = "<span class=smallheading>Send to:&nbsp;</span>" if ($seq2 and $running);

	make_buttons(\@seq1_buttons, \@seq1_ncbi, \@seq2_buttons, \@seq2_ncbi);
	my $ncbi1 = $ncbi_header if (@seq1_ncbi);
	my $ncbi2 = $ncbi_header if (@seq2_ncbi);

	#rediredct standard output a file if necessary; needed for frames
	if ($interface_file)
	{
		open SAVEOUT, ">&STDOUT";
		open STDOUT, ">$interface_file" or die "Cannot open $interface_file for input!!!";
	}
	
    &MS_pages_header ("Gap", '008000', $nocache, '<BASE TARGET="_parent">');
	print"<hr>\n";

	print <<EOFORM;
<script language='JavaScript'>
	function clearTextbox(name)
	{
		self.document.forms[0][name].value = '';

		
		var num = name.substr(name.length - 1);		//last char
		var tagname = 'buttons' + num;
		
		if (isIE)
		{	
			self.document.all[tagname].style.visibility = 'hidden';
		}

		if (isNN)
		{		
			self.document[tagname].visibility = false;
		}
	}
</script>

<div>
<FORM METHOD=post ACTION="$ourname">
<input type=hidden name=running value=1>
<table cellspacing=0 cellpadding=0 border=0>
<tr height=25>
	<td bgcolor=#e8e8fa nowrap><span class=smallheading>&nbsp;&nbsp;Enter Protein 1</span>
	<INPUT TYPE=RADIO NAME="type_of_query1" VALUE=0$checked{"type_of_query1=0"}>
	<span class="smallheading">sequence</span>
	<INPUT TYPE=RADIO NAME="type_of_query1" VALUE=1$checked{"type_of_query1=1"}>
	<span class="smallheading"><nobr>identifier from db:</nobr></span>
EOFORM

# The following based on sequence_lookup.pl, sets @ordered_db_names
&get_dbases;

# make dropbox:
&make_dropbox ("database1", $FORM{'database1'}, @ordered_db_names);
	print <<EOP;
		<span class='smallheading'>Frame:</span>
		<SPAN CLASS="dropbox"><SELECT NAME="frame1">
EOP
	foreach $value ('+1', '+2', '+3', '-1', '-2', '-3') 
	{
		print <<EOP;
		<OPTION $sel{"frame1=$value"}>$value
EOP
	}
	print <<EOFORM;
	</SELECT></SPAN>&nbsp;
	</td>
	<td bgcolor=#e8e8fa>
	<input type=button class="smalloutlinebutton button" style="cursor:hand" value="Clear" title='Clear protein field 1' onclick=\"$clear_seq1\" onMouseOver=\"window.status='Clear protein field 1'; return true;\" onMouseOut=\"window.status='';return true;\">&nbsp;
	</td>
</tr>
<tr><td style="font-size:3" bgcolor=#f2f2f2 colspan=2>&nbsp;</td></tr>
<tr>
	<td bgcolor=#f2f2f2 align=center valign=top colspan=2>
		<tt><TEXTAREA WRAP=VIRTUAL ROWS=4 COLS=86 NAME="peptide1" class=outline>$peptide1</TEXTAREA></tt>
	</td>
	<td valign=top>
		<span id='buttons1' style='position:relative'>
		<table cellspacing=0 cellpadding=2 border=0>	
		<tr>
			<td align=right nowrap>
				&nbsp;&nbsp;$send1
			</td>
			<td nowrap>
				$seq1_buttons[0]
				$seq1_buttons[1]
				$seq1_buttons[2]
			</td>
		</tr>
		<tr>
			<td align=right nowrap>
				$ncbi1
			</td>
			<td>
				$seq1_ncbi[0]
				$seq1_ncbi[1]
			</td>
		</tr>
		</table>
		</span>	
	</td>
</tr>
<tr><td style="font-size:3" bgcolor=#f2f2f2 colspan=2>&nbsp;</td></tr>
<tr>
	<td height=10>&nbsp;
	<td>
</tr>
<tr height=25>
	<td bgcolor=#e8e8fa nowrap><span class="smallheading">&nbsp;&nbsp;Enter protein 2</span>
			<INPUT TYPE=RADIO NAME="type_of_query2" VALUE=0 $checked{"type_of_query2=0"}>
			<span class="smallheading">sequence</span>
			<INPUT TYPE=RADIO NAME="type_of_query2" VALUE=1$checked{"type_of_query2=1"}>
			<span class="smallheading"><nobr>identifier from db:</nobr></span>
EOFORM

	# make dropbox:
	&make_dropbox ("database2", $FORM{'database2'}, @ordered_db_names);
	print <<EOP;
			<span class='smallheading'>Frame:</span>
			<SPAN CLASS="dropbox"><SELECT NAME="frame2">
EOP
	foreach $value ('+1', '+2', '+3', '-1', '-2', '-3') 
	{
		print <<EOP;
				<OPTION $sel{"frame2=$value"}>$value
EOP
	}
	print <<EOFORM;
	</SELECT></SPAN>&nbsp;
	</td>
	<td bgcolor=#e8e8fa>
	<input type=button class="smalloutlinebutton button" style="cursor:hand" value="Clear" title='Clear protein field 2' onclick=\"$clear_seq2\" onMouseOver=\"window.status='Clear protein field 2'; return true;\" onMouseOut=\"window.status='';return true;\">
	</td>
</tr>
<tr><td style="font-size:3" bgcolor=#f2f2f2 colspan=2>&nbsp;</td></tr>
<tr>
	<td align=center bgcolor=#f2f2f2 valign=top colspan=2>
		<tt><TEXTAREA WRAP=VIRTUAL ROWS=4 COLS=86 NAME="peptide2" class=outline>$peptide2</TEXTAREA></tt>
	</td>
	<td valign=top>
		<span id='buttons2' style='position:relative'>
		<table cellspacing=0 cellpadding=2 border=0>
		<tr>
			<td align=right nowrap>
				&nbsp;&nbsp;$send2
			</td>
			<td nowrap>
				$seq2_buttons[0]
				$seq2_buttons[1]
				$seq2_buttons[2]
			</td>
		</tr>
		<tr>
			<td align=right>
				$ncbi2
			</td>
			<td>
				$seq2_ncbi[0]
				$seq2_ncbi[1]
			</td>
		</tr>

		</table>
		</span>
	</td>
</tr>
<tr><td style="font-size:3" bgcolor=#f2f2f2 colspan=2>&nbsp;</td></tr>
<tr>
	<td height=10>&nbsp;</td>
</tr>
<tr>
	<td colspan=2>
		<table cellspacing=0 cellpadding=0 border=0 width=100%>
		<tr>
			<td width=1>
				<span class="smallheading">Mismatch:&nbsp;</span>
			</td>
			<td>
EOFORM

	opendir GAPFILEDIR, $gapfiledir or die "No $gapfiledir dir???: $!";
	my @mismatch_tbls = grep /\.gap$/, readdir (GAPFILEDIR);
	closedir GAPFILEDIR;

	&make_dropbox ("mismatch", $FORM{'mismatch'}, @mismatch_tbls);

	print <<EOFORM;
			</td>
			<td align=right>
				<span class="smallheading">Gap Size:&nbsp;
			</td>
			<td>
				</span><INPUT SIZE=2 MAXLENGTH=2 NAME="gap_size" value="$FORM{'gap_size'}">
			</td>
			<td align=right>
				<span class="smallheading">Open Penalty:&nbsp;</span>
			</td>
			<td>
				<INPUT SIZE=2 MAXLENGTH=2 NAME="gap_open_penalty" value="$FORM{'gap_open_penalty'}">
			</td>
			<td align=right>
				<span class="smallheading">Extend Penalty:&nbsp;</span>
			</td>
			<td>
				<INPUT SIZE=2 MAXLENGTH=2 NAME="gap_extend_penalty" value="$FORM{'gap_extend_penalty'}">
			</td>			
			<td align=right>
				<INPUT TYPE="submit" CLASS="outlinebutton button" style="cursor:hand" title='Compare the sequences with the Gap algorithm' VALUE=" Gap ">&nbsp;&nbsp;
				<input type="hidden" name='running' value=1>
EOFORM
	
	if ($running)
	{
		print <<BUTTONS;
				<INPUT TYPE="button" CLASS="outlinebutton button" name='clear' style="cursor:hand" VALUE="Clear All" title='Clear all fields' onClick="self.parent.location = '$ourname'">&nbsp;&nbsp;&nbsp;
				<input type="button" class="outlinebutton button" name='print' style="cursor:hand" VALUE='Print' title="Print GAP results" onClick="printResults(self)">
			</td>
BUTTONS
	}

	print <<EOFORM;
		</tr>
		</table>
	</td>
</tr>
</table>
EOFORM

	print <<EOFORM;
<hr>
</FORM>
</div>
<SCRIPT Language="Javascript">
EOFORM
	if ($running)
	{
		print <<FUNC;
	function printResults(frame)
	{
		var toPrint = frame.parent.frames['results'];
		toPrint.focus();
		toPrint.print();
	}
FUNC
	}

	print <<EOFORM;
	//This is for formating purposes. Textareas are created so that they would apear properly aligned in NN. 
	//However, if brouwser is IE, the dimentsions are slightly different
	if (isIE)
	{
		document.forms[0].peptide1.cols=91;
		document.forms[0].peptide2.cols=91;
	}
</script>
</body>
</html>
EOFORM
	if ($interface_file)
	{
		close STDOUT;
		open STDOUT, ">&SAVEOUT";
	}
}

#modified from flicka.pl
sub make_buttons 
{
	#arguments passed by reference
	my ($seq1_buttons, $seq1_ncbi, $seq2_buttons, $seq2_ncbi) = @_;
	
	if ($seq1)
	{	
		my $ncbi_type1 = "p";
		my $type1 = $FORM{"type_of_query1"};
		
		#if a database query pass only first 15 chars of identifier
		my $ref1 = $type1 == 1? substr($fasta_info1,0, 15) : url_encode($FORM{'peptide1'});
		
		my $temp1 = $ref1;

		my $dir_query1 = "&Dir=". url_encode($FORM{'Dir'}) if (defined $FORM{'Dir'});

		my $frame_query1 = "";

		if ($is_nucleo1) { 
			$ncbi_type1 = "n";
			$frame_query1 = "&frame=$frame";
		}

		#make link to PEPSTAT
		$seq1_buttons[0] = qq(<span class="smallerbutton" style="width=58" onclick="window.open('$pepstat?type_of_query=$type1&database=$db1&peptide=$ref1$frame_query1$dir_query1&running=1', '_blank')">PepStat</span>);
		
		#make link to PEPCUT
		$seq1_buttons[1] = qq(<span class="smallerbutton" style="width=55" onclick="window.open('$pepcut?mode=backlink_run&type_of_query=$type1&database=$db1&query=$ref1$frame_query1$dir_query1&MassType=$FORM{MassType}&disp_sequence=yes', '_blank')">PepCut</span>);
		
		#make blast link
		$d1 = $db1;
		$d1 =~ s!\.fasta!!;

		$ncbi1 = "$remoteblast?$sequence_param=$seq1&";

		if (($d1 =~ m!dbEST!i) || ($d1 eq "est")) { $ncbi1 .= "$db_prg_aa_nuc_dbest"; }
		elsif ($d1 eq "nt") { $ncbi1 .= "$db_prg_aa_nuc_nr"; }
		elsif ($d1 =~ m!yeast!i) { $ncbi1 .= "$db_prg_aa_aa_yeast"; }
		else { $ncbi1 .= "$db_prg_aa_aa_nr"; }

		$ncbi1.= ($ncbi_type1 eq "p") ? "&$word_size_aa" : "&$word_size_nuc" if (defined $ncbi_type1);

		$ncbi1 .= "&$expect&$defaultblastoptions";
		
		$seq1_buttons[2] = qq(<span class="smallerbutton" style="width=55" onclick="window.open('$ncbi1', '_blank')">Blast</span>);

		$ref1 = $temp1;
		 
		# if reference is from ncbi then show links to Entrez
		if ($ref1 =~/gi\|/) 
		{
			$ref1 =~ /^gi\|(\d*)/;
			my  $myref1 = $1;
			$seq1_ncbi[0] = qq(<span class="smallerbutton" style="width=58" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref1&form=6&db=$ncbi_type1&Dopt=f', '_blank')">Sequence</span>);
			$seq1_ncbi[1] = qq(<span class="smallerbutton" style="width=55" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref1&form=6&db=$ncbi_type1&Dopt=m', '_blank')">Abstract</span>);
		}
	}

	if ($seq2)
	{
		my $ncbi_type2 = "p";
		my $type2 = $FORM{"type_of_query2"};

		
		#if a database query pass only first 15 chars of identifier
		my $ref2 = $type2 == 1? substr($fasta_info2,0, 15) : url_encode($FORM{'peptide2'});

		my $temp2 = $ref2;
		
		my $frame_query2 = "";
			
		if ($is_nucleo2) { 
			$ncbi_type2 = "n";
			$frame_query2 = "&frame=$frame";
		}

		#make link to PEPSTAT
		$seq2_buttons[0] = qq(<span class="smallerbutton" style="width=58" onclick="window.open('$pepstat?type_of_query=$type2&database=$db2&peptide=$ref2$frame_query2&running=1', '_blank')">PepStat</span>);
		
		
		#make link to PEPCUT
		$seq2_buttons[1] = qq(<span class="smallerbutton" style="width=55" onclick="window.open('$pepcut?mode=backlink_run&type_of_query=$type2&database=$db2&query=$ref2$frame_query2&MassType=$FORM{MassType}&disp_sequence=yes', '_blank')">PepCut</span>);	#make blast link
		$d2 = $db2;
		$d2 =~ s!\.fasta!!;

		$ncbi2 = "$remoteblast?$sequence_param=$seq2&";

		if (($d2 =~ m!dbEST!i) || ($d2 eq "est")) { $ncbi2 .= "$db_prg_aa_nuc_dbest"; }
		elsif ($d2 eq "nt") { $ncbi2 .= "$db_prg_aa_nuc_nr"; }
		elsif ($d2 =~ m!yeast!i) { $ncbi2 .= "$db_prg_aa_aa_yeast"; }
		else { $ncbi2 .= "$db_prg_aa_aa_nr"; }

		$ncbi2.= ($ncbi_type2 eq "p") ? "&$word_size_aa" : "&$word_size_nuc" if (defined $ncbi_type2);
		
		$ncbi2 .= "&$expect&$defaultblastoptions";

		$seq2_buttons[2] = qq(<span class="smallerbutton" style="width=55" onclick="window.open('$ncbi2', '_blank')">Blast</span>);
		$ref2 = $temp2;
		
		if ($ref2 =~/gi\|/) 
		{
			$ref2 =~ /^gi\|(\d*)/;
			my  $myref2 = $1;
			$seq2_ncbi[0] = qq(<span class="smallerbutton" style="width=58" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$ref2&form=6&db=$ncbi_type2&Dopt=f', '_blank')">Sequence</span>);
			$seq2_ncbi[1] = qq(<span class="smallerbutton" style="width=55" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref2&form=6&db=$ncbi_type2&Dopt=m', '_blank')">Abstract</span>);

		}
	}
}

sub error
{
	#argument(s): $error, $error_file
	my ($error, $error_file) = @_;
	open ERROR, ">$error_file";
	print ERROR "<html><body>";
	print ERROR "<span style='color:red'>$error<span>\n";
	print ERROR "</body></html>";
	close ERROR;
}