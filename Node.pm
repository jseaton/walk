package Node;

use Data::Dumper;
use Memoize;
use List::Util qw(sum);
use List::MoreUtils qw(pairwise);
use Text::LevenshteinXS qw(distance);
use URI::URL ();

use constant W_INDEX         => 2.0;
use constant W_INDEX_LEFT    => 0.7;
use constant W_INDEX_RIGHT   => 0.1;
use constant W_INDEX_DIFF    =>-9.0;
use constant W_INDEX_MISSING =>-8.0;
use constant W_INDEX_DECAY   => 0.9;
use constant W_CONTENT       => 5.0;
use constant W_CONTENT_EMPTY => 0.001;
use constant W_URL           => 8.0;
use constant W_REL           =>50.0;
use constant W_FRIENDS       => 2.0;
use constant W_NUMERIC       => 0.2;
use constant W_URLMATCH      => 0.7;

sub new {
  my $class = shift;
  my ($raw, $page_) = @_;
  my $page = URI::URL->new($page_);
  my $base = $page->host;
  $base  =~ s/^www\.//;

  my $self = {
    raw => $raw,
    tag => $raw->tag,
    base => $base,
    page => $page
  };
  bless $self, $class;

  $self->{url} = URI::URL->new($self->_url, $page->abs);
  $self->_init;

  $self->{raw} = undef;

  return $self;
}

sub _init {
  my $self = shift;
  my @indexes = reverse map {
    my @left  = $_->left;
    my @right = $_->right;
    { tag => $_->tag, left => scalar @left, right => scalar @right }
  } $self->raw->lineage;
  $self->{sibind} = \@indexes;

  my @list = grep { $_ ne "" } map {
    if (ref $_ eq "HTML::Element") {
      join(",", grep { $_ ne "" } ($_->attr('alt'), $_->attr('class'), $_->attr('rel'), $_->id(), $_->attr('src')));
    } else {
      $_;
    }
  } $self->_children;
  $self->{content} = \@list;
  
  $self->{rel} = $self->{raw}->attr('rel');
}

sub _children {
  my $self = shift;
  return $self->raw->content_list;
}

sub raw {
  my $self = shift;
  return $self->{raw};
}

sub path {
  my $self = shift;
  return $self->{url}->full_path;
}
memoize('path');

sub page_path {
  my $self = shift;
  return $self->{page}->full_path;
}
memoize('page_path');

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

sub abs {
  my $self = shift;
  return $self->{url}->abs;
}

sub print {
  my $self = shift;
  return $self->sibprint, " ", $self->contprint, " ", $self->path, "\n";
}

sub is_http {
  my $self = shift;
  return ($self->{url}->scheme =~ /^(https?|)$/);
}

sub samesite {
  my $self = shift;
  return ($self->{url}->host eq "" or $self->{url}->host =~ /^(www\.)?\Q$self->{base}\E$/);
}

sub samepage {
  my $self = shift;
  return ($self->path eq $self->page_path);
}

sub urlmatches {
  my $self = shift;
  my @matches = $self->path =~ /comic/;
  return log(1 + @matches);
}

sub numeric {
  my $self = shift;
  my @num = $self->path =~ /[0-9]+/g;

  return log(1 + sum map { length $_ } @num);
}

sub weight {
  my $self = shift;
  return ( 
    (W_URLMATCH * $self->urlmatches),
    (W_NUMERIC  * $self->numeric)
  );
}
memoize('weight');

sub sibcompare {
  my ($an, $bn) = @_;
  my @a = @{$an->sibind};
  my @b = @{$bn->sibind};

  my $exp = 1.0 / W_INDEX_DECAY;

  my $total = sum pairwise {
    return W_INDEX_MISSING if not defined $a or not defined $b;
    $exp *= W_INDEX_DECAY;

    W_INDEX_DIFF  * ($a->{tag} ne $b->{tag}) +
    W_INDEX_LEFT  * $exp / (1.0 + abs($a->{left}  - $b->{left})) +
    W_INDEX_RIGHT * $exp / (1.0 + abs($a->{right} - $b->{right}))
  } @a, @b;

  return 2.0 * $total / (@a + @b);
}

sub contcompare {
  my @a = @{shift->content};
  my @b = @{shift->content};

  return W_CONTENT_EMPTY if @a == 0 or @b == 0;
  my $total = sum pairwise { 1.0 / (1 + distance($a, $b)) } @a, @b;

  return 2.0 * $total / (@a + @b);
}

sub urlcompare {
  my ($a, $b) = @_;
  return -2 if $a->path eq $b->path;
  return (-0.001 * abs(length($a->path) - length($b->path))) + (1.0 / (1 + distance($a->path, $b->path)));
}

sub compare {
  my ($a, $b) = @_;

  my @aw = $a->weight;
  my @bw = $b->weight;

  my $sim = -abs(sum @aw - sum @bw);

  my @t = (
    @aw, @bw, $sim,
    (W_INDEX     * sibcompare($a, $b)),
    (W_CONTENT   * contcompare($a, $b)),
    (W_URL       * urlcompare($a, $b)),
  );
  return @t;
}

1;
