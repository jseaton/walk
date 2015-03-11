package Node;

use Data::Dumper;
use Memoize;
use List::Util qw( sum );
use List::MoreUtils qw( pairwise );
use Text::LevenshteinXS qw(distance);
use URI::URL ();

sub new {
  my $class = shift;
  my ($raw, $base, $page) = @_;
  my $self = {
    raw => $raw,
    url => $raw->attr('href'),
    tag => $raw->tag(),
    base => $base,
    page => URI::URL->new($page)->full_path
  };
  bless $self, $class;

  $self->_init();

  return $self;
}

sub _init {
  my $self = shift;
  my @indexes = reverse map {
    my @left  = $_->left();
    my @right = $_->right();
    { tag => $_->tag(), left => scalar @left, right => scalar @right }
  } $self->raw()->lineage();
  $self->{sibind} = \@indexes;

  my @list = grep { $_ ne "" } map {
    if (ref $_ eq "HTML::Element") {
      #$_->as_HTML();
      join(",", grep { $_ ne "" } ($_->attr('alt'), $_->attr('class'), $_->attr('rel'), $_->id(), $_->attr('src')));
    } else {
      $_;
    }
  } $self->raw()->content_list(), $self->raw();
  $self->{content} = \@list;
  
  $self->{rel} = $self->{raw}->attr('rel');
}

sub raw {
  my $self = shift;
  return $self->{raw};
}

sub url {
  my $self = shift;
  my $url = $self->{url};
  $url =~ s/^\Q$self->{base}\E//;
  $url = "/" if $url eq "";
  return $url;
}

sub tag {
  my $self = shift;
  return $self->{tag};
}

sub page {
  my $self = shift;
  return $self->{page};
}

sub sibind {
  my $self = shift;
  return $self->{sibind};
}

sub sibprint {
  my $self = shift;
  return join('|', map { $_->{left} . $_->{tag} . $_->{right} } @{$self->{sibind}});
}
memoize('sibprint');

sub content {
  my $self = shift;
  return $self->{content};
}

sub contprint {
  my $self = shift;
  return join("|", @{$self->{content}});
}
memoize('contprint');

sub rel {
  my $self = shift;
  return $self->{rel};
}
  
sub samesite {
  my $self = shift;
  return ($self->{url} =~ /^\Q$self->{base}\E/ or $self->{url} !~ /^https?:\/\//);
}

sub prev_next {
  my $self = shift;
  return $self->contprint() =~ /prev|next|forward|back/i;
}

use constant W_INDEX         => 5.0;
use constant W_INDEX_LEFT    => 0.7;
use constant W_INDEX_RIGHT   => 0.1;
use constant W_INDEX_SAME    => 4.0;
use constant W_INDEX_MISSING =>-8.0;
use constant W_INDEX_DECAY   => 0.9;
use constant W_CONTENT       => 5.0;
use constant W_CONTENT_EMPTY => 0.001;
use constant W_URL           => 4.0;
use constant W_REL           =>50.0;
use constant W_PREV_NEXT     => 2.0;
use constant W_FRIENDS       => 2.0;

sub sibcompare {
  my ($an, $bn) = @_;
  my @a = @{$an->sibind()};
  my @b = @{$bn->sibind()};

  my $exp = 1.0 / W_INDEX_DECAY;

  my $total = sum pairwise {
    return W_INDEX_MISSING if not defined $a or not defined $b;
    $exp *= W_INDEX_DECAY;

    W_INDEX_SAME  * ($a->{tag} eq $b->{tag}) +
    W_INDEX_LEFT  * $exp / (1.0 + abs($a->{left}  - $b->{left})) +
    W_INDEX_RIGHT * $exp / (1.0 + abs($a->{right} - $b->{right}))
  } @a, @b;

  return 2.0 * $total / (@a + @b);
}

sub contcompare {
  my @a = @{shift->content()};
  my @b = @{shift->content()};

  return W_CONTENT_EMPTY if @a == 0 or @b == 0;
  my $total = sum pairwise { 1.0 / (1 + distance($a, $b)) } @a, @b;

  return 2.0 * $total / (@a + @b);
}

sub urlcompare {
  my ($a, $b) = @_;
  my $dist = 1.0 / (1 + distance($a->url(), $b->url()));
  return $dist == 1 ? -1 : $dist;
}

sub friends {
  my ($a, $b) = @_;
  my $dist_ab = 1.0 / (1 + distance($a->url(), $b->page()));
  my $dist_ba = 1.0 / (1 + distance($b->url(), $a->page()));
  return $dist_ab + $dist_ba;
}
    
sub compare {
  my ($a, $b) = @_;

  my @t = (
    (W_INDEX     * sibcompare($a, $b)),
    (W_CONTENT   * contcompare($a, $b)),
    (W_URL       * urlcompare($a, $b)),
    # Try not to use these, since they overwhelm other heuristics
    #(W_PREV_NEXT * ($a->prev_next() and $b->prev_next())),
    #(W_REL       * (rel($a) ne "" and rel($b) ne "" and rel($a) eq rel($b))),
    (W_FRIENDS   * friends($a, $b))
  );
  #print $a->contprint(), " ", $b->contprint(), " ", $a->url(), " ", $b->url(), " ", Dumper(\@t);
  return sum @t;
}

1;
