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
	$0 =~ m!(.*)\\([^\\]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################


require "$form_defaults_file";
#$incdir = "//WEBSERVER/documents/ben/inetpub/etc";

&MS_pages_header("Form Defaults Editor", "BB8888");
print "<HR><P>\n";

&cgi_receive();

open (HASHES, "<$incdir/$form_defaults_file") || &error("Can't open file $form_defaults_file");
@infile = <HASHES>;
close HASHES;
$vars_code = join("", @infile);
@blocks = split(/\n\s*#+\s*APPLICATION:\s*/, $vars_code);
shift @blocks;
foreach $block (@blocks) {
	$block =~ s/(.*)//;
	my $appname = $1;
	if ($appname =~ s/\s*#+\s*FILENAME:\s*(.*)//) {
		$path = $1;
	} else {
		undef($path);
	}
	$appname =~ s/ *$//;
	$path{$appname} = $path if ($path);
	$code{$appname} = $block;
}


$do_app = $FORM{"app2do"};
$set_vars = $FORM{"set_vars"};
if (!$do_app && !$set_vars)   {&output_form;}
elsif ($do_app && !$set_vars) {&input_defaults_new;}
elsif ($do_app && $set_vars)  {&umcvar;}


sub input_defaults_new {
	my $comment;
	my $options;
	my @hashes = $code{$do_app} =~ /%(\w*) *=/g;

	&load_java_checkblanks;
	if (defined $path{$do_app}) {
		print qq(<b><a href="$webcgi/$path{$do_app}" target=_blank>$do_app</a></b><p>);
	} else {
		print "<b>$do_app</b><p>";
	}
	print "<FORM ACTION=\"$ourname\" METHOD=get>";
	foreach $hash (@hashes) {
		print "<table cellpadding=0 cellspacing=0 border=0>\n";
     	(my $hashcode) = $code{$do_app} =~ /\%$hash\s*=(.*?)\n\);/s;
		(my @lines) = split (/\n/, $hashcode);
		LINE: foreach $line (@lines) {
			(my $comment);
			(my $key) = $line =~ /\A\s*['"]([^'"]*).*['"]/;
			($comment) = $line =~ /\A\s*#+(.*)/ if (!$key);
			if ($comment) {
				print "<tr><td colspan=2><I>$comment</I></td></tr>";
				next LINE;	
			}
			next LINE if (!$key);
			(my $default) = $line =~ /^\s*['"][^"']*['"][^"']*['"]([^"']*)/;
			(my $endline = $line) =~ s/^\s*['"][^"']*['"][^"']*['"]([^"']*)//;
			(my $display_t) = $endline =~ /^[^#]*#+\s*(\w*)/;
			$display_t =~ tr/a-z/A-Z/;
			if ($display_t eq "LIST" || $display_t eq "RADIO") {
				(my $options) = $endline =~ /^[^#]*#[^"]*(.*)/;
				(@options) = $options =~ /"([^"]*)"/g;
			}			

			if ($display_t eq "LIST") {
				print "<tr><td valign=top>$key&nbsp;&nbsp;</td>\n";
				print "<td valign=top><span class=dropbox><SELECT NAME=\"$key\{\}$hash\" VALUE=$default>\n";
				foreach $option (@options) {
					$selected = ($option eq $default) ? " selected" : "";
					print qq(<option value="$option"$selected>$option);
				}
				print "</SELECT></span></td></tr>";			

			} elsif ($display_t eq "RADIO") {
 				print "<tr><td valign=top>$key&nbsp;&nbsp;</td>\n";
				print "<td valign=top>";
				foreach $option (@options) {
					print "<NOBR><INPUT TYPE=\"radio\" NAME=\"$key\{\}$hash\" VALUE=\"$option\"";
					print " CHECKED" if ($$hash{$key} eq $option); 
					print ">$option&nbsp;&nbsp;</NOBR>\n";					
				}				
				print "</td></tr>\n";

			} elsif ($display_t eq "CHECKBOX") {
				print "<tr><td valign=top>$key&nbsp;&nbsp;</td>";
				print qq(<td valign=top><INPUT TYPE="checkbox" NAME="$key\{\}$hash" VALUE="yes");
				print " CHECKED" if ($default eq "yes"); 
				print "></td></tr>\n";	
			
			} elsif ($display_t eq "TEXTAREA") {
				print qq(<tr><td valign="top">$key&nbsp;&nbsp;</td><td><TEXTAREA COLS=70 ROWS=6 NAME="$key\{\}$hash">$default</TEXTAREA></td></tr>);
			} else {
				print qq(<tr><td>$key&nbsp;&nbsp;</td><td><INPUT TYPE="text" NAME="$key\{\}$hash" VALUE="$default"></td></tr>);
			}
		}
		print "</table>\n";
	}
	print "<HR>";
	print "<INPUT TYPE=HIDDEN NAME=\"app2do\" VALUE=\"$do_app\">\n";
	print "<INPUT TYPE=HIDDEN NAME=\"set_vars\" VALUE=\"yes\">\n";
	print "<INPUT TYPE=button CLASS=button VALUE=\"Set Defaults\" onClick=\"checkBlanks()\">\n";
	print "</FORM>";
}


