#!/usr/bin/perl -w

use strict;
use warnings;  

use Test::More tests => 2;
use lib qw(t/lib);
use DBICTest;

=head1 DESCRIPTION

Attempt to add a relationship to a class *after* they've been initialised..

=cut

my $schema = DBICTest->init_schema();

my @previous_rels = sort $schema->source('Artist')->relationships;

my $class = $schema->class('Artist');
$class->belongs_to('rank' => $schema->class('Lyrics'));

# Now check we have the relationship:
my $source = $schema->source('Artist');

is_deeply(
    [sort $source->relationships],
    [sort(@previous_rels, 'rank')],
    'Found rank in relationships'
);

ok($source->relationship_info('rank'), "We have relationship info for rank");

