#!/usr/local/bin/perl

#-----------------------------------------------
# Project		: Neutral Loss Finder
# Description	: searches DTAs for neutral loss 
# Includes		:  	
# Requires		: "michrocem_include.pl"	
# Authors		: D. Toncheva, W. Lane, C. Wendl
# Version		: v3.1a
# Copyright		:(C) 1999 Harvard University	
# Comments		: 	
#----------------------------------------------


## site definitions
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
&cgi_receive;

&MS_pages_header("Neutral Loss Finder", "#9F9F5F");
# grab options
$dirname = $FORM{'directory'};
$error = $FORM{'error'};
$show = $FORM{'show'};
$percent = $FORM{ 'percent'};
$intensity = $FORM{'intensity'};
$tolerance = $FORM { 'tolerance'};
$enter_loss = $FORM { 'enter_loss' };
$neutral_loss = $FORM { 'neutral_loss'};
if (!defined $neutral_loss) {
	$neutral_loss = 98 if ($DEFS_NEUTRAL_LOSS_FINDER{"Choose the loss"} eq "H3PO4 - (98)");
	$neutral_loss = 80 if ($DEFS_NEUTRAL_LOSS_FINDER{"Choose the loss"} eq "H2PO3 - (80)");
	$neutral_loss = 64 if ($DEFS_NEUTRAL_LOSS_FINDER{"Choose the loss"} eq "Msx - (64)");
}
print "<P><HR>\n";
#print "enterloss   :$enter_loss<BR>";
#print "neutralloss   :$neutral_loss<BR>";
#if (!defined $dirname) {
	&output_form;
#}
#print "</FORM>\n";
#print "</body></html>\n";
#exit;

$dir="$seqdir/$dirname";  # this is somewhat insecure
if (defined $enter_loss) {
	$calcul_loss = $enter_loss;
}
else {
	$calcul_loss = $neutral_loss;
}
#print ("calculloss   :  $calcul_loss");
# log file
#open(LOG, ">> dta_banisher.log");
#$date=localtime(time);
#print LOG "$date\n";

# fast file glob
&read_data;

sub read_data {
	opendir CURRDIR, "$dir";
	@allfiles=readdir CURRDIR;
	closedir CURRDIR;
	# glob for *.2.dta
	@dta2files=grep(/^.*\.2\.dta$/, @allfiles);
	@dta3files=grep(/^.*\.3\.dta$/, @allfiles);
	# glob for all dta files -wsl 12/14
	@dtafiles=grep(/^.*\.dta*$/, @allfiles);
}
## PRESENTATION and status loop
# presentation header

if (defined $dirname) {
	print <<EOM;
	<TABLE CELLSPACING=2 CELLPADDING=2 BORDER=1>
	<TR ALIGN=CENTER>
	<br>
	<TD COLSPAN=4><B><A HREF="$webseqdir/$dirname"><img border=0  align=center src="$webimagedir/p_view_directory.gif"></A></B></TD>
	<TD COLSPAN=6><B>Relative Abundance (%)</B></TD>
	</TR>

	<TR ALIGN=CENTER>
	<TD><b>Scans</b></TD>
	<TD><b>&nbsp;z&nbsp;</b></TD>
	<TD><b>m/z</b></TD>
	<TD><b>MH+</b></TD>
	<TD><span style="color:blue">1+</span></TD>
	<TD><span style="color:blue">2+</span></TD>
	<TD><span style="color:blue">3+</span></TD>
	<TD><span style="color:blue">4+</span></TD>
	<TD><span style="color:blue">5+</span></TD>
	<TD><span style="color:blue">6+</span></TD>
	</TR>
EOM

	print "<form action=\"$ourname\" method=post>\n";
	print qq(<input type="hidden" name="directory" value="$dirname">);

# status loop through @dtafiles
@dtapairs = (); # initialize, changed from a string to an array thomas 12/16/97
PRV: foreach $dtafile (@dtafiles) {
$dtabase=$dtafile; $dtabase=~s/\.\d\.dta$//; # base for all filenames

  # skip if the .3.dta pair
  #next PRV if grep(/^$dtafile$/, @dtapairs);
  
  # some filenames
$dta2file = $dtabase . ".2.dta";
$dta3file = $dtabase . ".3.dta";
($mhplus, $charge, $highion, $highion2, $highion3, $highion4, $highion5, $highion6, $precursor) = &read_dta($dtafile, $error, $intensity);

  $scans=$dtabase;
  $scans=~s/[\w|\d|\-]+\.(\d+)\.(\d+)/$1-$2/; # remove hyphens, prefix
  
  #checks if the user wants all the directories displayed
    if($show==1) {
	if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4 != 0) || ($highion5 != 0) ||($highion6 !=0)) {
		    print "<tr><TD nowrap align=center><tt>&nbsp;<a target=_blank href=\"$fuzzyions?Dta=$dir/$dtafile&interior_ions&interior_ions_on=PH&
specialloss_on=on&specialloss=phosphate&b-ions=CHECKED&y-ions=CHECKED&ladders=on&ion_to_jump_to=Y\">$scans</a>&nbsp;</tt></td>\n";
      
      }
   }
