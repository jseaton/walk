use 5.0.18;
use warnings;
use strict;
use utf8;

use Carp;
use Carp::Always;
use Data::Dumper;
use Hash::PriorityQueue;

use Walk;

binmode(STDOUT, ":utf8");

my $walk = Walk->new();

my $q = Hash::PriorityQueue->new;

sub add_nodes {
  for my $i (@_) {
    my ($t, $n) = @$i;
    $q->insert($n, -$t);
  }
}

sub get_node {
  my $n;
  do {
    $n = $q->pop;
  } while (defined $n and not $walk->unseen($n));
  return $n;
}

my ($al, $ai) = $walk->get_data($ARGV[0]);

add_nodes weigh_all $al;

my $n = get_node;
die "No Node!" unless defined $n;
my ($bl, $bi) = $walk->get_data($n->abs);

foreach my $i (0..200) {
  if (defined $bl and defined $bi) {
    my @imgs = compare_all($bi, $ai);
    print $imgs[-1]->[0], " ", $imgs[-1]->[1]->print, "\n";
    if ($imgs[-1]->[0] > 5) {
      add_nodes compare_all($bl, $al);
      $al = $bl;
      $ai = $bi;
    } else { print "(ignored)\n"; }
  }

  my $n = get_node;
  last unless $n;
  ($bl, $bi) = $walk->get_data($n->abs);
}
