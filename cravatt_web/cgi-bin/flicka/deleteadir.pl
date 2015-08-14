#!/usr/local/bin/perl

#-------------------------------------
#	Delete-A-Dir,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


##
## For muchem-specific definitions and cgilib routines
##
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
 
&cgi_receive();

&MS_pages_header("Dir de Dozen", "#871F78", "tabvalues=Delete-A-Dir&Clone-A-Dir:\"/cgi-bin/cloneadir.pl\"&Delete-A-Dir:\"/cgi-bin/deleteadir.pl\"&Combine-A-Dir:\"/cgi-bin/combineadir.pl\"&Rename-A-Dir:\"/cgi-bin/renameadir.pl\"&Search and Replace:\"/cgi-bin/searchreplace.pl\"");

# extensively comb "$dir"
($dir) = $FORM{"directory"} =~ m!^([A-Za-z0-9\-_]+)$!;

if ((!defined $dir) || ($dir eq "")) {
  &get_alldirs();
  &output_form();
  exit;
}

$num_checks = $FORM{"num_checks"};

if ($num_checks < 1) {
  &print_warning_form();
  exit;
}

opendir (DIR, "$seqdir/$dir");
@allfiles = grep !/^\.\.?$/, readdir DIR;
closedir DIR;
unlink map "$seqdir/$dir/$_", @allfiles;

$errcode = (rmdir "$seqdir/$dir") ? 0 : $!;

(@return) = &removefrom_flatfile ($dir);
$return = shift (@return);

#print ("<h3>Directory deleted...</h3>\n");
print "<div>\n";

if ($errcode) {
  print <<EOM;
<br><image src="/images/circle_1.gif">&nbsp;There were some problems while deleting the directory -
error code: $errcode.<br><br>

EOM
} else {
  print qq(<br><image src="/images/circle_1.gif">&nbsp;Directory deletion successful.<br><br>\n);
}

if ($return) {
  print <<EOM;
<br><image src="/images/circle_2.gif">&nbsp;There were some problems while removing the flatfile
entry - error message was &quot;<tt>@return</tt>&quot;<br>
EOM
} else {
  print qq(<image src="/images/circle_2.gif">&nbsp;Flatfile update successful.<br>\n);
}

@text = ("Setup Sequest Directory","Run Sequest", "Sequest Summary","View DTA Chromatogram");
@links = ("setup_dirs.pl","sequest_launcher.pl" , "runsummary.pl","dta_chromatogram.pl");
&WhatDoYouWantToDoNow(\@text, \@links);


sub print_warning_form {
  my ($fancyname) = &get_fancyname($dir);
  my (@files);
  my ($num_dtas, $num_outs);

  opendir (DIR, "$seqdir/$dir") || &error ("Unable to open directory $dir.");
  @files = readdir (DIR);

  $num_dtas = grep { m!\.dta$! } @files;
  $num_outs = grep { m!\.out$! } @files;
  
  $num_checks++;

  print <<EOM;
<p>

<div>
<FORM ACTION="$ourname" METHOD=POST>

<INPUT TYPE=HIDDEN NAME="directory" VALUE="$dir">
<INPUT TYPE=HIDDEN NAME="num_checks" VALUE="$num_checks">

<span class="smallheading">You have selected the directory</span><span style="color:#0000ff"> $dir</span> <span class="smallheading">for deletion</span>
<ul>
<li>This is $fancyname. 
<li>It has $num_dtas DTA files and $num_outs OUT files.
</ul>
<span class="smallheading">Are you sure you want to delete it? <br><br></span>

<INPUT TYPE=SUBMIT CLASS=button VALUE="Yes, I am really sure I want to Delete this.">&nbsp;&nbsp;
<a href = "$ourname"><span class="smalltext">No! Wait, what am I thinking?</span></a>
</FORM>
</div>

EOM
}


sub error {
  print ("<h2>Error:</h2>\n");
  print join ("\n", @_);
  exit 1;
}






sub output_form {

  print <<EOM;
<div>
<FORM ACTION="$ourname" METHOD=POST>

<span class=smallheading>Pick a directory to delete:</span><br><br>
EOM

  print qq(<span class=dropbox><SELECT NAME="directory">\n);
  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE="$dir">$fancyname{$dir}\n);
  }
  print ("</SELECT></span>\n");

  print <<EOM;

<p>
<INPUT TYPE=SUBMIT CLASS=button VALUE="Yes, I am really sure I want to delete this.">&nbsp;&nbsp;
<a href = "$HOMEPAGE"><span class="smalltext">No! Wait, what am I thinking?</span></a>

</FORM>
</div>
EOM
}