if ($show==0) {
	print "<tr><TD nowrap align=center><tt>&nbsp;<a target=_blank href=\"$fuzzyions?Dta=$dir/$dtafile&interior_ions&interior_ions_on=PH&
	specialloss_on=on&specialloss=phosphate&b-ions=CHECKED&y-ions=CHECKED&ladders=on&ion_to_jump_to=Y\" >$scans</a>&nbsp;</tt></td>\n";
}
if ($show == 2) {
	if(($highion>= $percent) ||($highion2>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion5 >= $percent)||($highion6 >=$percent)) {
		print "<tr><TD nowrap align=center><tt>&nbsp;<a  target=_blank href=\"$fuzzyions?Dta=$dir/$dtafile&interior_ions&interior_ions_on=PH&
		specialloss_on=on&specialloss=phosphate&b-ions=CHECKED&y-ions=CHECKED&ladders=on&ion_to_jump_to=Y\">$scans</a>&nbsp;</tt></td>\n";
	}
}
   
if($show==1) {
	if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4 != 0)|| ($highion5 != 0)||($highion6 !=0)) {
		print "  <td align=center><tt>$charge</tt></td>\n";
    }
} 
if ($show == 0) {
	print "  <td align=center><tt>$charge</tt></td>\n";
}
if ($show == 2) {
	if(($highion>= $percent) ||($highion2>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion5 >= $percent)||($highion6 >=$percent)) {
  		print "  <td align=center><tt>$charge</tt></td>\n";
    }
}
  
$precursor=&precision($precursor, 2);
if ($precursor<1000) {
    $precursor="&nbsp;$precursor";
}
  
if($show==1) {
	if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4 != 0)|| ($highion5 != 0)||($highion6 !=0)) {
  		print "  <td><tt>&nbsp;$precursor&nbsp;</tt></td>\n";
    }
} 
if ($show==0) { 
	print "  <td><tt>&nbsp;$precursor&nbsp;</tt></td>\n";
}	
if ($show==2) {
	if(($highion>= $percent) ||($highion2>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion5 >= $percent)||($highion6 >=$percent)) {
		print "  <td><tt>&nbsp;$precursor&nbsp;</tt></td>\n";
	}
}
 
$mhplus=&precision($mhplus, 2);
if ($mhplus<1000) {
    $mhplus="&nbsp;$mhplus";
}

if($show==1) {
	if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4 != 0)|| ($highion5 != 0)||($highion6 !=0)) {
		print "  <td><b><tt>&nbsp;$mhplus&nbsp;</tt></b></td>\n";	   
    }
}
if ($show == 0) {
	print "  <td><b><tt>&nbsp;$mhplus&nbsp;</tt></b></td>\n";
   }
if ($show==2) {
	if(($highion>= $percent) ||($highion2>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion5 >=$percent)||($highion6 >=$percent)) {
	print "  <td><b><tt>&nbsp;$mhplus&nbsp;</tt></b></td>\n";
	}
}

  
  #prints out the 1+intensity
  #if the user needs only the nonzero files to be printed

if ($show==1) { 
	if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4 != 0)|| ($highion5 != 0)||($highion6 !=0)) {
		if ($highion >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion&nbsp;</tt></b></td>\n";
        }
		else {
			print "<td align=right><tt>&nbsp;$highion&nbsp;</tt></td>\n";
		}
	}
} 
#if all the files have to be printed

if ($show == 0) {
	if ($highion >= $percent) {    
		print "<td align=right><b><tt>&nbsp;$highion&nbsp;</tt></b></td>\n";
    }
	else {
		print "<td align=right><tt>&nbsp;$highion&nbsp;</tt></td>\n";
	}
}
# only the files in which the percent loss is above
# the percent limit are printed
if ($show ==2) {
	if ($highion >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion&nbsp;</tt></b></td>\n";
 	}
	if ($highion < $percent) {
		if(($highion2>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion5 >=$percent)||($highion6 >=$percent)) {
			#$highion = ' ';
 			print "<td align=right>&nbsp;</td>\n";
		}
	}
}

  
  # prints out the 2+ intensity
  #  
