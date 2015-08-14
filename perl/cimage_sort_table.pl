#!/usr/bin/perl

###############################################################################################
#
#    sort cimage output table by a selected column
#
################################################################################################


use CGI;
#use GD;
#use GD::Graph::points;
#use GD::Graph::axestype;
use CGI::Carp qw(fatalsToBrowser);
#use Spreadsheet::WriteExcel;

#use Math::Trig;


$q = new CGI;

$dset = $q->param('dset');
$ddir = $q->param('ddir');
$colname = $q->param('colname');
$ascending = $q->param('ascending');


#$dset = $ARGV[0];;
#$colname = $ARGV[1];
#$ascending = $ARGV[2];;

#$ddir = "/~chuwang/shared/EW/from_DTASelect/competitive_isoTOPABPP/2012_12_31_HNE_PGJ_HEX/align/";
if ($ddir eq "" ) {
    $ddir=$ENV{HTTP_REFERER};
}
@cwdpath=split(/\//,$ddir);
pop(@cwdpath);
splice(@cwdpath, 0, 3);
$cwd=join('/',@cwdpath);

open (DSET, $dset) or die "cannot open cimage output table $! -- $dset";
my @dsettable;
@dsettable = <DSET>;
close DSET;

################# parse the header line #############################
$colindex = 0;
@header=split(/\t/,$dsettable[0]);
$i = 0;
foreach (@header) {
    last if ($header[$i] eq $colname);
    ++$i;
}
$colindex = $i;

################# load in dset table ################################
$exclude_zero = ($ascending eq "True");
$i = 0;
$entry = 0;
%colvalues=();
%linenum=();
foreach (@dsettable) {
    @currow = split(/\t/,$_);
    if ( $currow[0] ne " " ){
	$colvalues{$entry} = $currow[$colindex];
	if ($colvalues{$entry} eq "NaN") { $colvalues{$entry}=0 }
#	if ($exclude_zero && ($currow[$colindex] == 0)) {
	if ($exclude_zero && ($colvalues{$entry} == 0)) {
	    $colvalues{$entry} = 99999; # a very large number for sorting
	}
	$linenum{$entry} = $i;
	++$entry;
    }
    ++$i;
}
$linenum{$entry} = ++$i; ## appending the end of file

## sort by colume values ##
@sortindex=();

delete($colvalues{0}); ## remove the first line of header prior to sorting

foreach $value (sort {$colvalues{$a} <=> $colvalues{$b} } keys %colvalues )
{
    push(@sortindex, $value);
}

#while(($key,$value)=each(%linenum)) {
#    print "chu linenum $key $value \n";
#}

## ascending or descending
@sortindex = reverse(@sortindex) if ($ascending ne "True" );

## print the sorted table
@txt=();
push(@txt, $dsettable[0]);
foreach(@sortindex) {
    $begin = $linenum{$_};
    $end = $linenum{$_+1};
    for ($i = $begin; $i < $end; ++$i) {
	push(@txt,$dsettable[$i]);
    }
}

#"/home/chuwang/pub/perl/textTableCombinedToHtml.pl" $outname $cwd $allpt;

$nrow = @txt;
@header = split(/\t/,$txt[0]);
$ncol = @header;
@bgcolormap=@header;
$nset=0;
for ($i=0; $i<$ncol; ++$i) {
    if ($header[$i] =~ /^mr\./) {
	$bgcolormap[$i]="bgcolor=\"#DCDCDC\"";
	$nset++;
    } else {
	$bgcolormap[$i]=""
    }
}

print STDOUT "Content-type: text/html\n\n";
print STDOUT <<ENDOFHEADER;
<HTML><HEAD>
<STYLE TYPE="text/css">
*{
    font-family: arial, helvetica, myriad;
    font-size: 13px;
}
table#sample TD {
    text-align: center;
}
</STYLE>
<script data-main="/~chuwang/cimage-clientpatches/dist/main" src="/~chuwang/cimage-clientpatches/dist/vendor/require.js" type="text/javascript"></script>
</HEAD>
<BODY>
ENDOFHEADER

