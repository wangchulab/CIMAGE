#!/usr/local/bin/perl

#-------------------------------------
#	FuzzyLauncher,
#	(C)1999 Harvard University
#	
#	C. J. Taubman/W. S. Lane/M. A. Baker
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
 
&cgi_receive;

$dif_tolerance = 1.0;
$dirname = $FORM{"directory"};
&MS_pages_header ("FuzzyLauncher", "#871F78");
print "<P><hr><P><P>\n";
&setup_js;
if(!defined $dirname) {
	&output_dir_form;
}
else {
	&output_dta_form;
}
&tail;
exit;



sub setup_js {
print <<FORMPAGE;

<SCRIPT LANGUAGE="Javascript">
<!--

function launchFuzzy() {
	var selected = document.forms[0].directory.options.selectedIndex;
	var gotoDta = document.forms[0].directory.options[selected].value;
	// the "escape" function in this line is necessary to prevent Javascript errors in Netscape4 (it doesn't like colons in CGI parameters)
	var gotoURL = "$webcgi/fuzzyions.pl?Dta=" + escape("$seqdir/$dirname/") + escape(gotoDta) + "&NumAxis=1";
	location.href=gotoURL;
}

//-->
</SCRIPT>
FORMPAGE
}

sub output_dir_form {
  print qq(<H4>Choose a directory:</H4>);
  print qq(<FORM ACTION="$ourname" METHOD=POST>);
 
  ##
  ## subroutine from microchem_include.pl
  ## that gets all the directory information
  ##
  &get_alldirs;

  # make dropbox:
  print ("<span class=dropbox><SELECT name=\"directory\">\n");

  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }
  print ("</SELECT></span>\n");

  print qq(<INPUT TYPE="SUBMIT" CLASS=button VALUE="Show" NAME="show">&nbsp;);
  print qq(</FORM>);
}

sub output_dta_form {
print qq(<H4>Choose a dta file:</H4>);
  print qq(<FORM ACTION="$ourname" METHOD=POST>);
  &get_all_dtas;

  # make dropbox:
  print ("<span class=dropbox><SELECT name=\"directory\">\n");

  foreach $dta (@dtas) {
    print qq(<OPTION VALUE = "$dta">$dta\n);
  }
  print ("</SELECT></span>\n");

  print qq(<INPUT TYPE="BUTTON" CLASS=button VALUE="Run Fuzzyions" NAME="show" onClick="launchFuzzy()">&nbsp;);
  print qq(</FORM>);
}

sub get_all_dtas {
	opendir(MYDIR,"$seqdir/$dirname");
   @dtas = grep /\.dta$/, readdir(MYDIR);
   closedir MYDIR;
}

##
## &tail
##
##      Prints copyright, attributions, and closing tags
##
sub tail {
  print ("</body></html>\n");
}
