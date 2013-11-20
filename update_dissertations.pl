#!/usr/bin/perl

use Modern::Perl;
use Class::CSV;
use JSON;
use Getopt::Compact;
use List::MoreUtils qw(all none uniq);
use Text::Autoformat;
use Text::Names qw(reverseName cleanName samePerson);
use File::Slurp qw(read_file write_file);
use Data::Dumper;

## no tidy
my $opts = Getopt::Compact->new(
  struct => [
    [[qw(b bo_file)],              q{Exported Buisness Objects spreadsheet}, q{:s}],
    [[qw(y year)],                 q{Year to pull records for from BO data}, q{:i}],
    [[qw(i input_dissertations)],  q{Existing dissertations json data},      q{:s}],
    [[qw(o output_dissertations)], q{New dissertation json data},            q{:s}], 
  ]
)->opts();
## use tidy

my $DISS_FIELDS = [qw(name role committee_member term title)];
my $BO_FIELDS   = [
  qw(
    emplid name degree_descrshort acad_prog_descr term
    degr_confer_dt acad_sub_plan_descr trnscr_descr
    role committee_member title
    )
];

# TODO clean up the BO data
# TODO compare old and new diss data
# TODO merge new and old data
# TODO write out new diss json data

my $bo_data       = get_bo_data($opts->{bo_file}, $opts->{year});
my $dissertations = get_old_json_data($opts->{input_dissertations});

sub get_old_json_data {
  my ($file) = @_;
  my $json = from_json(read_file($file));
  return $json->{aaData};
}

sub get_bo_data {
  my ($file, $year) = @_;

  my $diss_data = [];
  my $fields    = $DISS_FIELDS;
  my $in_csv    = Class::CSV->parse(
    filename => $file,
    fields   => $BO_FIELDS,
  );

  my @lines = @{$in_csv->lines()};
  shift @lines;    # remove the header row
  pop @lines;      # there is cruft on the last line, no idea why

  for my $line (@lines) {
    next if $line->term !~ /$year/;
    push @{$diss_data}, {map {$_ => $line->$_} @{$DISS_FIELDS}};
  }

  return $diss_data;
}
