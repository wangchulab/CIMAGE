#!/usr/bin/perl
use CGI;

my $q = new CGI;
$sstring = $q->param('sstring');

print <<ENDOFHTML;
Content-type: text/html\n\n
<html>
<head>
<title>Search dataset</title>
<SCRIPT>
    function clearDefault(el){
if(el.defaultValue==el.value) el.value=""
}
</SCRIPT>
<SCRIPT type="text/javascript">
function checkAll(field)
{
    for (i = 0; i < field.length; i++)
    field[i].checked = true ;
}
function uncheckAll(field)
{
    for (i = 0; i < field.length; i++)
        field[i].checked = false ;
}
</script>

<script type="text/javascript">

    function swap(listIdPrefix,group) {
	collapsedList = document.getElementById(listIdPrefix + "_collapsed");
	expandedList = document.getElementById(listIdPrefix + "_expanded");
	if (collapsedList.style.display == "block") {
	    collapsedList.style.display = "none";
	    expandedList.style.display = "block";
	} else {
	    collapsedList.style.display = "block";
	    expandedList.style.display = "none";
	}
	if (group) {
	    ensureExclusivity(listIdPrefix,group);
	}
    }

function ensureExclusivity(listIdPrefix,group) {

    //alert("listIdPrefix is " + listIdPrefix + ", group is " + group);

    for (var i = 0 ; i < group.length ; i++) {
        if (group[i] != listIdPrefix) {
            document.getElementById(group[i] + "_collapsed").style.display = "block";
            document.getElementById(group[i] + "_expanded").style.display = "none";
        }
    }
}

// mutually exclusive lists
    var groupA = new Array();
groupA[groupA.length] = "list_a_excl";
groupA[groupA.length] = "list_b_excl";

var outerGroup = new Array();
outerGroup[outerGroup.length] = "list_1";
outerGroup[outerGroup.length] = "list_2";

var innerGroup1 = new Array();
innerGroup1[innerGroup1.length] = "list_1_a";
innerGroup1[innerGroup1.length] = "list_1_b";

var innerGroup2 = new Array();
innerGroup2[innerGroup2.length] = "list_2_a";
innerGroup2[innerGroup2.length] = "list_2_b";

</script>
</head>
<body link=444444 vlink=444444 alink=440000>
<font face="arial">
ENDOFHTML



open (INDIN, "/srv/www/htdocs/cimage/cimage_data/index.txt") or die "cannot open index.index";
@index = <INDIN>;
close INDIN;

print "<CENTER><H2>Cravatt-lab CIMAGE database:</H2>\n";
print "<IMG SRC=\"/cimage/isotopabpp.jpg\" border=0>\n";

print "<H3>Select dataset to search:</H3>\n";

#print "<FORM METHOD=get ACTION=\"\/cgi-bin\/cravatt\/\/restricted\/cimage-frmrec2\.pl\" ENCTYPE=\"multipart\/form-data\" NAME=\"keywordsearch\">\n";
print "<FORM NAME=\"keywordsearch\">\n";

############################# dataset selection ##########################################


print "\n<div style=\"background-color: #EFEFEF; width: 600px; padding: 20px; border: grey 1px dashed;text-align: left;\">";

&lister("isoTOP-ABPP");

foreach (@index) {
    @curline = split (/\t/,$_);
    &printdesc(@curline) if ($curline[3] =~ /isoTOP-ABPP/);
}
print "</div>";

&lister("SILAC");

foreach (@index) {
    @curline = split (/\t/,$_);
    &printdesc(@curline) if ($curline[3] =~ /SILAC/);
}
print "</div>";


&lister("N15");

foreach (@index) {
    @curline = split (/\t/,$_);
    &printdesc(@curline) if ($curline[3] =~ /N15/);
}
print "</div>";

&lister("Other");

foreach (@index) {
    @curline = split (/\t/,$_);
    &printdesc(@curline) if ($curline[3] =~ /other/);
}
print "</div>";

#print "<input type=button name=\"CheckAll\" value=\"Select all\" onClick=\"checkAll(document.keywordsearch.dset)\" onClick=\"javascript:swap(\'list_Human\')\"><input type=button name=\"UnCheckAll\" value=\"Clear selection\" onClick=\"uncheckAll(document.keywordsearch.dset)\">";
print "<input type=button name=\"CheckAll\" value=\"Select all\" onClick=\"checkAll(document.keywordsearch.dset);\"><input type=button name=\"UnCheckAll\" value=\"Clear selection\" onClick=\"uncheckAll(document.keywordsearch.dset);\">";

print "</div>";


print "<\/FORM>\n";


print "</BODY></HTML>";

sub lister {
    my ($header) = @_[0];
    print "\n<P><div id=\"list_" . $header . "_collapsed\" style=\"display:block;\">";
    print "\n<a href=\"javascript:swap(\'list_$header\')\"><B>[+] $header</B></a>";
    print "\n</div>";
    print "\n<P><div id=\"list_" . $header . "_expanded\" style=\"display:none\">";
    print "\n<a href=\"javascript:swap(\'list_$header\')\"><B>[-] $header</B></a><br/>";
}

sub printdesc {
    my ($filename, $org, $stype, $itype, $probe, $username, $datesub, $desc)  = @_;
    print "\n<span class=\"indented\">";
    @temp = split (/\./, $filename);
    $asterisk = "";
    $asterisk = "*" if ( -d '/srv/www/htdocs/cimage/cimage_data/'.$temp[0]);

    print "<BR><INPUT TYPE=\"checkbox\" name=\"dset\" value=\"/srv/www/htdocs/cimage/cimage_data/$filename\">$asterisk $username\'s $desc &nbsp;&nbsp;<FONT SIZE=-1>[<A HREF=\"/cgi-bin/cravatt/restricted/cimage-dset-list.pl?filename=$filename&description=$desc\">view</A>][<A HREF=\"/cgi-bin/cravatt/restricted/cimage-dset-edit.pl?filename=$filename\">edit</A>][<A HREF=\"mpd_volcano.pl?dset=$filename\">plot</A>]</FONT><BR>";
    print "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp<FONT SIZE=-2 COLOR=#555555>filename: $filename - sample-type: $stype - isotope-type: <B>$itype</B> - probe: <B>$probe</B> - date submitted: $datesub</FONT>\n";
    print "\n</span>";
}