if ($show== 1) { 
	if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4 != 0)|| ($highion5 != 0)||($highion6 !=0)) {
  		if ($highion2 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion2&nbsp;</tt></b></td>\n";
        }
		else {
			print "<td align=right><tt>&nbsp;$highion2&nbsp;</tt></td>\n";
		}
    }
} 
if ($show == 0) {
	if ($highion2 >= $percent) {    
		print "<td align=right><b><tt>&nbsp;$highion2&nbsp;</tt></b></td>\n";
    }
	else{
		print "<td align=right><tt>&nbsp;$highion2&nbsp;</tt></td>\n";
	}	
}
if ($show == 2) {
	if ($highion2 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion2&nbsp;</tt></b></td>\n";
 	}
	if ($highion2 < $percent) {
		if(($highion>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion5 >=$percent)||($highion6 >=$percent)) {
			$highion2 = ' ';
 			print "<td align=right><tt>&nbsp;$highion2&nbsp;</tt></td>\n";
		}
	}

}

 
  # prints out the 3+ intensity
    
if ($show == 1) { 
	if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)|| ($highion4 != 0)|| ($highion5 != 0)||($highion6 !=0)) {
 		if ($highion3 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion3&nbsp;</tt></b></td>\n";
		}else {
			print "<td align=right><tt>&nbsp;$highion3&nbsp;</tt></td>\n";
		}
    }
} 
if ($show == 0) {
	if ($highion3 >= $percent) {    
		print "<td align=right><b><tt>&nbsp;$highion3&nbsp;</tt></b></td>\n";
    }else{
		print "<td align=right><tt>&nbsp;$highion3&nbsp;</tt></td>\n";
	}
}
if ($show == 2) {
	if ($highion3 >= $percent) {    
		print "<td align=right><b><tt>&nbsp;$highion3&nbsp;</tt></b></td>\n";
 	}
	if ($highion3 < $percent) {
		if(($highion2>= $percent)|| ($highion>=$percent)||($highion4 >= $percent)|| ($highion5 >=$percent)||($highion6 >=$percent)) {
			print "<td align=right><tt>&nbsp;</tt></td>\n";
		}
	}

}

  
  #prints out the 4+intensity
if ($show==1) { 
    if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4!=0)||($highion5!=0)||($highion6 !=0)) {
		if ($highion4 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion4&nbsp;</tt></b></td>\n";
        }
		else {
			print "<td align=right><tt>&nbsp;$highion4&nbsp;</tt></td>\n";
		}
	}
} 
if ($show == 0) {
	if ($highion4 >= $percent) {    
		print "<td align=right><b><tt>&nbsp;$highion4&nbsp;</tt></b></td>\n";
    } else {
		print "<td align=right><tt>&nbsp;$highion4&nbsp;</tt></td>\n";
	}
}
if ($show == 2) {
	if ($highion4 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion4&nbsp;</tt></b></td>\n";
 	}
if ($highion4 < $percent) {
		if(($highion2>= $percent)|| ($highion3>=$percent)||($highion >= $percent)|| ($highion5 >=$percent)||($highion6 >=$percent)) {
	
 		print "<td align=right><tt>&nbsp;</tt></td>\n";
		}
	}

}
 #prints out the 5+intensity
  if ($show==1) { 
      if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4!=0)||($highion5!=0)||($highion6 !=0)) {
 		if ($highion5 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion5&nbsp;</tt></b></td>\n";
            } else {
			print "<td align=right><tt>&nbsp;$highion5&nbsp;</tt></td>\n";
		}
      }
  } 
 if ($show==0) {
  		if ($highion5 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion5&nbsp;</tt></b></td>\n";
            } else {
 			print "<td align=right><tt>&nbsp;$highion5&nbsp;</tt></td>\n";
		}


  }
