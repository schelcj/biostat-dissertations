#!/usr/bin/perl

use Modern::Perl;
use Getopt::Compact;
use Class::CSV;
use File::Slurp qw(write_file);
use Data::Dumper;

## no tidy
my $opts = Getopt::Compact->new(
  struct => [
    [[qw(f file)], q{Exported Buisness Objects spreadsheet}, q{:s}],
    [[qw(y year)], q{Year to pull records for},              q{:i}],
  ]
)->opts();
## use tidy

my $file    = 'cleaned_bo_report.csv';
my $fields  = [qw(name role committee_member term title)];
my $out_csv = Class::CSV->new(fields => $fields);
my $in_csv  = Class::CSV->parse(
  filename => $opts->{file},
  fields   => [
    qw(
      emplid name degree_descrshort acad_prog_descr term
      degr_confer_dt acad_sub_plan_descr trnscr_descr
      role committee_member title
      )
  ],
);

my @lines = @{$in_csv->lines()};
shift @lines;    # remove the header row
pop @lines;      # there is cruft on the last line, no idea why

$out_csv->add_line({map {$_ => $_} @{$fields}});
for my $line (@lines) {
  next if $line->term !~ /$opts->{year}/;
  $out_csv->add_line({map {$_ => $line->$_} @{$fields}});
}

write_file($file, $out_csv->string());

