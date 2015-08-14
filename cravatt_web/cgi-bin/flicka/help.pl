#!/usr/local/bin/perl
#-------------------------------------
#	Form Defaults Editor
#	(C)1999 Harvard University
#	
#	W. S. Lane/Vanko Vankov/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
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
}
################################################
#require "$form_defaults_file";
&MS_pages_header("Help", "BB8888");
print "<P><HR><P>\n";
&cgi_receive();
$helpfile = $FORM{"help"};
opendir THISDIR, "$helpdir" or die "some problem : $!";
@allfiles = readdir THISDIR;
closedir THISDIR;
foreach $list (@allfiles){
	if ($list =~ /^help_.*\.html$/)	{
		open FILE,"$helpdir/$list";
		$pattern =  '<TITLE>\s*(.*)</TITLE>';
		while ($line = <FILE>){
			if ($line =~ /$pattern/i){
				$line = $1;
				$line =~ s/help$//i;
				$filelist{$list} = $line;
				$filelistback{"$line"} = $list; # Kludge to sort by values in key instead of the key 
			}
		}
	}
}

#if(!defined $helpfile){
	&output_form;
#}

sub output_form {
	my $key;
	print <<EOF;
	<FORM METHOD=POST name=helpform>
	<TABLE CELLSPACING=0 CELLPADDING=4 BORDER=0>
	<TR><TD align=right><span class="smallheading">	Help Files:</span></TD><TD><span class=\"dropbox\"><SELECT name=\"help\">\n
EOF
	foreach $key (sort keys(%filelistback)) {
		chomp $key;
		print qq(<OPTION VALUE="$webhelpdir/$filelistback{$key}" >$key </OPTION>\n);
	}
	print <<EOF;
	</SELECT></span></TD><TD><INPUT name=subbutton TYPE=button class=button VALUE="View" Onclick="Openfile()";>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<A href=\"$webhelpdir/help_$ourshortname.html\">
	<span class="smallheading">Help</span></a></TD>
	</TR>
	</TABLE>
	</FORM>

<script language="Javascript">
<!--
function Openfile()
{
	window.navigate(document.helpform.help.value);
}
//-->
</script>
EOF
}