if ($show == 2) {
	if ($highion5 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion5&nbsp;</tt></b></td>\n";
	}
	if ($highion5 < $percent) {
		if(($highion2>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion >=$percent)||($highion6 >=$percent)) {
	 			print "<td align=right>&nbsp;</td>\n";
		}
	}
}
#prints out the 6+intensity
  if ($show==1) { 
      if(($highion!=0) ||($highion2!=0)|| ($highion3!=0)||($highion4!=0)||($highion5!=0)||($highion6 !=0)) {
		if ($highion6 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion6&nbsp;</tt></b></td>\n";
            } else {
			print "<td align=right><tt>&nbsp;$highion6&nbsp;</tt></td>\n";
		}	
	}
  } 
 if ($show == 0) {
		if ($highion6 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion6&nbsp;</tt></b></td>\n";
            } else {
			print "<td align=right><tt>&nbsp;$highion6&nbsp;</tt></td>\n";
		}	
  }
if ($show == 2) {
	if ($highion6 >= $percent) {    
			print "<td align=right><b><tt>&nbsp;$highion6&nbsp;</tt></b></td>\n";
	
	}

	if ($highion6 < $percent) {
		if(($highion2>= $percent)|| ($highion3>=$percent)||($highion4 >= $percent)|| ($highion5 >=$percent)||($highion >=$percent)) {
			$highion6=' ';		
 			print "<td align=right><tt>&nbsp;$highion6&nbsp</tt></td>\n";
		}
	}

}

}
print "</table>";

