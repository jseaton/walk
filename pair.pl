use 5.0.18;
use warnings;
use strict;
use utf8;

use Carp;
use Carp::Always;
use Data::Dumper;

use Walk;

binmode(STDOUT, ":utf8");

my $walk = Walk->new();

my ($al, $ai) = $walk->get_data($ARGV[0]);
my ($bl, $bi) = $walk->get_data($ARGV[1]);

print_pairs compare_all($al, $bl);
print "--\n";
print_pairs compare_all($ai, $bi);

print "------\n";
print_weights weigh_all($al);
print "--\n";
print_weights weigh_all($ai);
