# README: If you set the env var DBICTEST_THREAD_STRESS to a number greater
# than 10, we will use that many children

use strict;
use warnings;
use Config;

BEGIN {
  my $err;

  if (! $Config{useithreads}) {
    $err = 'your perl does not support ithreads';
  }
  elsif ($] < '5.008005') {
    $err = 'DBIC does not actively support threads before perl 5.8.5';
  }
  elsif ($INC{'Devel/Cover.pm'}) {
    $err = 'Devel::Cover does not work with threads yet';
  }

  if ($err) {
    print "1..0 # SKIP $err\n";
    exit 0;
  }
}

use threads;  # must be loaded before Test::More
use Test::More;

use lib qw(t/lib);
use DBICTest;

plan skip_all => 'Potential problems on Win32 Perl < 5.14 and Variable::Magic - investigation pending'
  if $^O eq 'MSWin32' && $] < 5.014 && DBICTest::RunMode->is_plain;

my $num_children = $ENV{DBICTEST_THREAD_STRESS} || 1;
if($num_children !~ /^[0-9]+$/ || $num_children < 10) {
   $num_children = 10;
}

my $schema = DBICTest->init_schema(no_deploy => 1);
isa_ok ($schema, 'DBICTest::Schema');

my @threads;
push @threads, threads->create(sub {
  my $rsrc = $schema->source('Artist');
  undef $schema;
  isa_ok ($rsrc->schema, 'DBICTest::Schema');
  my $s2 = $rsrc->schema->clone;

  sleep 1;  # without this many tasty crashes
}) for (1.. $num_children);
ok(1, "past spawning");

$_->join for @threads;
ok(1, "past joining");

done_testing;
