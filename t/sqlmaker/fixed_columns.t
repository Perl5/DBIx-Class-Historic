use strict;
use warnings;
use Test::More;
use Test::Warn;

use lib qw(t/lib);
use DBICTest;

my $schema = DBICTest->init_schema;

foreach (
  [ plain => { artistid => 1, charfield => undef },
    [qw(artistid)] ],
  [ -and => { -and => [ artistid => 1, { rank => 13 }, charfield => undef ] },
    [qw(artistid rank)] ],
  [ -or => { -and => [ -or => { name => 'Caterwauler McCrae', artistid => 2 } ] },
    [ ] ],
  [ array => { artistid => [ 1 ], rank => [ 13, 2, 3 ], charfield => [ undef ] },
    [qw(artistid)] ],
  [ operator => { artistid => { '=' => 1 }, rank => { '>' => 12 }, charfield => { '=' => undef } },
    [qw(artistid)] ],
  [ "= array" => { artistid => { '=' => [ 1 ], }, rank => { '=' => [ 1, 2 ] } },
    [qw(artistid)] ],
) {
  my ($desc, $where, $exp) = @$_;

  is_deeply(
    [ sort @{DBIx::Class::Storage::DBIHacks->_extract_fixed_condition_columns($where)} ],
    [ sort @{$exp} ],
    "$desc fixed columns",
  );

  my ($warning, $wdesc) = (@{$exp}
    ? ( undef, "doesn't warn" )
    : ( qr/Unable to properly collapse/, "warns" )
  );

  warning_like {
    $schema->resultset('Artist')
      ->search($where, { prefetch => 'cds_unordered', order_by=> ['name'] })
      ->next;
  } $warning, "$desc prefetch $wdesc";

}

done_testing;
