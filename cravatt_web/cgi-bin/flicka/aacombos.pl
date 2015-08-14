#!/usr/local/bin/perl

#-------------------------------------
#	Amino Acid Combinations,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
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
################################################
&cgi_receive();
#$pairurl = "$server/aapairs.txt";
#$tripurl = "$server/aatriplets.txt";
$DEFAULT_COLUMN_DIVISION = .51;  # distance from max tolerance at which columns are divided
$default_tolerance = $DEFS_AACOMBOS{"Mass +/-"};
&MS_pages_header("Amino Acid Combos", "#C0C0C0");
print "<hr>\n";
$tolerance = $FORM{"tolerance"} || $default_tolerance;
$mass = $FORM{"mass"};
$use_mono = $FORM{"MassType"};
if (!defined $use_mono) {
	$use_mono = 1 if ($DEFS_AACOMBOS{"Mono/Avg"} eq "Mono");
}
$unipeps = ($FORM{"unipeps"} ? "CHECKED" : undef);
$dipeps = ($FORM{"dipeps"} ? "CHECKED" : undef);
$tripeps = ($FORM{"tripeps"} ? "CHECKED" : undef);
$qpeps = ($FORM{"qpeps"} ? "CHECKED" : undef);

if (!$dipeps and !$tripeps and !$unipeps and !$qpeps) {
  $unipeps = "CHECKED" if ($DEFS_AACOMBOS{"Mono-residues"} eq "yes");
  $dipeps = "CHECKED" if ($DEFS_AACOMBOS{"Di-residues"} eq "yes");
  $tripeps = "CHECKED" if ($DEFS_AACOMBOS{"Tri-residues"} eq "yes");
  $qpeps = "CHECKED"; 
}
$highlight = $FORM{"highlight"};
$highlight =~ tr/a-z/A-Z/;
$highlight =~ tr/A-Z//cd;
undef ($highlight) if ($highlight eq "");

