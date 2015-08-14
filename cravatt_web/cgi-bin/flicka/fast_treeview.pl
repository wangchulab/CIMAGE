#!/usr/local/bin/perl

#-------------------------------------
#	FastView HTML
#	Copyright © 2000 Harvard University
#	
#	W. S. Lane/Georgi Matev
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


use strict;

#importing global variables
use vars qw($ourname $webimagedir %FORM $Harvard_Microchem $multiple_sequest_hosts $htdocs);

#global variables for this script
my %tree_item = ();
my @roots = ();
my $line_num;
my ($dirsequest, $miscsequest); # Hides these directories when opening

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
require "stringlist_include.pl"

&cgi_receive();

print <<EOF;
Content-type: text/html

<head> 
  <title>Intranet Home - Harvard Microchemistry Facility</title>
  <meta name="author" content="W. S. Lane / Tim Vasil">
  <meta name="description" content="Harvard Microchemistry Facility Intranet Home">
  <script language="JavaScript">
  <!--
    var isNN = (navigator.appName.indexOf("Netscape") >= 0);
    var isIE = (navigator.appName.indexOf("Microsoft") >= 0);
    if      (isNN) document.write('<LINK REL="stylesheet" TYPE="text/css" HREF="../incdir/intrachem_NN.css">');
    else if (isIE)  document.write('<LINK REL="stylesheet" TYPE="text/css" HREF="../incdir/intrachem_IE.css">');
  //-->
  </script>
  <link rel="stylesheet" type="text/css" href="/incdir/intrachem.css">
<style>
	A:hover {color:"#336699";}
</style>
</head>

<!-- former body attributes: link="#3134b5"  vlink="#3134b5" alink="#ff0000" -->
<body text="#000000" bgcolor="#ffffff" background="$webimagedir/vline.gif" leftmargin=5 topmargin=5 link="#336699"  vlink="#336699" alink="336699">
<form name="form" method="GET" action="$ourname">
<table><tr><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td>&nbsp;<br>
EOF

if (($FORM{'file'} eq '') || !open(ITEMS, "<$htdocs/$FORM{'file'}")) {
	print '<p><font color="#808080">(Nothing to show in this view)';
} else {
	&LoadTree();
	&PrintTree();
	close ITEMS;
}

print <<EOF;
</td></tr></table>
</form>
</body>
EOF

exit;

sub GetControlName {
	my $name = $_[0];
	$name =~ tr/A-Za-z0-9/_/c;
	return $name . $line_num;
}

sub PrintBranchHolders {
	my $item = $_[0];
	my $item_level = $tree_item{$item}{'level'};
	my $style = ($item_level != 0)?"style='display:none;'":"";
		my $html = "";

	print "\t"x($item_level + 1);

	#we show root nodes right away 
	$html.= &PrintLevel($item);
	$html.= &PrintIcon($item);
	$html.= &PrintLink($item);

	print "<span id=$item $style>$html</span>\n";
	
	foreach (split /,/, $tree_item{$item}{'children'}) {
		PrintBranchHolders("$_") if (DisplayCheck($tree_item{$_}{'tag'}));
	}
}

sub PrintTree {
	foreach (@roots) {
		PrintBranchHolders("$_") if (DisplayCheck($tree_item{$_}{'tag'}));
	}

	PrintJS();
}

sub DisplayCheck {
	my ($tag) = $_[0];

		return !(($tag eq 'M:' && 1) || ($tag eq 'X:' && !$multiple_sequest_hosts));

}

sub LoadTree {
	my $parent;
	my $unique_name;
	my $last_control = '';

	#holds the parent for levels 1, 2, ... of current branch
	my @parents = ();

	# file format:	[<tabs>][tag]name[<tabs>link[<tabs>desc]]
	while (<ITEMS>) {
		$line_num++;		
		chop;

		my ($item_level, $item_tag, $item_name, $extras, $item_link, $item_desc, $control_name, $line);
		$line = $_;

		if ($line ne '' && (substr($line, 0, 1) ne '#')  && ($line =~ /^(\t*)([^:\t]*:)*([^\t]+)\t*(.*)/)) {
			($item_level, $item_tag, $item_name, $extras) = (length($1), $2, $3, $4);
			

			$unique_name = &GetControlName($item_name);
			$control_name = "obj_".$unique_name;

			# keep track of parents 
			if ($item_level == 0) {
				#root level
				push @roots, $control_name;
				@parents = ();
			}

			if ($item_name eq "Directory Tools") {
				$dirsequest = $control_name;
			}
			if ($item_name eq "Miscellaneous") {
				$miscsequest = $control_name;
			}

			$parents[$item_level + 1] = $control_name;
			
			if ($extras) {
				$extras =~ /([^\t]+)\t*(.*)/;
				($item_link, $item_desc) = ($1, $2);
			}

			$parent = $parents[$item_level];
			
			#inherit tags
			if (!$item_tag && $parent) {
				$item_tag = $tree_item{$parent}{'tag'};
			}

			$tree_item{$control_name}{'level'} = $item_level;
			$tree_item{$control_name}{'tag'} = $item_tag;
			$tree_item{$control_name}{'name'} = $item_name;
			$tree_item{$control_name}{'img_name'} = "img_".$unique_name;
			$tree_item{$control_name}{'link'} = $item_link;
			$tree_item{$control_name}{'desc'} = $item_desc;
			$tree_item{$control_name}{'parent'} = $parent;
			$tree_item{$control_name}{'children'} = '';
			$tree_item{$control_name}{'next_level'} = $item_level;
		
			#fix the 'next_level' property for the last component
			if ($last_control ne '') {
				$tree_item{$last_control}{'next_level'} = $item_level;
			}

			if ($item_level > 0) {
				if (&DisplayCheck($item_tag)) {
					if ($tree_item{$parent}{'children'}) {
					$tree_item{$parent}{'children'}.= ",$control_name";
					} else {
						$tree_item{$parent}{'children'} = $control_name;
					}
				}
			}	
		}
	
		$last_control = $control_name;
	}
}