sub getkeys {
	(my $hash) = @_;
	my $hashcode;
	($hashcode) = ($code{$do_app} =~ /\%$hash\s*=\s*\((.*?)\n\)/s);
	my @keyvals = $hashcode =~ /[\n\A]\s*['"]([^'"]*).*['"]/g;
	@keyvals;
}


sub umcvar {
	my ($form_key, @code_keys, $code_keys);
	my @hashlist;
	my $hash;
	(my $before_appcode, $appcode, $after_appcode);

	# first find out what hashes are concerned:
	KEYS: foreach $key (keys (%FORM)) {
		next KEYS if ($key eq "set_vars" || $key eq "app2do");
		(my $keyname, my $hashname) = split (/\{\}/, $key);
		my $inlist;
		$in_list = 0;
		foreach $hash_in_list (@hashlist) {
			$in_list = 1 if ($hash_in_list eq $hashname);
		}
		push (@hashlist, ($hashname)) unless ($in_list);
	}

	foreach $hash_concerned (@hashlist) {
		my $placeholder = "___var_editor.pl_placeholder__";

		$vars_code =~s/(\%$hash_concerned.*?\n\);)/$placeholder/s;
		my $hash_raw_code = $1;
#		print qq(code of $hash_concerned is: "$hash_raw_code");
		@code_keys = &getkeys($hash_concerned);
		foreach $code_key (@code_keys) {
#			print qq(<pre>key: $code_key</pre>);
			my $slashed_code_key = $code_key;
			$slashed_code_key =~ s/(\W)/\\$1/g;
			my $value = "";
			$value = "no" if (&get_type ($code_key, $hash_concerned) eq "CHECKBOX");
			FORM_KEY: foreach $form_key (keys (%FORM)) {
				next FORM_KEY if ($form_key eq "app2do" || $form_key eq "set_vars");
				(my $submitted_key) = $form_key =~ /(.*)\{\}/;
#				print qq(<pre>      search in form: $submitted_key</pre>);			
				$value = $FORM{$form_key} if ($submitted_key eq $code_key);
			}
			$hash_raw_code =~ s/(['"]$slashed_code_key['"][^'"]*['"])[^'"]*/$1$value/;
		}
		$vars_code =~ s/$placeholder/$hash_raw_code/;
	}

		
	# create a copy of old version of file in case of a screw-up:
	if (!rename "$incdir/$form_defaults_file", "$incdir/$form_defaults_file." . "previous") {
		print "<PRE>Program encountered error.  Could not create a backup copy.</PRE>";
		return;
	}

	# write new code in file:
	if (!open (HASHES, ">$incdir/$form_defaults_file")) {
		&error("Error: Could not write $incdir/$form_defaults_file.");
	}
	print HASHES "$vars_code";
	close HASHES;
#	print "<PRE>new code: $vars_code</PRE>";

	if (defined $path{$do_app}) {
		print qq(<b><a href="$webcgi/$path{$do_app}">$do_app</a></b><p>);
	} else {
		print "<b>$do_app</b><p>";
	}
	print "Defaults changed successfully.<p>";


}


sub get_type {
	(my $key, $hash) = @_;
	(my $hashcode) = $code{$do_app} =~ /\%$hash *= *\(([^\)]*)\n\)/;
	$slashed_key = $key;
	$slashed_key =~ s/(\W)/\\$1/g;
	(my $type) = $hashcode =~ /[\n\A]\s*['"]$slashed_key['"][^#\n]*#+\s*(\w*)/;
	$type =~ tr/a-z/A-Z/;
	return $type;
}

sub output_form {
	print "<FORM ACTION=\"$ourname\" METHOD=get>";
	print "<span class=dropbox><SELECT name=\"app2do\">\n";
	foreach $key (sort keys(%code)) {
		print qq(<option value="$key">$key\n);
	}
	print "</SELECT></span>\n";

	print "<INPUT TYPE=SUBMIT CLASS=button VALUE=\"Edit Defaults\">\n";
	print "</FORM>";
}

# Checks that no form fields are blank on submission (added 7-27-00, P.Djeu)
sub load_java_checkblanks {
	print <<EOF;
<script language="Javascript">
<!--
function checkBlanks() {
	var maxelements = document.forms[0].elements.length;
	var warning_mesg = "One or more of the defaults on this page contain white space instead of remaining entirely blank.\\n";
	warning_mesg += "White space defaults may cause problems in certain applications.  Are you sure you want to continue?";
	var do_submit = true;
	for (i = 0; i < maxelements; i++) {
		if (document.forms[0].elements[i].value.match(/^\\s\+\$/g)) {
			do_submit = confirm(warning_mesg);
			break;
		}
	}

	if (do_submit) {
		document.forms[0].submit();
	}
}
//-->
</script>
EOF
}



sub error {

	print "<h2>Error</h2>" . join ("<br>",@_) . "</body></html>";
	exit;

}


print "</BODY></HTML>\n";
exit;
