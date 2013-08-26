use warnings;
use strict;

use Test::More;
use lib 't/lib';

use DBICTest::Util::LeakTracer qw( populate_weakregistry assert_empty_weakregistry run_and_populate_weakregistry );

my $reg = {};

my $foo = { bar => {} };

my @x = run_and_populate_weakregistry {

  my @y = sub {
    $_[0]->{bar}{baz} = $_[0]->{bar};
    return [];
  }->($foo);

  eval {
    die;
  } or return []
} $reg;

use Data::TreeDumper;
use Data::Dumper;
warn DumpTree ([$foo, $reg ], 'bah', DISPLAY_PERL_ADDRESS => 1);
#warn Dumper $reg;

my $x = 1;

$x *= 2;


END {
  assert_empty_weakregistry($reg);
  print "ok 1\n1..1\n";
}
