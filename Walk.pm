package Walk;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(compare_all weigh_all print_pairs print_weights unseen nodes);

use 5.0.18;
use warnings;
use strict;
use utf8;

use WWW::Mechanize;
use WWW::Mechanize::TreeBuilder;
use Data::Dumper;
use List::MoreUtils qw(pairwise);
use List::Util qw(sum);
use URI::URL ();

use Image;
use Link;

binmode(STDOUT, ":utf8");

use constant W_SELECT => 10;

sub new {
  my $class = shift;
  my $mech = WWW::Mechanize->new();
  WWW::Mechanize::TreeBuilder->meta->apply($mech);
  return bless {mech => $mech, seen => {}}, $class;
}

sub filter {
  my $page = shift;
  my $name = shift;
  return grep { $_->is_http and $_->samesite } map { $name->new($_, $page) } grep { defined $_ } @_[0 .. 200];
}

sub unseen {
  my ($self, $n) = @_;
  return (not $n->same and not $self->{seen}->{$n->abs});
}

sub compare_all {
  my ($as, $bs) = @_;
  my @good;
  for my $a (@$as) {
    for my $b (@$bs) {
      my @t = $a->compare($b);
      my $sum = sum @t;
      if ($sum >= W_SELECT) {
        push @good, [$sum, $a, $b, \@t];
      }
    }
  }

  return sort { $a->[0] <=> $b->[0] } @good;
}

sub weigh_all {
  my ($as) = @_;
  my @good;
  for my $a (@$as) {
    my @t = $a->weight();
    my $sum = sum @t;
    if ($sum >= 0) {
      push @good, [$sum, $a, \@t];
    }
  }

  return sort { $a->[0] <=> $b->[0] } @good;
}

sub print_pairs {
  my @good = @_;
  for my $e (@good >= 30 ? @good[ -30 .. -1 ] : @good) {
    my ($t, $a, $b) = @$e;
    print "$t\n";
    print "AAAA ", $a->print();
    print "BBBB ", $b->print();
    print "\n";
  }
}

sub print_weights {
  my @good = @_;
  for my $e (@good) {
    my ($t, $a, $w) = @$e;
    print $t, " ", join(",", @$w), " ", $a->print();
  }
}

sub get_data {
  my ($self, $url) = @_;
  print "$url\n";
  my $mech = $self->{mech};
  $self->{seen}->{$url} = 1;

  my (@al, @ai);
  eval {
    $mech->get($url);
    @al = filter $url, "Link", $mech->find('a');
    @ai = filter $url, "Image", $mech->find('img');
  };

  return (undef, undef) if $@;

  return (\@al, \@ai);
}