sub read_dta {
  my($dtafile)=@_;
  my(@temp, @datax, @data3, @firstline, @lastline, $highion, $highion2, $highion3, $highion4, $highion5, $highion6,
  $mz2, $mz3, $mz4, $mz5, $mz6, $loss, $loss2, $loss3, $loss4, $loss5, $loss6, 
  $i, $check, $dta3file, $dta2file, $mhplus, $charge, $precursor, $mass, $mass2, 
  $mass3, $mass4, $mass5, $mass6, $error2, $error3, $error4, $error5, $error6, $toler);

  $dta4file=$dtabase . ".4.dta";
  $dta3file=$dtabase . ".3.dta";
  $dta2file=$dtabase . ".2.dta";
  $dta1file=$dtabase . ".1.dta";

  open DTA, "$dir/$dtafile"; @datax=<DTA>; close DTA;
  @firstline=split(' ', $datax[0]);
  $mass=0;
  $highion=0;
  $highion2=0;
  $highion3=0;
  $highion4=0;
  $highion5=0;
  $highion6=0;
  $maxinten=0;
# if the tolerance is absolute then the error
# should be the same for all calculations.
# else for different charges the error is 
# devided by the charge.
	
  if ($tolerance) {
	$error2 = $error;
 	$error3 = $error;
	$error4 = $error;
	$error5 = $error;
	$error6 = $error;
  } else {
	$error2 = $error/2;
 	$error3 = $error/3;
	$error4 = $error/4;
	$error5 = $error/5;
	$error6 = $error/6;
  }	
 # calculates the loss for the different charges

 $loss = $firstline[0] - $calcul_loss;
  if ($firstline[1]>1) {
  	$mz2=(($firstline[0] - 1)/2)+1;
  	$loss2 = $mz2 - ($calcul_loss/2);
  }
  if($firstline[1]>2) {
  	$mz3=(($firstline[0] - 1)/3)+1;
	$loss3 = $mz3 - ($calcul_loss/3);
  }
  if($firstline[1]>3) {
  	$mz4=(($firstline[0] - 1)/4)+1;
	$loss4 = $mz4 - ($calcul_loss/4);
  }
  if($firstline[1]>4) {
  	$mz5=(($firstline[0] - 1)/5)+1;
	$loss5 = $mz5 - ($calcul_loss/5);
  }
  if($firstline[1]>5) {
  	$mz6=(($firstline[0] - 1)/6)+1;
	$loss6 = $mz6 - ($calcul_loss/6);
  }

# if the maximum intensity is needed
#checks for all the intensities and find the max

if ($intensity) {			 
  LINE: for $i (1..$#datax) {
	@temp = split(' ', $datax[$i]);
	$check= $temp[0];
	if ($maxinten < $temp[1]) {
		$maxinten=$temp[1];
      }
	if(($check - $loss)>=-$error) {
			if(($check - $loss)<=$error) {
				if($highion < $temp[1]) {
					$highion=$temp[1];
			      }
			}
	}
	if ($firstline[1]>1) {
		if(($check - $loss2)>=-$error2) {
			if(($check - $loss2)<=$error2) {
				if ($highion2 < $temp[1]) {
					$highion2 = $temp[1];
				}
			}
		}
	}
      if ($firstline[1]>2) {
		if(($check - $loss3)>=-$error3) {
			if(($check - $loss3)<=$error3) {
				if($highion3 < $temp[1]) {	
					$highion3 = $temp[1];
				}
			}
		}
	}
      if ($firstline[1]>3) {
		if(($check - $loss4)>=-$error4) {
			if(($check - $loss4)<=$error4) {
				if($highion4 < $temp[1]) {	
					$highion4 = $temp[1];
				}
			}
		}
	}
	if ($firstline[1]>4) {
		if(($check - $loss5)>=-$error5) {
			if(($check - $loss5)<=$error5) {
				if($highion5 < $temp[1]) {	
					$highion5 = $temp[1];
				}
			}
		}
	}
      if ($firstline[1]>5) {
		if(($check - $loss6)>=-$error6) {
			if(($check - $loss6)<=$error6) {
				if($highion6 < $temp[1]) {	
					$highion6 = $temp[1];
				} 
			}		
		}
	}

      last LINE if (($check - $loss)> $error);
		 
  }
} 

#if the sum of all intensities is needed
#finds the intensities that are in between the 
# tolerance and sums them

if (!$intensity) {
  LINE: for $i (1..$#datax) {
	@temp = split(' ', $datax[$i]);
	$check= $temp[0];
	if ($maxinten < $temp[1]) {
		$maxinten=$temp[1];
      }
	if(($check - $loss)>=-$error) {
			if(($check - $loss)<=$error) {
					$highion+=$temp[1];
			}
	}
	if ($firstline[1]>1) {
		if(($check - $loss2)>=-$error2) {
			if(($check - $loss2)<=$error2) {
					$highion2+= $temp[1];
			}
		}
	}
      if ($firstline[1]>2) {
		if(($check - $loss3)>=-$error3) {
			if(($check - $loss3)<=$error3) {
					$highion3+= $temp[1];
			}
		}
	}
      if ($firstline[1]>3) {
		if(($check - $loss4)>=-$error4) {
			if(($check - $loss4)<=$error4) {
					$highion4+=$temp[1];
			}
		}
	}
	if ($firstline[1]>4) {
		if(($check - $loss5)>=-$error5) {
			if(($check - $loss5)<=$error5) {
					$highion5+=$temp[1];
			}
		}
	}
      if ($firstline[1]>5) {
		if(($check - $loss6)>=-$error6) {
			if(($check - $loss6)<=$error6) {
					$highion6+=$temp[1];
			}		
		}
	}

      last LINE if (($check - $loss)> $error);
		 
  }
} 

# calculates the percent and converts into an integer
	
if ($highion > 0) {
	$highion = int (($highion*100)/$maxinten);	
}
if ($highion2 > 0) {
	$highion2 = int (($highion2*100)/$maxinten);	
}
if ($highion3 > 0) {
	$highion3 = int (($highion3*100)/$maxinten);	
}
if ($highion4 > 0) {
	$highion4 = int (($highion4*100)/$maxinten);	
}
if ($highion5 > 0) {
	$highion5 = int (($highion5*100)/$maxinten);	
}
if ($highion6 > 0) {
	$highion6 = int (($highion6*100)/$maxinten);	
}

$highion=' ' unless ($highion > 0);
$highion2=' ' unless ($highion2 > 0);
$highion3=' ' unless ($highion3 > 0);
$highion4=' ' unless ($highion4 > 0);
$highion5=' ' unless ($highion5 > 0);
$highion6=' ' unless ($highion6 > 0);

  @lastline=split(' ', $datax[1]);
  $mhplus=$firstline[0];
  $charge=$firstline[1];
  #print "charge3 : $charge<br>";
  $precursor = ( ($mhplus - $Mono_mass{'Hydrogen'}) / $charge) + $Mono_mass{'Hydrogen'};
  return($mhplus, $charge, $highion, $highion2, $highion3, $highion4, $highion5, $highion6, $precursor);
}
}

