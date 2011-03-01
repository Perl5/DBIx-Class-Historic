use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
  require DBIx::Class;
  plan skip_all => 'Test needs ' . DBIx::Class::Optional::Dependencies->req_missing_for ('test_poe_easydbi')
    unless DBIx::Class::Optional::Dependencies->req_ok_for ('test_poe_easydbi');
}

use lib qw(t/lib);
use DBICTest;
use POE;

my $artist_num = -3;

POE::Session->create(
  inline_states => {
    _start => sub {
      $_[HEAP]{schema} = DBICTest->init_schema(
        no_populate  => 1,
        storage_type => '::DBI::POE::EasyDBI',
      );
      $_[KERNEL]->yield('do_creates');
      $_[KERNEL]->yield('do_creates');
    },
    do_creates => sub {
      my $ars = $_[HEAP]{schema}->resultset('Artist');

      $artist_num += 3;

      my $i = $artist_num;

      $ars->create({ name => "Artist ".($i++) });
      $ars->create({ name => "Artist ".($i++) });
      $ars->create({ name => "Artist ".($i++) });

      $_[KERNEL]->yield('creates_done');
    },
    creates_done => sub {
      my $ars = $_[HEAP]{schema}->resultset('Artist');

      return unless $ars->count == 6 && (not $_[HEAP]{creates_done_ran});

      my $seq = join ',', map /(\d+)/, map $_->name, $ars->all;

      isnt $seq, '0,1,2,3,4,5', 'records were not inserted synchronously';

      $_[HEAP]{creates_done_ran} = 1;
    },
  },
);

$poe_kernel->run;

done_testing;

# vim:sw=2 sts=2:
