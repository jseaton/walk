package Link;
use parent 'Node';

use Text::LevenshteinXS qw(distance);

use constant W_PREV_NEXT     => 2.0;

sub _url {
  my $self = shift;
  return $self->raw->attr('href');
}

sub _children {
  my $self = shift;
  return ($self->SUPER::_children, $self->raw);
}

sub prev_next {
  my $self = shift;
  return $self->contprint =~ /prev|next|forward|back/i;
}

sub same {
  my $self = shift;
  my $url  = $self->abs;
  my $page = $self->page->abs;
  $url  =~ s/\/*#?$//;
  $page =~ s/\/*#?$//;
  return $url eq $page;
}

sub friends {
  my ($a, $b) = @_;
  my $dist_ab = 1.0 / (1 + distance($a->path, $b->page->path));
  my $dist_ba = 1.0 / (1 + distance($b->path, $a->page->path));
  return $dist_ab + $dist_ba;
}

sub compare {
  my ($a, $b) = @_;
  return (
    $a->SUPER::compare($b),
    # Try not to use these, since they overwhelm other heuristics
    #(W_PREV_NEXT * ($a->prev_next() and $b->prev_next())),
    #(W_REL       * (rel($a) ne "" and rel($b) ne "" and rel($a) eq rel($b))),
    (W_FRIENDS   * friends($a, $b)),
  );
}

sub weight {
  my $self = shift;
  return (
    $self->SUPER::weight,
    (W_PREV_NEXT * $self->prev_next),
  );
}

1;
