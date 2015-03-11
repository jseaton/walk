use 5.0.18;
use warnings;
use strict;
use utf8;

use WWW::Mechanize;
use WWW::Mechanize::TreeBuilder;
use Data::Dumper;
use Carp;
use Carp::Always;
use List::MoreUtils qw( pairwise );
use Devel::Trace qw( trace );
use URI::URL ();

use Node;

binmode(STDOUT, ":utf8");

use constant W_SELECT => 10;

my $mech = WWW::Mechanize->new();
WWW::Mechanize::TreeBuilder->meta->apply($mech);

print "Getting...\n";
$mech->get($ARGV[0]);

print "Finding...\n";
my @a = $mech->find('a');

my $base = URI::URL->new($ARGV[0]);
my $url  = $base->scheme() . $base->host();

sub filter {
  my $page = shift;
  return grep { $_->samesite() } map { Node->new($_, $url, $page) } grep { defined $_ } @_[0 .. 200];
}


print "Filtering...\n";
my @al = filter $ARGV[0], @a;

print "Getting...\n";
$mech->get($ARGV[1]);
print "Finding...\n";
my @b = $mech->find('a');

print "Filtering...\n";
my @bl = filter $ARGV[2], @b;

print "Picking...\n";
print scalar(@al), "\n";
print scalar(@bl), "\n";

my @good;
for my $a (@al) {
  for my $b (@bl) {
    my $t = $a->compare($b);
    if ($t >= W_SELECT) {
      push @good, [$t, $a, $b];
    }
  }
}
print "\n";

print "Sorting...\n";
@good = sort { $a->[0] <=> $b->[0] } @good;

for my $e (@good >= 30 ? @good[ -30 .. -1 ] : @good) {
  my ($t, $a, $b) = @$e;
  print "$t\n";
  print "AAAA ", $a->sibprint(), " ", $a->contprint(), " ", $a->url(), "\n";
  print "BBBB ", $b->sibprint(), " ", $b->contprint(), " ", $b->url(), "\n";
  print "\n";
}
