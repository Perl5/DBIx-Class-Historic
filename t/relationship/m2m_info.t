use strict;
use warnings;

use Test::More;

use lib qw(t/lib);
use DBICTest;

my $schema = DBICTest->init_schema();

my $cd = $schema->source('CD');
ok( $cd->has_m2m('producers'), 'CD has a producers m2m' );

is_deeply( [ sort $cd->m2ms ],
           [ 'producers', 'producers_sorted' ],
           'got right list of m2ms' );

is_deeply( $cd->m2m_info('producers'),
           { rel  => 'cd_to_producer',
             frel => 'producer',
           },
           'm2m_info for CD producers is right',
         );

done_testing;