sub PrintJS
{
	my ($i, $item);
	my $child;
	
	print <<OBJ;
<script language=JavaScript>
	function click_branch (obj) {
		if (obj.state == "expanded") {
			shrink_branch(obj);
		} else {
			expand_branch(obj);
		}
	}

	function expand_branch(obj)
	{
		obj.state = "expanded";
		obj.style.display = "";
		if (obj.ch.length > 0) {
			obj.icon.src = "$webimagedir/tree_open.gif";
		}

		//close all other roots
		if (obj.is_root) {
			for(i=0; i < roots.length; i++) {
				if (roots[i] != obj && roots[i].state == "expanded") {
					shrink_branch(roots[i]);
				}
			}
		}
		
		for (var i=0; i < obj.ch.length; i++) {
			expand_branch(obj.ch[i]);
		}
	}

	function shrink_branch(obj)
	{	
		obj.state = "shrunk";
		if (obj.ch.length > 0) {
			obj.icon.src = "$webimagedir/tree_closed.gif";
		}

		for (var i=0; i < obj.ch.length; i++) {
			shrink_branch(obj.ch[i]);
			obj.ch[i].style.display = "none";
		}
	}
	
	var obj;
OBJ
	
	print qq(\tvar roots = new Array();\n);
	
	$i = 0;
	foreach (@roots) {
		print qq(\troots[$i] = document.getElementById('$_');\n);
		$i++;
	}
	printf("\n");


	foreach $item (keys %tree_item) {
		next if (!DisplayCheck($tree_item{$item}{'tag'}));

		print qq(\n\tobj = document.getElementById("$item");\n);
		print qq(\tobj.state = "shrunk";\n);
		print qq(\tobj.is_root = true;\n) if ($tree_item{$item}{'level'} == 0);
		print qq(\tobj.icon = document.getElementById("$tree_item{$item}{'img_name'}");\n) if ($tree_item{$item}{'children'});
		
		print qq(\tobj.ch = new Array();\n);

		$i=0;
		foreach $child (split /,/, $tree_item{$item}{'children'}) {
			print("\tobj.ch[$i] = $child;\n");
			$i++;
		}
	}
	print qq(expand_branch(document.getElementById("$roots[$FORM{'active_root_num'}]"));\n);
		print qq(shrink_branch(document.getElementById("$dirsequest"));\n);
		print qq(shrink_branch(document.getElementById("$miscsequest"));\n);


	print("</script>\n");
}
	
sub PrintLevel {
	my $item = $_[0];
	my ($level, $next_level) = ($tree_item{$item}{'level'}, $tree_item{$item}{'next_level'});
	
	my $class;
	my $result = "<nobr>";
	
	if ($level >= $next_level) {
		$class = 'Child';
	} elsif ($level==0) {
		$class = 'Node1';
	} elsif ($level==1) {
		$class = 'Node2';
	} else {
		$class = 'NodeX';
	}
	
	$result.= "<span class=\"$class\">"	;
	$result.= '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' x $level;
	
	return $result;
}

sub PrintIcon {
	my $control_name = $_[0];
	my ($item_level, $next_level) = ($tree_item{$control_name}{'level'}, $tree_item{$control_name}{'next_level'});
	my $result = "";

	if ($item_level < $next_level) {
		$result = "<img border=0 id=\"$tree_item{$control_name}{'img_name'}\" src=\"$webimagedir/tree_closed.gif\" onClick=\"click_branch(document.getElementById('$control_name'))\" style=\"cursor: hand;\">&nbsp;"
	} else {
		$result =  "<img border=0 id=\"$tree_item{$control_name}{'img_name'}\" src=\"$webimagedir/tree_item.gif\">&nbsp;"
	}

	return $result;
}

sub PrintLink {
	my $item = $_[0];
	my ($name, $link, $desc) = ($tree_item{$item}{'name'}, $tree_item{$item}{'link'}, $tree_item{$item}{'desc'} );
	my $result = "";
	
	my $prefix = !(($link =~ /^http:/) || ($link =~ /.*\.pl$/) || ($link =~ /.*\.pl?/)) ? '../' : '';
	$result.= (($link) ? "<a title=\"$desc\" href=\"$prefix$link\" target=\"_parent\">" : '');
	$result.= $name;
	$result.= '</span>';
	$result.= (($link) ? '</a>' : '');
	$result.= '</nobr><br>';

	return $result;
}