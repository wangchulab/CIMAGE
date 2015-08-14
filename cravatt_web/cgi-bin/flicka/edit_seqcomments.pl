#!/usr/local/bin/perl

#-------------------------------------
#	Sequest Params Text Editor,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# a simple editor for comments in Header.txt that simply uses a <TEXTAREA> to hold and
# edit the file

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
&MS_pages_header ("Sequest Comments Editor", "#9F9F5F");
print "<HR><P>";

# define varaibles (if $dir doesn't get directory output dropbox)

$dir = $FORM{"directory"};
if (!defined $dir) {
  &output_dropbox;
  exit;
}

$file = "$seqdir/$dir/header.txt";

###################### ADD COMMENT CONVERSION 
# this method is taken directly from view_info.pl

if (open (HEADER, "$file")) {
	my $firstline = <HEADER>;
	if ($firstline !~ /:/) {
		@names = split /:/, $samplelist_firstline;
		@entries = ($firstline, <HEADER>);
		chomp @entries;
		for ($i = 0; $i <= $#names; $i++) {
			$entry{$names[$i]} = $entries[$i];
		}
	} else {
		@names = ();
		foreach $line ($firstline, <HEADER>) {
			chomp $line;
			$line =~ /([^:]*):([^:]*)/;
			($key = $1) =~ tr/A-Z/a-z/;
			push(@names,$key);
			$entry{$key} = $2;
		}
	}
	close HEADER;
} else {
	print <<EOF;
	<H4 style="color:#800000">The file $file is either inaccessible or nonexistent.</H4>
	</body></html>
EOF
	exit;
}

$comments = $entry{"comments"};

if ($comments) {
	$comments =~ s/<BR><I>cloned<\/I><BR>/!SPLIT!/g;
	$comments =~ s/<br>/\n/g;	   # replace all remaining <br> tag with \n
	$comments =~ s/<COLON>/:/g;	   # can't allow colons normally because they're used as delimiters in header.txt and SAMPLELIST
	@fields = split /!SPLIT!/, $comments;
} else {
	$comments = "No Comments";	
}

###################################### If data has not yet been posted then the following function does so. 
# If the data has been posted and this program is running again then user chose to save changes, so save them.

my $a, $b;
for ($a; $a <= ($#fields+1); $a++) {
  $b=$a+1;
  if ($FORM{"$b"} ne "") {$newfields[$a] = $FORM{"$b"}; }
}

if ($newfields[0] eq "") {
  &output_form;
  exit;
}

$operator = $FORM{"operator"};
if (!defined $operator) {
	&error("You must type your initials in the Operator field.");
}
$operator =~ tr/A-Z/a-z/;

$comments = join(" cloned: ", @newfields);


# backup Header.txt to Header.txt.old.txt 
copy("$file", "$file.old.txt");


# clean up for HTML:
$comments =~ s/&/&amp;/g;
$comments =~ s/>/&gt;/g;
$comments =~ s/</&lt;/g;  
$comments =~ s/\"/&quot;/g;
$comments =~ s/\r//g;			# remove all carriage returns (necessary only for Windows OS?)
$comments =~ s/\n/<br>/g;	      # replace all newlines with the <br> tag
$comments =~ s/ cloned: /<BR><I>cloned<\/I><BR>/g;   #replace 'cloned:' in text with HTML version
$comments =~ s/:/<COLON>/g;		# can't allow colons because they're used as delimiters in header.txt and SAMPLELIST


###################################################### actually save the page & the log

open (FILE, "$file") || (print ("<h3>ERROR: Unable to save.</h3>") && exit);
@filestuff = <FILE>;

my $a;
for ($a; $a <= $#filestuff; $a++) {
  if (@filestuff[$a] =~ /Comments/) {$filestuff[$a] = "Comments:" . $comments; }
}

close FILE;

open (FILEa, ">$file") || (print ("<h3>ERROR: Unable to save.</h3>") && exit);
$filewrite = join ("", @filestuff); 
print FILEa $filewrite;
close FILEa;

### write in log
open(LOG,"<$seqdir/$dir/$dir.log");
@loglines = <LOG>;
close(LOG);

$timestamp = &get_timestamp();
$newline = "Comments edited" . " " . $timestamp . " " . $operator . "\n";
push(@loglines, "$newline");
$newlog = join("", @loglines);

open (FILEb, ">$seqdir/$dir/$dir.log");
print FILEb $newlog;
close FILEb;


### output page that comments have been saved

$comments =~ s/cloned<\/I><BR>/<span style="color:0000ff">cloned: <\/span><\/I>/g;
$comments =~ s/<COLON>/:/g;	   # can't allow colons normally because they're used as delimiters in header.txt and SAMPLELIST

print "\n<div> <h5>File has been saved.</h5>\n\n";

print <<EOF;
(Use the back button to return to whatever you were doing. 
<br> If you changed the comments remember to refresh the screen.)
<p> (backup of comments exists in <a href="$webseqdir/$dir/header.txt.old.txt">header.txt.old.txt</a>)
<h5>Comments are:</h5> $comments
EOF

print "</div></body></html>\n";

exit;

############################################################# OUTPUT FORM (or dropbox)

sub output_form {

# this variable determines amount of rows that are given per text area
$rows = 5;

print "<div><FORM ACTION=\"$ourname\" METHOD=POST>\n";

my $a;
for ($a; $a <= ($#fields); $a++) {
  # if ($a==($#fields+1)) {print "<p>Additional info:<br>"; } #preliminary method for add info
  # if ($a!=($#fields+1) && ($a!=0)) {print "<p>Cloned:<br>"; }

  if ($a!=0) {print "<br><i><span style=\"color:0000ff\">cloned: </span></I><br>"; }
  $name=$a+1;
  print "<tt><TEXTAREA ROWS=$rows COLS=100 WRAP=VIRTUAL NAME=\"$name\">$fields[$a]</TEXTAREA></tt>\n";
}

print <<EOF2;
  <br><b>Operator:</b> <INPUT NAME="operator" SIZE=3> &nbsp;&nbsp;&nbsp;&nbsp; 
  <INPUT TYPE=SUBMIT CLASS=button VALUE="Save"> &nbsp;&nbsp;&nbsp;&nbsp;
  <INPUT TYPE=RESET CLASS=button VALUE="Revert"> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <b>Directory: &nbsp;&nbsp; $dir </b>\n
  <INPUT TYPE=HIDDEN NAME="directory" VALUE="$dir">
  </FORM></div>
EOF2

exit;
}


# output a dropbox for the user to pick a directory in which to edit comments

sub output_dropbox {

print <<EOF;
  <b>Pick a directory:</b>
  <FORM ACTION="$ourname" METHOD=POST>
  <span class=dropbox><SELECT NAME="directory">
EOF

&get_alldirs;            # get directory information

foreach $dir (@ordered_names) {
  print ("<OPTION VALUE = \"$dir\">$fancyname{$dir}\n");
}

print <<EOF;
  </SELECT></span><INPUT TYPE=SUBMIT CLASS=button VALUE="GO!"></FORM>
EOF

}

sub error {

print <<EOF;

<H3>Error:</H3>
<div>
@_
</div>
</body></html>
EOF

exit 0;
}
