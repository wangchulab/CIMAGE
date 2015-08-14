#!/usr/bin/perl -w

die "Usage: $0 text_table\n" if (@ARGV <1 );

$intable=$ARGV[0];
##$title=$ARGV[1];

open(INFILE,$intable) || die "cannot open $intable: $!\n";
@txt = <INFILE>;
close(INFILE);
$nrow = @txt;
@header = split(/\t/,$txt[0]);
$ncol = @header;


$outhtml=$intable;
$outhtml =~ s/\.txt$/\.html/g;

open(OUTFILE, ">$outhtml") || die "cannot write to $outhtml: $!\n";
##print OUTFILE "Content-type: text/html\n\n";
print OUTFILE <<ENDOFHEADER;
<HTML><HEAD>
<STYLE TYPE="text/css">
    * {
        font-family: arial, helvetica, myriad;
        font-size: 10px;
    }
</STYLE>
ENDOFHEADER
print OUTFILE "<TABLE border=2 frame=\"border\" rules=\"groups\" summary=$intable>\n";
##print OUTFILE "<CAPTION> <b>$title</b> </CAPTION>\n";
print OUTFILE "<COLGROUP span=1>\n";
print OUTFILE "<COLGROUP span=4>\n";
print OUTFILE "<COLGROUP span=3>\n";
print OUTFILE "<COLGROUP span=3>\n";
print OUTFILE "<COLGROUP span=3>\n";
print OUTFILE "<COLGROUP span=3>\n";
print OUTFILE "<COLGROUP span=1>\n";
print OUTFILE "<COLGROUP span=1>\n";
print OUTFILE "<TBODY>\n";
print OUTFILE "<TR>\n";
for ($i=0; $i<$ncol; ++$i) {
    print OUTFILE "<TH align=\"center\" bgcolor=\"HoneyDew\">$header[$i]\n";
}
print OUTFILE "<TBODY>\n";
@bgcolormap=@header;
for ($i=0; $i<$ncol; ++$i) {
    $bgcolormap[$i]=""
}
for ($i=8; $i<11; ++$i) {
    $bgcolormap[$i]="bgcolor=\"#DCDCDC\""
}
for ($i=1; $i<$nrow; ++$i) {
    print OUTFILE "<TR>";
    @line = split('\t',$txt[$i]);
    for ($j=0; $j<$ncol; ++$j) {
	$_ = $line[$j];
	if ( /^=HYPERLINK/ ) {
	    /^=HYPERLINK\("(.*)"\)$/;
	    print OUTFILE "<TD><A HREF=\"$1\">$1</A>";
	} else {
	    print OUTFILE "<TD align=\"center\" $bgcolormap[$j]>$line[$j]";
	}
    }
    print OUTFILE "\n";
}
print OUTFILE '</TABLE>'."\n";
