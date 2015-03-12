use 5.0.18;
use warnings;
use strict;
use utf8;

use Test::More;
use Data::Dumper;

use Walk;

my $walk = Walk->new();

sub get_maxweight {
  my $url = shift;

  my ($links, $images) = $walk->get_data($url);

  my @lweight = weigh_all($links);
  my @iweight = weigh_all($images);

  my ($tl, $l) = @{$lweight[-1]};
  my ($ti, $i) = @{$iweight[-1]};

  return ($l, $i);
}

my @wtests = (
  ["http://www.dangerouslychloe.com/strips-dc/teenage_hormones",
   qr/The (next|previous) comic/,
   qr/dc20150309\.png/],
  ["http://www.biblecomic.net/archive/rebound-page-167",
   qr/(next|previous)-webcomic-link/,
   qr/015-03-11-rebound-page-167\.jpg/],
  ["http://www.schlockmercenary.com/2015-03-02",
   qr/nav-(previous|next)/,
   qr/comics\/schlock20150302\.jpg/],
  ["http://www.xkcd.com/1306",
   qr/< Prev|Next >/,
   qr//], # TODO can this be done? qr/sigil_cycle\.png/]
  ["http://www.questionablecontent.net/view.php?comic=2800",
   qr/Previous|Next/,
   qr/comics\/2800\.png/],
  ["http://www.dumbingofage.com/2014/comic/book-4/04-the-whiteboard-dong-bandit/cleaning/",
   qr/navi-(next|previous)/,
   qr/2014-09-19-cleaning\.png/]
);

for my $t (@wtests) {
  my ($url, $ltest, $itest) = @$t;
  my ($l, $i) = get_maxweight $url;

  like($l->contprint(), $ltest, "L " . $url);
  like($i->url(), $itest, "I " . $url);
}

done_testing();
