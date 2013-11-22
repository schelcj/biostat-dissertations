#!/usr/bin/perl

## no critic (ProhibitVoidMap,ProhibitMagicNumbers)
## no critic (RequireLocalizedPunctuationVars,ProhibitComplexMappings)

use Modern::Perl;
use Class::CSV;
use JSON;
use Getopt::Compact;
use List::MoreUtils qw(all none uniq any);
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

my @JSON_FIELDS = (qw(name committee year title));
my @DISS_FIELDS = (qw(name role committee_member term title));
my @BO_FIELDS   = (
  qw(
    emplid name degree_descrshort acad_prog_descr term
    degr_confer_dt acad_sub_plan_descr trnscr_descr
    role committee_member title
    )
);

# TODO compare old and new diss data
# TODO merge new and old data
# TODO write out new diss json data

my $bo_data              = get_bo_data($opts->{bo_file}, $opts->{year});
my $dissertations        = get_dissertations($opts->{input_dissertations});
my $json_data            = build_json($bo_data);
my $merged_dissertations = merge_dissertations($dissertations, $json_data);

write_json($merged_dissertations);

sub get_dissertations {
  my ($file) = @_;
  my $json = from_json(read_file($file));
  return [map {my %a = (); @a{@JSON_FIELDS} = @{$_}; \%a} @{$json->{aaData}}];
}

sub get_bo_data {
  my ($file, $year) = @_;

  my $diss_data = {};
  my $fields    = \@DISS_FIELDS;
  my $in_csv    = Class::CSV->parse(filename => $file, fields => \@BO_FIELDS);
  my @lines     = @{$in_csv->lines()};

  shift @lines;    # remove the header row
  pop @lines;      # there is cruft on the last line, no idea why

  for my $line (@lines) {
    next if $line->term !~ /$year/;
    next if $line->role !~ /coch|chai/i;

    my $name = reverseName(cleanName($line->name));

    if ($line->committee_member) {
      my $committee_member = reverseName(cleanName($line->committee_member));
      if (  none {$_ eq $committee_member} @{$diss_data->{$name}{committee_members}}
        and none {samePerson($_, $committee_member)} @{$diss_data->{$name}{committee_members}})
      {
        push @{$diss_data->{$name}{committee_members}}, $committee_member;
      }
    }

    $diss_data->{$name}{titles} = [];

    if ($line->title !~ /^\s*$/) {
      my $title = $line->title;
      chomp($title);
      push @{$diss_data->{$name}{titles}}, $title;
    }

    ($diss_data->{$name}{year} = $line->term) =~ s/\D//g;
    $diss_data->{$name}{name} = $name;
  }

  return $diss_data;
}

sub build_json {
  my ($student_ref) = @_;
  my $param_ref = [];

  for my $student (keys %{$student_ref}) {
    my $title = join(q{ }, uniq @{$student_ref->{$student}{titles}});
    ($title = autoformat($title, {case => 'highlight'}) || q{}) =~ s/[\n\r]+//g;

    my $committee;
    my @members = uniq @{$student_ref->{$student}{committee_members}};
    given (scalar @members) {
      when ($_ >= 3) {$committee = join(q{, and }, @members)}
      when ($_ >= 2) {$committee = join(q{ and },  @members)}
      default        {$committee = join(q{},       @members)}
    }

    push @{$param_ref}, {
      name      => reverseName(cleanName($student)),
      committee => $committee,
      year      => $student_ref->{$student}{year},
      title     => $title,
      };
  }

  return $param_ref;
}

sub merge_dissertations {
  my ($current, $new) = @_;

  my @list     = @{$current};
  my @students = map {$_->{name}} @{$current};

  for my $student (@{$new}) {
    if (not any {/$student->{name}/} @students) {
      push @list, $student;
    }
  }

  return \@list;
}

sub write_json {
  my ($dissertations) = @_;
  my @json_data = sort {$a->{year} <=> $b->{year}} @{$dissertations};
  print Dumper \@json_data;
  return;
}
