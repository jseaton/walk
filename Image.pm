package Image;
use parent 'Node';

use List::Util qw(sum);
use Algorithm::Diff qw(LCS);

use constant W_IMGTYPE  => 1.0;
use constant W_PAGES    => 4.0;
use constant W_TITLE    => 4.0;
use constant W_SIZE     => 2.0;

sub _init {
  my $self = shift;
  $self->SUPER::_init;

  $self->{title} = @{$self->raw->root->find('title')->content_list}[0];

  $self->{width}  = $self->raw->attr('width');
  $self->{height} = $self->raw->attr('height');
}
  
sub _url {
  my $self = shift;
  return $self->raw->attr('src');
}

sub samesite {
  my $self = shift;
  my $super = $self->SUPER::samesite;
  return ($super or $self->{url}->host =~ m/\Q$self->{base}\E$/);
}

sub imgtype {
  my $self = shift;
  return $self->path =~ /\.jpg$/;
}

sub pagematches {
  my $self = shift;

  my $url   = lc $self->path;
  my $part = (grep { $_ ne "" } split(/\?|\//, $self->page))[-1];
  
  $url   =~ s/[^a-z0-9]//g;
  $part  =~ s/[^a-z0-9]//g;

  my ($matches) = $url =~ /\Q$part\E/gi;

  return log(1 + length($matches));
}

sub titlematches {
  my $self = shift;

  my $url   = lc $self->path;
  my $title = lc $self->{title};

  $url   =~ s/[^a-z0-9]//g;
  $title =~ s/[^a-z0-9]//g;

  my @url   = split(//, $url);
  my @title = split(//, $title);

  my @lcs = LCS(\@url, \@title);

  return log(1 + length(@lcs));
}

sub size {
  return log(1 + ($self->{width} or 20)/20.0 + ($self->{height} or 20)/20.0);
}

sub weight {
  my $self = shift;
  return (
    $self->SUPER::weight,
    (W_IMGTYPE  * $self->imgtype),
    (W_PAGES    * $self->pagematches),
    (W_TITLE    * $self->titlematches),
    (W_SIZE     * $self->size)
  );
}

1;