if (defined $mass) {
	# construct a reference to the array we will use:
	$MassArr = $use_mono ? \%Mono_mass : \%Average_mass;
	$cys_alkyl_add = $use_mono ? \%cys_alkyl_add_mono : \%cys_alkyl_add_average;
	$$MassArr{"C'"} = $$MassArr{"C"} + $$cys_alkyl_add{"CAM"};
	$$MassArr{"C''"} = $$MassArr{"C"} + $$cys_alkyl_add{"PA"};

	@AAs_by_mass = sort { $$MassArr{$a} <=> $$MassArr{$b} }
		  ("C'", "C''", 'G', 'A', 'S', 'P', 'V', 'T', 'C', 'I', 'L', 'N',
		   'D', 'Q', 'K', 'E', 'M', 'H', 'F', 'R', 'Y', 'W' );
	$numAAs = $#AAs_by_mass + 1;
	# if mass is in the form of letters, calculate the sum of the residues:
	$mass =~ tr/a-z/A-Z/;
	$dispstring = $mass;
	&output_form;

	if ($mass =~ m![A-Z\(\)]!) {
		my $realmass = 0;
		# take out parenthesized masses
		while ($mass =~ s!\((\d+\.?\d*)\)!!) {
			$realmass += $1;
			print "here :$realmass <br>";
			print $1;
		}
		foreach $let (split ("", $mass)) {
			$realmass += $$MassArr{$let};
		}
		$mass = &precision ($realmass, 2);
	}
	# otherwise, search the files for appropriate masses:
	$floor = $mass - $tolerance;
	$ceiling = $mass + $tolerance;

	if ($dipeps) {
	 OUTER:
	  for ($i = 0; $i < $numAAs; $i++) {
		$firstAA = $AAs_by_mass[$i];
		$mass1 = $$MassArr{$firstAA};
	  INNER:
		for ($j = $i; $j < $numAAs; $j++) {
		  $secondAA = $AAs_by_mass[$j];
		  $mass2 = $$MassArr{$secondAA};
		  $sum = $mass1 + $mass2;
		  next INNER if ($sum < $floor);
		  next OUTER if ($sum > $ceiling);
		  $seq = $firstAA . $secondAA;
		  $sum{$seq} = $sum;
		  $line{$seq} = join ("\t", $seq,  &precision ($sum, 2));
		  push (@dipeps, $seq);
		} # INNER
	  } # OUTER
	}

	if ($tripeps) {
	 OUTER:
	  for ($i = 0; $i < $numAAs; $i++) {
		$firstAA = $AAs_by_mass[$i];
		$mass1 = $$MassArr{$firstAA};

	  MIDDLE:
		for ($j = $i; $j < $numAAs; $j++) {
		  $secondAA = $AAs_by_mass[$j];
		  $mass2 = $$MassArr{$secondAA};

		INNER:
		 for ($k = $j; $k < $numAAs; $k++) {
		$thirdAA = $AAs_by_mass[$k];
		$mass3 = $$MassArr{$thirdAA};

		$sum = $mass1 + $mass2 + $mass3;
		next INNER if ($sum < $floor);
		next MIDDLE if ($sum > $ceiling);

		$seq = $firstAA . $secondAA . $thirdAA;
		$sum{$seq} = $sum;
		$line{$seq} = join ("\t", $seq,  &precision ($sum, 2));
		push (@tripeps, $seq);
		  } # INNER
		} # MIDDLE
	  } # OUTER
	}
	if ($qpeps) {
		OUTER:
		for ($i = 0; $i < $numAAs; $i++) {
		$firstAA = $AAs_by_mass[$i];
		$mass1 = $$MassArr{$firstAA};

		MIDDLE1:
		  for ($j = $i; $j < $numAAs; $j++) {
		  $secondAA = $AAs_by_mass[$j];
		  $mass2 = $$MassArr{$secondAA};

			MIDDLE2:
			for ($k = $j; $k < $numAAs; $k++) {
			$thirdAA = $AAs_by_mass[$k];
			$mass3 = $$MassArr{$thirdAA};

				INNER:
				for ($l = $k; $l < $numAAs; $l++) {
				$fourthAA = $AAs_by_mass[$l];
				$mass4 = $$MassArr{$fourthAA};

				$sum = $mass1 + $mass2 + $mass3 + $mass4;
				next INNER if ($sum < $floor);
				next MIDDLE2 if ($sum > $ceiling);
		
				$seq = $firstAA . $secondAA . $thirdAA . $fourthAA ;
				$sum{$seq} = $sum;
				$line{$seq} = join ("\t", $seq,  &precision ($sum, 2));
				push (@qpeps, $seq);
				} # INNER
			} # MIDDLE2
		 } # MIDDLE1
	  } # OUTER
	}

	##
	## include single amino acids if appropriate
	##
	## the following nightmare expression simply checks to see if
	## $floor is less than the heaviest amino acid.
	## 
	if ($unipeps) {
	  if ($floor <= $$MassArr{$AAs_by_mass[($numAAs - 1)]} ) {
		foreach $AA (@AAs_by_mass) {
		  $mass1 = $$MassArr{$AA};
		  next if ($mass1 < $floor);
		  last if ($mass1 > $ceiling);
		
		  push (@unipeps, $AA);
		  $sum{$AA} = $mass1;
		  $line{$AA} = "$AA\t" . &precision ($mass1, 2, 3, " ");
		}
	  }
	}
	  $header = "Pep\t   MW";
	@allpeps = (@unipeps, @dipeps, @tripeps, @qpeps);

	foreach $seq (@allpeps) {
		$prname{$seq} = "$seq";
	}
	

	## Bold certain amino acids if asked
	#### Account for C', C''.

	if (defined $highlight) {
	  foreach $seq (@allpeps) {
		$seqcolor = $seq;
		$seqcolor =~ s!([$highlight]'*)!<span style="color:red"><b>$1</b></span>!go;
		$prname{$seq} = "$seqcolor";
	  }
	}


	# THIS is called a HACK!
	# this will give us horizontal dividers at mass +/- 0.5 dalton.
	#$line{"lowend"} = qq(<span style="color:#C0C0C0">) . "-" x 37 . "</span>";
	$sum{"lowend"} = $mass - $DEFAULT_COLUMN_DIVISION;
	#$line{"highend"} = qq(<span style="color:#00ff00">) . "-" x 37 . "</span>";
	$sum{"highend"} = $mass + $DEFAULT_COLUMN_DIVISION;
	$sum{"givenmass"} = $mass;
	$line{"givenmass"} = "<b>****\t" . &precision ($mass, 2, 3, " ") . "</b>";

	@allpeps = sort { $sum{$a} <=> $sum{$b} } (@allpeps, "givenmass"); ###, "lowend", "highend", "givenmass"
	#print @allpeps;
	#print "<br>";
	#print %sum;
	$len = scalar @allpeps;
#	$size=int($len/3)+1;
#	for($i=0;$i<$size;$i++) {
#		push(@one,$allpeps[$i]);
#	}
#	for($i=$size;$i<2*$size;$i++) {
#		push(@two,$allpeps[$i]);
#	}
#	for($i=2*$size;$i<3*$size;$i++) {
#		push(@three,$allpeps[$i]);
#	}
	for ($i=0; $i<$len; $i++) {
		$cur = $allpeps[$i];
		if ($sum{$cur} <= $sum{"lowend"}) {
			push(@one,$allpeps[$i]);
		} elsif ($sum{$cur} >= $sum{"highend"}) {
			push(@three,$allpeps[$i]);
		} else {
			push(@two,$allpeps[$i]);
		}
	}
	

	print qq(<table border=0 cellspacing=0 cellpadding=10>);
	print qq(<tr valign=top><td bgcolor="#efefef" width=240 align=center>);
	print qq(<table border=0 cellspacing=0 cellpadding=0><tr><td align=left><span class=smallheading>AAs</span></td><td align=center><span class=smallheading>MW</span></td></tr><tr><td height=2 colspan=2 bgcolor=black><spacer type=block height=2></td></tr>);
	foreach $seq (@one) {
		$thismass = precision($sum{$seq}, 2);
		print qq(<tr><td width=65><span class=smallheading>$prname{$seq}</span></td><td align=right><span class=smallheading>$thismass</span></td></tr>);
	}
	print qq(</table>);
	print qq(</td><td bgcolor="#ffffff" width=240 align=center>);
	print qq(<table border=0 cellspacing=0 cellpadding=0><tr><td align=left><span class=smallheading>AAs</span></td><td align=center><span class=smallheading>MW</span></td></tr><tr><td height=2 colspan=2 bgcolor=black><spacer type=block height=2></td></tr>);
	foreach $seq (@two) {
		$thismass = precision($sum{$seq}, 2);
		if ($seq eq "givenmass") {
			# $prname{$seq} = "<span style=\"color:red\">----------></span>";
			$prname{$seq} = "<span style=\"font-family:symbol; color:red\">¾¾¾¾®</span>";
			$thismass = "<span style=\"color:red\">$thismass</span>";
		}
		print qq(<tr><td width=65><span class=smallheading>$prname{$seq}</span></td><td align=right><span class=smallheading>$thismass</span></td></tr>);
	}
	print qq(</table>);
	print qq(</td><td bgcolor="#efefef" width=240 align=center>);
	print qq(<table border=0 cellspacing=0 cellpadding=0><tr><td align=left><span class=smallheading>AAs</span></td><td align=center><span class=smallheading>MW</span></td></tr><tr><td height=2 colspan=2 bgcolor=black><spacer type=block height=2></td></tr>);
	foreach $seq (@three) {
		$thismass = precision($sum{$seq}, 2);
		print qq(<tr><td width=65><span class=smallheading>$prname{$seq}</span></td><td align=right><span class=smallheading>$thismass</span></td></tr>);
	}
	print qq(</table>);
	print qq(</td></tr></table>);


#	print qq(<table border=0 align=center cellspacing=0 cellpadding=10>);
#	print qq(<tr><td bgcolor="#dddddd"><pre>$header</pre></td><td><pre>$header</pre></td><td bgcolor="#dddddd"><pre>$header</pre></td></tr>);
#	print qq(<tr><td bgcolor="#dddddd" valign=top><pre>);
#	foreach $seq (@one){
#		$line = $line{$seq};
#		print ($line, "\n<br>");
#	}
#	print qq(</td></pre>);
#
#	print qq(<td valign=top><pre>);
#	foreach $seq (@two){
#		$line = $line{$seq};
#		print ($line, "\n<br>");
#	}
#	print qq(</pre></td><td bgcolor="#dddddd" valign=top><pre>);
#	foreach $seq (@three){
#		$line = $line{$seq};
#		print ($line, "\n<br>");
#	}
#	print qq(</pre></td></tr>);
#	print qq(</table>);

} else {	
	&output_form;
}

sub output_form {
  my ($mono, $avg);
  $mono = $use_mono ? "CHECKED" : "";
  $avg = !$use_mono ? "CHECKED" : "";
  $dispstring = $DEFS_AACOMBOS{"Mass"} if (!defined $dispstring);
  print <<EOM;
<script language="javascript">
<!--
function resfix(resid) {
	if (document.forms[0][resid].checked) {
		if (document.forms[0].r4.checked) {
			document.forms[0].r3.checked = true;
			document.forms[0].r2.checked = true;
			document.forms[0].r1.checked = true;
		} else if (document.forms[0].r3.checked) {
			document.forms[0].r2.checked = true;
			document.forms[0].r1.checked = true;
		} else if (document.forms[0].r2.checked) {
			document.forms[0].r1.checked = true;
		}
	} else {
		if (!document.forms[0].r1.checked) {
			document.forms[0].r2.checked = false;
			document.forms[0].r3.checked = false;
			document.forms[0].r4.checked = false;
		} else if (!document.forms[0].r2.checked) {
			document.forms[0].r3.checked = false;
			document.forms[0].r4.checked = false;
		} else if (!document.forms[0].r3.checked) {
			document.forms[0].r4.checked = false;
		}
	}
}
//-->
</script>
<table border=0 cellspacing=0 cellpadding=0>
<form action="$ourname" name="subform" method=GET>
<tr>
	<td valign=middle>
		<input type=submit class=button value="Search">
	</td><td width=48>&nbsp;</td><td valign=middle>
		<span class="smallheading">Mass:</span>
		<input name="mass" size=5 value="$dispstring"><tt>±</tt>
		<input name="tolerance" value="$tolerance" size=4>
		<input type=radio name="MassType" value="1" $mono onClick="document.subform.submit();"><span class="smallheading">Mono</span>
		<input type=radio name="MassType" value="0" $avg onClick="document.subform.submit();"><span class="smallheading">Avg</span>
	</td><td width=48>&nbsp;</td><td valign=middle>
		<span class="smallheading">Highlight:</span>
		<input name="highlight" size=8 value="$highlight" onKeyUp="javascript:this.value=this.value.toUpperCase();">
		<!--<INPUT TYPE=CHECKBOX NAME="dipeps" $dipeps><a href="$pairurl">Dipeptides</a>&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE=CHECKBOX NAME="tripeps" $tripeps><a href="$tripurl">Tripeptides</a>-->
	</td><td width=48>&nbsp;</td><td valign=middle>
		<span class="smallheading">Residues:</span>
		<input type=checkbox name="unipeps" id="r1" $unipeps onClick="resfix('r1')"><span class="smallheading">1</span>&nbsp;
		<input type=checkbox name="dipeps" id="r2" $dipeps onClick="resfix('r2')"><span class="smallheading">2</span>&nbsp;
		<input type=checkbox name="tripeps" id="r3" $tripeps onClick="resfix('r3')"><span class="smallheading">3</span>&nbsp;
		<input type=checkbox name="qpeps" id="r4" $qpeps onClick="resfix('r4')"><span class="smallheading">4</span>
	</td>
</tr>
</form></table><br>
EOM
}
