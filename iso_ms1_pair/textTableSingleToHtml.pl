#!/usr/bin/perl -w

die "Usage: $0 text_table\n" if (@ARGV <1 );

$intable=$ARGV[0];
##$title=$ARGV[1];

open(INFILE,$intable) || die "cannot open $intable: $!\n";
@txt = <INFILE>;
close(INFILE);
$nrow = @txt;
@header = split(/\s+/,$txt[0]);
$ncol = @header;
@headerout=(1, 2, 3, 5, 6, 8, 9, 17, 19, 20);

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
##print OUTFILE "<COLGROUP span=1>\n";
##print OUTFILE "<COLGROUP span=4>\n";
##print OUTFILE "<COLGROUP span=3>\n";
##print OUTFILE "<COLGROUP span=3>\n";
##print OUTFILE "<COLGROUP span=3>\n";
##print OUTFILE "<COLGROUP span=3>\n";
##print OUTFILE "<COLGROUP span=1>\n";
##print OUTFILE "<COLGROUP span=1>\n";
print OUTFILE "<TBODY>\n";
print OUTFILE "<TR>\n";
for ($i=0; $i<@headerout; ++$i) {
    print $headerout[$i]."\n";
    print OUTFILE "<TH align=\"center\" bgcolor=\"HoneyDew\">$header[$headerout[$i]-1]\n";
}
print OUTFILE "<TBODY>\n";
@bgcolormap=@headerout;
for ($i=0; $i<$ncol; ++$i) {
    $bgcolormap[$i]=""
}
#for ($i=8; $i<11; ++$i) {
#    $bgcolormap[$i]="bgcolor=\"#DCDCDC\""
#}
for ($i=1; $i<$nrow; ++$i) {
    print OUTFILE "<TR>";
    @line = split('\s+',$txt[$i]);
    for ($j=0; $j<@headerout; ++$j) {
	if ( $j == (@headerout-1) ) {
	    print OUTFILE "<TD><A HREF=\"./img/$line[$headerout[$j]-1].png\">$line[$headerout[$j]-1]</A>";
	} else {
	    print OUTFILE "<TD align=\"center\" $bgcolormap[$j]>$line[$headerout[$j]-1]";
	}
    }
    print OUTFILE "\n";
}
print OUTFILE '</TABLE>'."\n";
