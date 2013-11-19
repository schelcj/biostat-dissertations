#!/usr/bin/env perl

use Modern::Perl;
use Spreadsheet::ParseExcel;
use Getopt::Compact;
use Data::Dumper;

## no tidy
my $opts = Getopt::Compact->new(
  struct => [
    [[qw(f file)], q{Exported Buisness Objects spreadsheet}, q{:s}],
    [[qw(y year)], q{Year to pull records for},              q{:s}],
  ]
)->opts();
## use tidy

my @disst  = ();
my $parser = Spreadsheet::ParseExcel->new();
my $wb     = $parser->parse($opts->{file});
my $ws     = $wb->worksheet(0);

my ($col_min, $col_max) = $ws->col_range();
my ($row_min, $row_max) = $ws->row_range();

my $headers = {map {$ws->get_cell(0, $_)->value() => $_} $col_min .. $col_max};

# loop over rows skipping the header row
for my $row ($row_min + 1 .. $row_max) {

  # grab each cell using the headers hashref values
  push @disst, {map {$headers->{$_} => $ws->get_cell($row, $headers->{$_})->value()} keys %{$headers}};
}

print Dumper \@disst;