sub output_form {

	#saves the values of the parameters as entered by the user
	$selected{"98"} = " SELECTED" if ($neutral_loss == 98);
	$selected{"80"} = " SELECTED" if ($neutral_loss == 80);
	$selected{"64"} = " SELECTED" if ($neutral_loss == 64);
	#$enter_loss = "" unless (defined $enter_loss);
	$error = $DEFS_NEUTRAL_LOSS_FINDER{"Tolerance"} unless (defined $error);
	$percent = $DEFS_NEUTRAL_LOSS_FINDER{"Percent limit"} unless (defined $percent);
	if ($dirname) {
		$checked{"Max"} = " CHECKED" if ($intensity eq 1);
		$checked{"Sum"} = " CHECKED" if ($intensity eq 0);
		$checked{"Absolute"} = " CHECKED" if ($tolerance eq 1);
		$checked{"By Charge"} = " CHECKED" if ($tolerance eq 0);
		$checked{"All"} = " CHECKED" if ($show eq 0);
		$checked{"Nonzero"} = " CHECKED" if ($show eq 1);
		$checked{"By %limit"} = " CHECKED" if ($show eq 2);
		$selected{$dirname} = " SELECTED";
	}else {
	    $checked{$DEFS_NEUTRAL_LOSS_FINDER{"Intensity"}} = " CHECKED";
		$checked{$DEFS_NEUTRAL_LOSS_FINDER{"Absolute/By Charge"}} = " CHECKED";
	    $checked{$DEFS_NEUTRAL_LOSS_FINDER{"Show"}} = " CHECKED";
    
	}
	print qq(<FORM ACTION="$ourname" METHOD=POST NAME=neutralloss>);
	&get_alldirs;
	print qq(<TABLE CELLSPACING=2 BORDER=0><TR><TD ALIGN="right"><span class="smallheading">Directory :&nbsp;</span></TD>);
	print qq(<td><span class=\"dropbox\"><SELECT name=\"directory\">);
	foreach $dir (@ordered_names) {
		print qq(<option value="$dir"$selected{$dir}>$fancyname{$dir}\n);
	}
	print ("</SELECT></span></td></tr>");
	print <<EOM;
	<TD ALIGN="right"><span class="smallheading">Choose the loss:&nbsp;</span></TD>
	<TD>
	<span class="dropbox"><SELECT NAME="neutral_loss" OnChange="Clearnum()";>
	<OPTION VALUE =98 $selected{"98"} >H3PO4 - (98)
	<OPTION VALUE =80 $selected{"80"}>H2PO3 - (80)
	<OPTION VALUE = 64 $selected{"64"}>Msx - (64)
	</SELECT></span>&nbsp;&nbsp; <span class="smallheading"> enter a number:</span>
	<INPUT NAME="enter_loss" VALUE="$enter_loss" SIZE=3></TD></TR>
	<TR><TD ALIGN="right"><span class="smallheading">Tolerance:&nbsp;</span></TD>	
	<TD><INPUT NAME="error" VALUE="$error" SIZE=3>&nbsp;&nbsp;
	<INPUT NAME="tolerance" TYPE=RADIO VALUE=1 $checked{"Absolute"}><span class="smallheading">Absolute</span>&nbsp; 
	<INPUT NAME="tolerance" TYPE=RADIO VALUE=0 $checked{"By Charge"}><span class="smallheading">By Charge </span>

	</TD>
	</TR>
	<TR>
	<TD ALIGN="right"><span class="smallheading">Percent limit:&nbsp;</span></TD>
	<TD><INPUT NAME="percent" VALUE="$percent" SIZE=2>&nbsp;&nbsp;
	<span class="smallheading">Show:</span>
	<INPUT NAME="show" TYPE=RADIO VALUE=2$checked{"By %limit"}><span class="smallheading">By %limit</span>&nbsp;&nbsp;	
	<INPUT NAME="show" TYPE=RADIO VALUE=1$checked{"Nonzero"}><span class="smallheading">Nonzero</span>&nbsp;&nbsp;
	<INPUT NAME="show" TYPE=RADIO VALUE=0$checked{"All"}><span class="smallheading">All</span> &nbsp;&nbsp;
	</B>
	</TD>
	</TR>
	<TR>
	<TD ALIGN="right"><span class="smallheading">Intensity:&nbsp;</span></TD>
	<TD>
	<INPUT NAME="intensity" TYPE=RADIO VALUE=1$checked{"Max"}><span class="smallheading">Max </span>&nbsp;&nbsp;
	<INPUT NAME="intensity" TYPE=RADIO VALUE=0$checked{"Sum"}><span class="smallheading">Sum</span>
	</TD>
	</TR>
	<TR><TD>&nbsp;</TD><TD><input type="submit" class="button" value="Find" name="enter">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="$webhelpdir/help_$ourshortname.html" target="_blank"><span class="smallheading">Help</a></span></TD></TR>
	</TABLE>
	</FORM>
<SCRIPT language="javascript">
function Clearnum()
{
document.neutralloss.enter_loss.value="";
}
</SCRIPT>

EOM
}
