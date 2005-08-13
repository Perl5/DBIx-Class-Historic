package DBIx::Class::Field::Type::auto_increment;

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use base qw(
    DBIx::Class::Field::Type::number
    DBIx::Class::Field::Type::column
);

sub types : CUMULATIVE method { 'auto_increment' }

1;
