use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;
use lib qw(t/lib);
use DBICTest;
use DBIx::Class::_Util 'sigwarn_silencer';
use Path::Class::File ();
use Math::BigInt;
use List::Util qw/shuffle/;
use Storable qw/nfreeze dclone/;

my $schema = DBICTest->init_schema();

my $artists = $schema->resultset('Artist');

{
  my $counter = 1;
  sub get_counter {
    if ($counter <= 5) {
      $counter++;
      return [ (101+$counter), 'T1.' . (101+$counter) ];
    } else {
      return undef;
    }
  }
}

#
# Tests for CODE references in populate
#

$schema->populate('Artist', [ [ qw/artistid name/ ], 
   [ 100, "T1.100" ],
   [ 101, "T1.101" ],
   \&get_counter,
   [ 110, "T1.110" ],
   [ 111, "T1.111" ],
]);

cmp_ok($artists->search({ name => { LIKE => 'T1%' } }), 
       '==', 
       9, 'Got 9 records populated in T1'
);

throws_ok(sub {
  $schema->populate('Artist', [ [ qw/artistid name/ ], 
    [ 201, "T2.201" ],
    [ 202, "T2.202" ],
    sub { die "Failed miserably" },
    [ 203, "T2.204" ],
    [ 204, "T2.205" ],
  ]);
}, qr/Failed miserably/, 'An invoked sub died');
cmp_ok($artists->search({ name => { LIKE => 'T2%' } })->count, 
       '==', 
       0, 'Got 0 records populated in T2 because a sub died on us'
);

# The sub should be changed to just return a duplicate value, without
# checking the fired flag once the CODEREF handling gets passed to 
# insert_bulk
my $fired = 0;
throws_ok(sub {
  my $ret = $schema->populate('Artist', [ [ qw/artistid name/ ], 
    [ 301, "T3.301" ],
    [ 302, "T3.302" ],
    sub { ($fired++)?undef:[ 302, "T3.302" ]},
    [ 303, "T3.304" ],
    [ 304, "T3.305" ],
  ]);
}, qr//, 'Exception caught when a duplicate got inserted');
cmp_ok($artists->search({ name => { LIKE => 'T3%' } })->count, 
       '==', 
       0, 'Got 0 records populated in T3 inserted a duplicate value'
);

$fired = 0;
$schema->populate('Artist', [ [ qw/artistid name/ ],
   sub { ($fired++)?undef:[ 401, "T4.401" ] }
]);

cmp_ok($artists->search({ name => { LIKE => 'T4%' } }), 
       '==', 
       1, 'Got 1 records populated in T4'
);

#
# Tests for Populating with Resultset
#

my $cds = $schema->resultset('CD');
my $insert_rs = $cds->search({ },{ select => [ 'artist', \"'New ' || title", 'year' ] });

my $old_cd_count = $cds->count;

$schema->populate('CD', [ [ qw/artist title year/ ],
  [ 3, "The new title", 2005 ],
  $insert_rs->as_query,
  [ 4, "The newer title", 2005 ],
]);

cmp_ok($cds->count, 
       '==', 
       $old_cd_count * 2, 
       'We just duplicated all the CDs'
);


my $insert_rs2 = $cds->search({ },{ select => [ 'artist', \"'Newest ' || title", 'year' ] });
$schema->populate('CD', [ [ qw/artist title year/ ],
  $insert_rs2->as_query,
]);

cmp_ok($cds->count, 
       '==', 
       $old_cd_count * 4, 
       'We just duplicated all the CDs'
);

use Data::Dumper;
diag(Dumper(map { { $_->get_columns } } $cds->all));
