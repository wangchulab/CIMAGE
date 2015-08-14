#!/usr/local/bin/perl

#-------------------------------------
#	qter-cool.pl,
#	(C)1999 Harvard University
#	
#	W.S. Lane/ A. Chang
#
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 01/11/02 by Aaron Chang
# Last Mod: 04/03/02 by Dong Kim
# Description: improved output version of q-cool.pl ("q-ter = cuter") - sortable, tabular output
# This program parses through the specified directories for .fuz.html files and outputs their content in a readable manner.  These rows of data can be sorted in ascending or descending order.  Also, entries with duplicate category values can be collapsed into one entry by clicking on the checkboxes at the top of the screen.
#
##CGI-RECEIVE## dirs - the list of selected sequest directories
##CGI-RECEIVE## sort_column - the number of the column by which to sort the output
##CGI-RECEIVE## order - an array which keeps track of ascending/descending ordering for each column
##CGI-RECEIVE## column1_order - the column on which to conduct primary sorting
##CGI-RECEIVE## change_order - indicates whether or not the output is to be resorted (as opposed to being collapsed)
##CGI-RECEIVE## checks - a concatenated, ordered list of which boxes have been checked (for collapsing)

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
use Time::Local;

#######################################
# Initial output
&MS_pages_header("Qter-Cool","#ff0000");
print "<hr>";

#######################################
# Fetching data
&cgi_receive;

# FORM VALUES
$dirs        = $FORM{"directory"};		# holds value of null or 1, depending on selection
$sort_column = $FORM{"sort_column"};

$order[1] = $FORM{"dir_order"};   # holds info on ascending/decending sort order of a given column header link
$order[2] = $FORM{"dta_order"};
$order[3] = $FORM{"mh_order"};
$order[4] = $FORM{"Z_order"};
$order[5] = $FORM{"seq_order"};
$order[6] = $FORM{"date_order"};
$order[7] = $FORM{"OP_order"};
$order[8] = $FORM{"com_order"};

$uncollapse  = $FORM{"uncollapsebox"};
$collapse[1] = $FORM{"dirbox"};
$collapse[2] = $FORM{"dtabox"};
$collapse[3] = $FORM{"mhbox"};
$collapse[4] = $FORM{"zbox"};
$collapse[5] = $FORM{"seqbox"};
#$collapse[6] = $FORM{"timebox"};
$collapse[7] = $FORM{"initbox"};
$collapse[8] = $FORM{"combox"};

$column1_order = $FORM{"column1_order"};
$change_order  = $FORM{"change_order"};
$checks        = $FORM{"checks"};

if (!($FORM{"execute"})) {
  &outputForm();
  exit 0;
}

#print "sort_column = $sort_column<BR>"; #debug
#print "change_order = $change_order<BR>"; 

# COLUMN ORDER PREFERENCES - order of sorting 
@names = ("", "dir", "dtafile", "mhValue", "zValue", "actualSeq", "actualTime", "initials", "comments"); # want to start index from 1
$column[1] = $names[$sort_column];
if ($change_order) { 
	$column1_order = ++($order[$sort_column]); 
} else { 
	$column1_order = $order[$sort_column]; 
} 

$val = 0;	# global which indicates if the directories should be sorted first by a num or an ascii value
if ($sort_column == 3 || $sort_column == 4 || $sort_column == 6) { $val = 1; }

# SETS ORDER OF COLLAPSING ACCORDING TO THE ORDER OF BOXES CHECKED
@temp_checked = split //, $checks;
if ($change_order) {
	@cur_checked = @temp_checked;
	$ind = scalar(@cur_checked);
} else {	
	$ind = 0;
	foreach $this (@temp_checked) { # check for any boxes that were unchecked
		if (!$collapse[$this]) { next; }
		$cur_checked[$ind] = $this;
		$ind++;
	}
	if (scalar(@cur_checked) == scalar(@temp_checked)) { # another box was checked
		foreach $this (@collapse) {
			if ($this) {
				if(!(&inList($this, @temp_checked))) {
					$cur_checked[$ind] = $this;
					last;
				}
			}
		}
	}
	$ind = scalar(@cur_checked);
}