print STDOUT "<A HREF=\"$ddir\">Orginal HTML table</A><BR>\n";
print STDOUT "<b>mr.set columns: </b><BR>";
print STDOUT "[bold] -- median value of measured ratios in this group<BR>";
print STDOUT "<b>sd.set columns:</b><BR>";
print STDOUT "[bold] -- standard deviation of measured ratios in this group<BR>";
print STDOUT "[plain] -- for each labeled peptide, number of peaks with triggered ms2 / number of candidate peaks for selection<BR>";
print STDOUT "<b>ratio calculation:</b><BR>";
print STDOUT "peak pairs with R2<0.8 are excluded<BR>";
print STDOUT "labeled peptides with invalid 1:10 ratios are excluded<BR>";
print STDOUT "<b>peptide grouping:</b><BR>";
print STDOUT "multiply labeled peptides are separated from singly labeled ones<BR>";
print STDOUT "singly labeled peptides with multiple alternative sites are grouped together<BR><BR>";
print STDOUT "<TABLE id=\"sample\" border=2 frame=\"border\" rules=\"groups\" summary=$intable>\n";
##print STDOUT "<CAPTION> <b>$title</b> </CAPTION>\n";

print STDOUT "<COLGROUP span=1>\n";
print STDOUT "<COLGROUP span=4>\n";
print STDOUT "<COLGROUP span=1>\n";
print STDOUT "<COLGROUP span=$nset>\n";
print STDOUT "<COLGROUP span=$nset>\n";
print STDOUT "<COLGROUP span=3>\n";
print STDOUT "<COLGROUP span=1>\n";
print STDOUT "<COLGROUP span=1>\n";
print STDOUT "<TBODY>\n";
print STDOUT "<TR>\n";
for ($i=0; $i<$ncol; ++$i) {
    #print STDOUT "<TH align=\"center\" bgcolor=\"HoneyDew\">$header[$i]\n";
    print STDOUT "<TH bgcolor=\"HoneyDew\">$header[$i]\n";
}
print STDOUT "<TR>\n";
@line1 = split('\t', $txt[1]);
for ($i=0; $i<$ncol; ++$i) {
    if ( $line1[$i] eq ' ' ) {
	print STDOUT "<TH bgcolor=\"HoneyDew\"> \n";
} else {
    print STDOUT "<TH bgcolor=\"HoneyDew\"><A HREF=\"http://162.105.22.250/cgi-bin/chuquest/cimage_sort_table.pl?dset=$dset&colname=$header[$i]&ascending=True&ddir=$ddir\" style=\"text-decoration:none\">^</A> <A HREF=\"http://162.105.22.250/cgi-bin/chuquest/cimage_sort_table.pl?dset=$dset&colname=$header[$i]&ascending=False&ddir=$ddir\" style=\"text-decoration:none\">v</A>\n";
}
}
print STDOUT "<TBODY>\n";
for ($i=1; $i<$nrow; ++$i) {
    print STDOUT "<TR>";
    @line = split('\t',$txt[$i]);
    if ($line[0] =~ /\d+/ ) {
	$bold1="<b>";
	$bold2="</b>";
	$anchor1 = 1;
    } else {
	$bold1="";
	$bold2="";
	$anchor1 = 0;
    }
    for ($j=0; $j<$ncol; ++$j) {
	$_ = $line[$j];
	if ( /^=HYPERLINK/ ) {
	    /^=HYPERLINK\("(.*)","(\d+.\d+)"\)$/;
	    print STDOUT "<TD $bgcolormap[$j]><A HREF=\"/$cwd/$1\">$2</A>";
	} elsif ( /^([a-zA-Z]+)$/ && $anchor1 ) {
	    print STDOUT "<TD $bgcolormap[$j]> <A NAME=\"$1\"></A> $bold1 $1 $bold2";
	} elsif ( /(\w+)$/ && $j==1 ) {
	    if (/^(IPI\w+)/) {
		print STDOUT "<TD $bgcolormap[$j]><A HREF=\"http://www.ebi.ac.uk/cgi-bin/dbfetch?db=IPI&id=$1&format=default\">$1</A>";
	    } elsif (/^(\w{6})$/) {
		print STDOUT "<TD $bgcolormap[$j]><A HREF=\"http://www.uniprot.org/uniprot/$1\">$1</A>";
	    } else {
		print STDOUT "<TD $bgcolormap[$j]> $bold1 $line[$j] $bold2";
	    }
	} elsif (/^(\d+\/\d+)/) {
	    print STDOUT "<TD $bgcolormap[$j]> $bold1 $1 $bold2";
	} else {
	    print STDOUT "<TD $bgcolormap[$j]> $bold1 $line[$j] $bold2";
	}
    }
    print STDOUT "\n";
}
print STDOUT '</TABLE>'."\n";
print STDOUT '</BODY>'."\n";
print STDOUT '</HTML>'."\n";
