package DBIx::Class::Field::Type::identifier;

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use base qw(DBIx::Class::Field);

sub types : CUMULATIVE method { 'identifier' }

1;