$change_order = 0;	# only change ascending/descending order when category headers are clicked

#debug
#print "ind = $ind<br>";
#print "collapse = $cur_checked[0]<br>";
#print "collapse = $cur_checked[1]<br>";

&secondarySortOrder();	# set sorting preference for remaining columns
&makeTableHeader();

$dirs =~ s/,//g;
@directories = split(" ", $dirs);

@unsorted_rows = ();        # initialize arrays
@sorted_rows = ();
@unique_rows = ();
@uniquely_sorted_rows = ();

&get_alldirs;  #can use for getting dir fancy names

foreach $dir (@directories){
	opendir (DIR, "$seqdir/$dir") || &error ("Could not open directory!");
	@fuzzies = grep { m!\.fuz\.html$! } readdir (DIR);
	closedir (DIR);

	if (! @fuzzies) {
		print <<EOF;
<tr>
	<td width=1><span class="smalltext"><nobr>$fancyname{$dir}</nobr></span></td>
</tr>
EOF
	}
	else{
		foreach $fuz (@fuzzies){
			($dta = $fuz) =~ s!\.fuz\.html$!.dta!;

			open (DTA, "<$seqdir/$dir/$fuz");
			while (<DTA>) {
				last if m!<BODY!; # skip the header and the <BODY> tag since this an html file
			}

			while (<DTA>) {   # process in the fuz data here into the "rowdata" array
				s!<hr>!!;     # take out html tags that affect fonts
				s/<b>//g;
				s/<\/b>//g;
				s/<div>//g;
				s/<\/div>//g;
				s/<font size=-1>//g;
				s/<\/font>//g;
				s/<tt>//g;
				s/<\/tt>//g;
				s/(<BR>)*//g;
				s/&nbsp\;//g;
				s/(<br>)*//g;

				#print "<BR>line = $_<BR>"; # FOR DEBUG
					
				if (/Dta:/) {              # first line match
					$_ =~ /(.*)\s+Dta:\s(.*)\.\d\.dta\s+MH\+:(.*)\s+z:\s+(.*)\s+/;
					$author = $dir;
					$dtafile = $2;
					$mhValue = $3;
					$zValue = $4;

					#print "<BR> directory= $author <BR> dtafile= $dtafile <BR> MH+= $mhValue <BR> z= $zValue <BR><BR>"; # FOR DEBUG
				}
				else {                     # next line match - dynamic array need since number of extra lines is unknown a priori 
					$_ =~ /(\S*)\s+<a\s(href.+\")>(.*)<\/a>\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\S+)\s*\S*\s*(.*)/;
					$initials = $1;
					$seqlink = $2;
					$actualSeq = $3;
					$wkday = $4;
					$mon = $5;
					$mday = $6;
					$hour = $7;
					$minute = $8;
					$sec = $9;
					$year = $10;
					$comments = $11;
					
					%mon_conv = (Jan => "0", Feb => "1", Mar => "2", Apr => "3", May => "4", Jun => "5", 
								Jul => "6", Aug => "7", Sep => "8", Oct => "9", Nov => "10", Dec => "11");
	
					$actualTime = timelocal($sec, $minute, $hour, $mday, $mon_conv{$mon}, $year-1900);

					push @unsorted_rows, {dir => $author, 
								 dtafile => $dtafile, 
								 mhValue  => $mhValue, 
								 zValue => $zValue, 
								 initials => $initials,  
								 seqlink => $seqlink,
								 actualSeq => $actualSeq,
								 wkday => $wkday,
								 mon => $mon,
								 mday => $mday,
								 year => $year,
								 hour => $hour,
								 minute => $minute,
								 sec => $sec,
								 actualTime => $actualTime,
								 comments => $comments};  
			
					# for debug
					#print "$actualTime <br>";
					#print "$1 <br> $2 <br> $3 <br> $4 <br> $5 <br> $6 <br> $7 <br> $8 <br> $9 <br> $10 <br>";
					#print "<BR>initials = $initials <BR> actualSeq= $actualSeq <BR> comments = $comments <BR>"; 	
					#print "$wkday <br> $mon <br> $mday <br> $hour <br> $minute <br> $sec <br> $year <br>";
					#exit 1;
				}

			} # end of while loop  

		} # end of foreach fuz file loop
		
	} # end of else (dirs = true) 
	
} # end of foreach dir loop

if ($ind && !$uncollapse) {
	@temp_rows = @unsorted_rows;
	foreach $checked (@cur_checked) {
		$collapse_column = $names[$checked];
		@unique_rows = &removeDupes($collapse_column, @temp_rows);
		@uniquely_sorted_rows = sort allTheHashesIn @unique_rows;
		@temp_rows = @uniquely_sorted_rows;
	}
	&printOut(@uniquely_sorted_rows);
} else {
	@sorted_rows = sort allTheHashesIn @unsorted_rows;
	&printOut(@sorted_rows);
}

print <<EOF;
</table>
EOF

#######################################
# subroutines (other than &outputForm and &error, see below)

##PERLDOC##
# Function : makeTableHeader
# Argument : NONE
# Globals  : NONE
# Returns  : 0 - Success
# Descript : Creates form to display category headers (used for sorting) and radio buttons (used for collapsing entry duplicates).
# Notes    : The category header turns firebrick when it is sorted in ascending order and green when it is sorted in descending 
#			 order.  Also, clicking a radio button submits the form.
##ENDPERLDOC##
sub makeTableHeader {

	# alternate column header color to indicate sort order & check for checkbox selections
	for (my $i = 1; $i < 9; $i++) {
		if ($order[$i]%2 != 0) { $color[$i] = "firebrick"; } else { $color[$i] = "green"; }	
	}
	# $color[$sort_column] = "blue"; # make last selected column blue
	
	if (!$uncollapse) {	# if uncollapse all was not selected
		$checks = "";
		foreach $checked (@cur_checked) {
			$box_state[$checked] = "checked";
			$checks .= $checked;
		}
	} else {
		$checks = "";
	}
	#print "checks = $checks<br>";

print <<EOF;
<FORM METHOD=get ACTION="$ourname" NAME="output">
	<input type="hidden" name="sort_column" value="$sort_column">
	<input type="hidden" name="change_order" value="$change_order">
	<input type="hidden" name="dir_order" value="$order[1]">
	<input type="hidden" name="dta_order" value="$order[2]">
	<input type="hidden" name="mh_order" value="$order[3]">
	<input type="hidden" name="Z_order" value="$order[4]">
	<input type="hidden" name="seq_order" value="$order[5]">
	<input type="hidden" name="date_order" value="$order[6]">
	<input type="hidden" name="OP_order" value="$order[7]">
	<input type="hidden" name="com_order" value="$order[8]">
	<input type="hidden" name="execute" value=1>
	<input type="hidden" name="directory" value="$dirs">
	<input type="hidden" name="checks" value="$checks">
EOF

print <<EOF;
<div><input type=checkbox name="uncollapsebox" $box_state[0] value="1" onClick=submit()><span class="smalltext">Uncollapse All</span></div>
<table border=0 cellspacing=0 cellpadding=0>
<tr>
<span class="smallheading">Choose columns to collapse (in order):</span>
</tr>
<tr>
	<td><input type=checkbox name="dirbox" $box_state[1] value="1" onClick=submit()></td>
	<td>&nbsp;&nbsp;<input type=checkbox name="dtabox" $box_state[2] value="2" onClick=submit()></td>
	<td>&nbsp;&nbsp;<input type=checkbox name="mhbox" $box_state[3] value="3" onClick=submit()></td>
	<td>&nbsp;<input type=checkbox name="zbox" $box_state[4] value="4" onClick=submit()></td>
	<td>&nbsp;<input type=checkbox name="seqbox" $box_state[5] value="5" onClick=submit()></td>
	<td></td>
    <!--
	<td>&nbsp;&nbsp;<input type=checkbox name="timebox" $box_state[6] value="6" onClick=submit()></td>
	//--> 
	<td>&nbsp;<input type=checkbox name="initbox" $box_state[7] value="7" onClick=submit()></td>
	<td>&nbsp;&nbsp;<input type=checkbox name="combox" $box_state[8] value="8" onClick=submit()></td>
	
</tr>
</FORM>
<tr>
	<td width=1><span class="smallheading"><a href="$ourname?sort_column=1&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[1]">DIRECTORY</FONT></a></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smallheading"><a href="$ourname?sort_column=2&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[2]">DTA</FONT></a></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smallheading"><a href="$ourname?sort_column=3&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[3]">MH+</FONT></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smallheading"><a href="$ourname?sort_column=4&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[4]">Z</FONT></span></td>
	<td width=1>&nbsp;<span class="smallheading"><a href="$ourname?sort_column=5&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[5]">SEQUENCE</FONT></a></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smallheading"><a href="$ourname?sort_column=6&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[6]">DATE</FONT></a></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smallheading"><a href="$ourname?sort_column=7&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[7]">OP</FONT></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smallheading"><a href="$ourname?sort_column=8&checks=$checks&change_order=1&dir_order=$order[1]&dta_order=$order[2]&mh_order=$order[3]&Z_order=$order[4]&seq_order=$order[5]&date_order=$order[6]&OP_order=$order[7]&com_order=$order[8]&execute=1&directory=$dirs"><FONT color="$color[8]">COMMENTS</FONT></span></td>
</tr>
EOF

}

##PERLDOC##
# Function : printTableRow
# Argument : %localhash - The hash which holds each row entry
# Globals  : NONE 
# Returns  : 0 - Success
# Descript : Parses and prints out each row of data (each directory entry).
# Notes    : This is a helper function to &printOut.
##ENDPERLDOC##
sub printTableRow {
	local(%localhash) = @_;  # takes in one row hash at a time

	%months = (Jan => "01", Feb => "02", Mar => "03", Apr => "04", May => "05", Jun => "06", 
				Jul => "07", Aug => "08", Sep => "09", Oct => "10", Nov => "11", Dec => "12");
	
	$localhash{year} =~ /\d\d(\d+)/;
	$shortYear = $1;

	# date parsing 
	$oldDate = "$localhash{wkday} $localhash{mon} $localhash{mday} $localhash{hour}:$localhash{minute}:$localhash{sec} $localhash{year}";
	$newDate = "$months{$localhash{mon}}\/$localhash{mday}\/$shortYear $localhash{hour}:$localhash{minute}:$localhash{sec}";

	# hard coded fix for sequence links (handles server name changes)
	$localhash{seqlink} =~ s/\S%3A%2FSequest/$seqdir/;
	
	print <<EOF;
<tr>
	<td width=1><a href=\"$createsummary?directory=$localhash{dir}&sort=consensus\" target=\"_blank\"><span class="smalltext"><nobr>$fancyname{$localhash{dir}}</nobr></a></span></td>
	<td width=1>&nbsp;&nbsp;<a href=\"$fuzzyions?dtafile=$seqdir\/$localhash{dir}\/$localhash{dtafile}\.$localhash{zValue}\.dta\" target=\"_blank\"><span class="smalltext"><nobr>$localhash{dtafile}</nobr></a></span></td>
	<td align="right">&nbsp;<span class="smalltext"><nobr>$localhash{mhValue}</nobr></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smalltext"><nobr>$localhash{zValue}</nobr></span></td>
	<td width=1>&nbsp;<a $localhash{seqlink} target=\"_blank\"><span class="smalltext"><nobr>$localhash{actualSeq}</a></nobr></span></td>
	<td width=1 title="$oldDate">&nbsp;&nbsp;<span class="smalltext"><nobr>$newDate</nobr></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smalltext"><nobr>$localhash{initials}</nobr></span></td>
	<td width=1>&nbsp;&nbsp;<span class="smalltext"><nobr>$localhash{comments}</nobr></span></td>
</tr>
EOF
}

##PERLDOC##
# Function : allTheHashesIn
# Argument : NONE
# Globals  : NONE
# Returns  : 0 - Success
# Descript : Sorting routine which sorts based on the selected category first; secondary sorting is done in ascending order down
#			 the columns.
# Notes    : 
##ENDPERLDOC##
sub allTheHashesIn { # sort routine

	my $return_val;
	if ($val) {    # numerical comparisons, not ascii - need this separate case
		if ($column1_order%2 != 0) {    # all ascending order
			$return_val = $$a{$column[1]} <=> $$b{$column[1]};  
		} else {                        # first (selected) column descending order
			$return_val = $$b{$column[1]} <=> $$a{$column[1]};   
		}
	} else {
		if ($column1_order%2 != 0) {    # ascending, for ascii sorting 
			$return_val = $$a{$column[1]} cmp $$b{$column[1]}
		} else {                        # first (selected) column descending
			$return_val = $$b{$column[1]} cmp $$a{$column[1]}; 
		}
	}
	return $return_val || &compareRest; # all other columns ascending, in order
}

##PERLDOC##
# Function : compareRest
# Argument : NONE
# Globals  : NONE
# Returns  : 0 - Success
# Descript : Performs the secondary sorting of all the rows in ascending order, down the columns
# Notes    : This is helper function to &allTheHashesIn. 
##ENDPERLDOC##
sub compareRest {

	my $temp_cmp;
	if ($val) {
		$temp_cmp = $$a{$column[4]} <=> $$b{$column[4]}  #val
	} else {
		$temp_cmp = $$a{$column[4]} cmp $$b{$column[4]}
	}

	$$a{$column[2]} cmp $$b{$column[2]} ||
	$$a{$column[3]} cmp $$b{$column[3]} || $temp_cmp ||
	$$a{$column[5]} <=> $$b{$column[5]} ||	#val	
	$$a{$column[6]} <=> $$b{$column[6]} ||	#val
	$$a{$column[7]} cmp $$b{$column[7]} ||
	$$a{$column[8]} cmp $$b{$column[8]}; 
}

##PERLDOC##
# Function : removeDupes
# Argument : $selected_column - The column in which to search for duplicates
# Globals  : NONE
# Returns  : 0 - Success
# Descript : Parses out duplicate data entries, saves only the latest entry
# Notes    : This function only needs to make 2 passes through the raw list of rows to pull out unique rows.
##ENDPERLDOC##
sub removeDupes {  
	local(@raw_hashes_array, @unique_list, $selected_column, %most_recent_rows);
	($selected_column, @raw_hashes_array) = @_;
	@unique_list = ();  #array of hashes
	%most_recent_rows = (); #lookup table for most up-to-date rows
	%recent_check = ();

	# for debug
	#foreach (@raw_hashes_array) {
	#	print "<br>RAW_DIR: $$_{\"dir\"} RAW_DTA: $$_{\"dtafile\"} RAW_TIME: $$_{\"actualTime\"}";
	#}
	#print "<br>";

	if ($selected_column ne "actualTime") {

		# first pass to set up an up-to-date lookup table - gets the latest rows ONLY
		foreach (@raw_hashes_array) {
			my ($raw_column) = $$_{"$selected_column"};
			my ($raw_time) = $$_{"actualTime"};

			# for debug
			#print "<br>FIRST PASS: raw_column: $raw_column raw_time: $raw_time";
		
			if ($raw_time > $most_recent_rows{$raw_column}) {
				$most_recent_rows{$raw_column} = $raw_time;
			}
		} 

		#print "<br>";

		# second pass to extract out unique rows by refering to the up-to-date lookup table 
		foreach (@raw_hashes_array) {
			my ($raw_column) = $$_{"$selected_column"};
			my ($raw_time) = $$_{"actualTime"};

			# for debug
			#print "<br>SECOND PASS: raw_column: $raw_column raw_time: $raw_time";

			if ($raw_time == $most_recent_rows{$raw_column} && !$recent_check{$raw_column}) {
				push @unique_list, $_;
				$recent_check{$raw_column} = 1;
			}
		} 

	} # end of if


	# for debug
	#print "<br><br>unique_list contents:";
	#foreach (@unique_list) {
	#	print "<br>$$_{\"$selected_column\"} $$_{\"actualTime\"}";
	#}
	#print "<br>";

	@unique_list;  # return the compiled unique rows
}

##PERLDOC##
# Function : printOut
# Argument : @the_rows - The array of sorted rows
# Globals  : NONE
# Returns  : 0 - Success
# Descript : Prints out all the .fuz rows in sorted order
# Notes    : 
##ENDPERLDOC##
sub printOut {
	local(@the_rows) = @_;

	foreach (@the_rows) {
		&printTableRow(%{$_});
	}
}

##PERLDOC##
# Function : secondarySortOrder
# Argument : NONE
# Globals  : NONE
# Returns  : 0 - Success
# Descript : Sets the secondary sorting preference once a column has been selected.
# Notes    : 
##ENDPERLDOC##
sub secondarySortOrder {

	my @column_names = ("dir", "dtafile", "mhValue", "zValue", "actualSeq", "actualTime", "initials", "comments");
	my $index = 2;

	foreach my $name (@column_names) {
		if ($name ne $column[1]) {
			$column[$index] = $name;
			$index++;
		}
	}
}

##PERLDOC##
# Function : inList
# Argument : $member - The element to check for in list
# Argument : @list   - The list in which we look for member
# Globals  : NONE
# Returns  : 0 - Member is not in list
# Returns  : 1 - Member is in list
# Descript : Basic function which checks to see if a value is an element in the given array. 
# Notes    :
##ENDPERLDOC##
sub inList {

	(my $member, my @list) = @_;
	foreach $element (@list) {
		if ($member == $element) { return 1; }
	}
	return 0;
}

#######################################
# Main form subroutine

##PERLDOC##
# Function : outputForm
# Argument : NONE
# Globals  : NONE
# Returns  : 0 - Success
# Descript : Prints out main qter-cool form, which includes a dropbox to indicate in which directories to search for .fuz files.
# Notes    : 
##ENDPERLDOC##
sub outputForm {
	print <<EOFORM;
<div>
<FORM METHOD=post ACTION="$ourname">
<span class=smallheading>Qter-Cool allows one to review logged FuzzyIon interpretations</span><p>
<span class=smallheading>Select directories to review:</span><br>
<input type="hidden" name="checks" value="">
<input type="hidden" name="sort_column" value="2">
<input type="hidden" name="change_order" value="1">
<input type="hidden" name="dir_order" value="0">
<input type="hidden" name="dta_order" value="0">
<input type="hidden" name="mh_order" value="0">
<input type="hidden" name="Z_order" value="0">
<input type="hidden" name="seq_order" value="0">
<input type="hidden" name="date_order" value="0">
<input type="hidden" name="OP_order" value="0">
<input type="hidden" name="com_order" value="0">
<input type="hidden" name="execute" value=1>
<span class=dropbox>
<SELECT NAME="directory" multiple size=20>
EOFORM

  &get_alldirs();       # make pulldown menu
  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }

  print <<EOFORM2;
</SELECT>
</span>
<br>
<br>
  
<INPUT TYPE=SUBMIT CLASS=button VALUE="Q-Cool It">
</FORM>
</div>
EOFORM2
}

##PERLDOC##
# Function : error 
# Argument : $error - error message to be printed out 
# Globals  : NONE
# Returns  : NONE - Exits out of code with a 1 for an error
# Descript : Generic error function which displays error message and exits.
# Notes    : 
##ENDPERLDOC##
sub error {
	&MS_pages_header("Qter-Cool","#ff0000");

	exit 1;
}
