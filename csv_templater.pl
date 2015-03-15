#!/usr/bin/env perl
#A perl script for substituting csv data into a template file
#depends: Text::CSV perl module.

use strict;
use warnings;
use Text::CSV;
use Getopt::Std;

#constants
use constant BGN_DELIM    => ":::";
use constant END_DELIM    => ":::";

#set file locations <-- Change to command line args
my $CSV_FILE = "data.csv";
my $TEMPLATE_FILE = "template.txt";

#parse command line
my %args;
getopt('dt', \%args);

if($args{'h'}){
	print "\nUsage: csv_templater.pl [switches]\n -c filename\t CSV file [default: data.csv]\n -h\t\t This help text\n -t filename\t Template file [default: template.txt]\n\n";
	exit 0
}
if($args{'d'}){  $CSV_FILE = $args{'d'}; }
if($args{'t'}){  $TEMPLATE_FILE = $args{'t'}; }


#load template
open (my $fh, '<', $TEMPLATE_FILE) or die "Couldn't open template file ($TEMPLATE_FILE): $!. Use -h flag for help.\n"; 
	my $template = join("", <$fh>);
close $fh;


#load CSV
my $csv = Text::CSV->new ({binary => 1, auto_diag => 1, allow_whitespace => 1});
open($fh, '<', $CSV_FILE) or die "Couldn't open csv file ($CSV_FILE): $!. Use -h flag for help.\n"; 
	$csv->column_names ($csv->getline ($fh)); # use first line for column names
	my $data = $csv->getline_hr_all($fh);
close $fh;


#subroutines
sub get_category_names {
	my ($col, $dat) = @_;
	return do { my %seen; grep { !$seen{$_}++ } map { %{$_}{$col}."" } @$dat; };
}

sub get_category_rows {
	my ($cat, $col, $dat) = @_;	
	return grep { $_->{$col} eq $cat } @$dat;
}

sub replace_elements {
	my ($tmplt, $row_hash) = @_;
	#my @cs = our @cols;
	#print "@cs"."\n";
	foreach my $c ( our @cols ) {	
		my $rpl = BGN_DELIM.$c.END_DELIM;
		#print $rpl."\n";	
		#my %r = %$row_hash;
		my $val = %$row_hash{$c};
		#print $rpl, $val;
		$tmplt =~ s/$rpl/$val/g;		
	}
	#print $tmplt;
	return $tmplt;
}

sub replace_loops {
	my ($tmplt, $rows) = @_;
	my $start_delim = BGN_DELIM."FOREACH".END_DELIM;
	my $end_delim = BGN_DELIM."END".END_DELIM;
	(my @loops)= $tmplt =~ /$start_delim(.*?)$end_delim/gs;
	$tmplt =~ s/$start_delim(.*?)$end_delim/:::SECTION_TO_BE_REPLACED:::/gs;
	my $output = "";
	foreach my $loop (@loops){
		foreach my $row ( @$rows ) { #for each data row
			$output = $output. replace_elements ($loop, $row);
		}
		$tmplt =~ s/:::SECTION_TO_BE_REPLACED:::/$output/;
	}
	return $tmplt
}

#column names
our @cols = $csv->column_names();

#check for templates for each column
foreach my $col ( @cols ) { #for each column

	my $start_delim = BGN_DELIM."FOREACH $col".END_DELIM;
	my $end_delim = BGN_DELIM."END $col".END_DELIM;
	(my @sub_templates)= $template =~ /$start_delim(.*?)$end_delim/gs;
	next unless @sub_templates; #break if no sub_templates for this category

	#pull the sub_templates out of the main string
	$template =~ s/$start_delim(.*?)$end_delim/:::SECTION_TO_BE_REPLACED:::/gs;
	#find the categories in this column
	my @cats = get_category_names ($col, $data);

	#fill out each sub template, then replace it in the maim
	foreach my $sub_tmplt ( @sub_templates ){		
		my $output = "";
		foreach my $cat ( @cats ) { #for each category
			my $sub_tmplt_copy = $sub_tmplt;
			#replace category names
			my $x =  BGN_DELIM.$col.END_DELIM;
			$sub_tmplt_copy =~ s/$x/$cat/g;
			#replace values, pull out rows in this category
			my @cat_rows = get_category_rows ($cat, $col, $data);
			$sub_tmplt_copy = replace_loops ($sub_tmplt_copy, \@cat_rows);
			$output = $output . $sub_tmplt_copy;
		}
		#replace a single instance with the new output
		$template =~ s/:::SECTION_TO_BE_REPLACED:::/$output/;
	}
}

#replace any other loops using the full dataset
$template = replace_loops ($template, $data);

print $template;

