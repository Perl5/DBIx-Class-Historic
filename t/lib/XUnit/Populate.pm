package
    XUnit::Populate;

use strict;
use warnings;

use base qw( XUnit );

use Path::Class::File ();

sub basic : Test(1) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    my $rows = 10;
    my $name = 'aaaa';

    $self->schema->populate(
        'Artist', [
            [ qw/artistid name/ ],
            map { [ $_ => $name++ ] } ( 1 .. $rows )
        ]
    );

    $self->cmp_ok(
        $self->schema->resultset('Artist')->count, '==', $rows,
        'populate created correct number of rows with massive AoA bulk insert',
    );
}

sub non_unique_column : Test(1) Populate {
    my $self = shift;

    my $artist = $self->schema->resultset ('Artist')->search(
        { 'cds.title' => { '!=', undef } },
        { join => 'cds' },
    )->first;
    my $ex_title = $artist->cds->first->title;

    $self->throws_ok ( sub {
        $self->schema->populate('CD', [
            map {
                {
                    artist => $artist->id,
                    title => $_,
                    year => 2009,
                }
            } ('Huey', 'Dewey', $ex_title, 'Louie')
        ])
    }, qr/columns .+ are not unique for populate slice.+$ex_title/ms,
    'Readable exception thrown for failed populate');
}

sub honor_field_order_schema_order : Test(4) {
    my $self = shift;

    my @links = $self->schema->populate('Link', [
        [ qw/id url title/ ],
        [ qw/2 burl btitle/ ]
    ]);
    $self->is(scalar @links, 1);
    $self->compare( $links[0], q/
        id: 2
        url: burl
        title: btitle
    /);
}

sub honor_field_order_random_order : Test(4) {
    my $self = shift;

    my @links = $self->schema->populate('Link', [
        [ qw/url id title/ ],
        [ qw/burl 2 btitle/ ]
    ]);
    $self->is(scalar @links, 1);
    $self->compare( $links[0], q/
        id: 2
        url: burl
        title: btitle
    /);
}

sub honor_field_order_missing_columns : Test(4) {
    my $self = shift;

    my @links = $self->schema->populate('Link', [
        [ qw/url id/ ],
        [ qw/burl 2/ ]
    ]);
    $self->is(scalar @links, 1);
    $self->compare( $links[0], q/
        id: 2
        url: burl
        title: ~
    /);
}

sub honor_field_order_schema_order_void_context : Test(4) {
    my $self = shift;

    $self->schema->populate('Link', [
        [ qw/id url title/ ],
        [ qw/2 burl btitle/ ]
    ]);
    $self->compare( $self->schema->resultset('Link'), q/
        all:
          - id: 2
            url: burl
            title: btitle
    /);
}

sub honor_field_order_random_order_void_context : Test(4) {
    my $self = shift;

    my @links = $self->schema->populate('Link', [
        [ qw/url id title/ ],
        [ qw/burl 2 btitle/ ]
    ]);
    $self->compare( $self->schema->resultset('Link'), q/
        all:
          - id: 2
            url: burl
            title: btitle
    /);
}

sub honor_field_order_missing_columns_void_context : Test(4) {
    my $self = shift;

    my @links = $self->schema->populate('Link', [
        [ qw/url id/ ],
        [ qw/burl 2/ ]
    ]);
    $self->compare( $self->schema->resultset('Link'), q/
        all:
          - id: 2
            url: burl
            title: ~
    /);
}

# test _execute_array_empty (insert_bulk with all literal sql)
sub literal_sql : Test(16) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    $rs->populate([
        (+{
            name => \"'DT'",
            rank => \500,
            charfield => \"'mtfnpy'",
        }) x 5
    ]);

    $self->compare( $rs, q/
        all:
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
    /);
}

sub mixed_with_literal_sql : Test(16) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    $rs->populate([
        (+{
            name => \"'DT'",
            rank => 500,
            charfield => \"'mtfnpy'",
        }) x 5
    ]);

    $self->compare( $rs, q/
        all:
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
          - name: DT
            rank: 500
            charfield: mtfnpy
    /);
}

sub bad_slice : Test(2) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    $self->throws_ok( sub {
        $rs->populate([
            {
                artistid => 1,
                name => 'foo1',
            },
            {
                artistid => 'foo', # this dies
                name => 'foo2',
            },
            {
                artistid => 3,
                name => 'foo3',
            },
        ]);
    }, qr/slice/, 'bad slice' );

    $self->cmp_ok($rs->count, '==', 0, 'populate is atomic');
}

# Trying to use a column marked as a bind in the first slice with literal sql in
# a later slice should throw.
sub literal_after_bind : Test(1) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    $self->throws_ok( sub {
        $rs->populate([
            {
                artistid => 1,
                name => \"'foo'",
            },
            {
                artistid => \2,
                name => \"'foo'",
            }
        ]);
    }, qr/bind expected/, 'literal sql where bind expected throws');
}

# . . . and vice versa
sub bind_after_literal : Test(1) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    $self->throws_ok( sub {
        $rs->populate([
            {
                artistid => \1,
                name => \"'foo'",
            },
            {
                artistid => 2,
                name => \"'foo'",
            }
        ]);
    }, qr/literal SQL expected/, 'bind where literal sql expected throws');
}

sub inconsistent_literal_sql : Test(1) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    $self->throws_ok( sub {
        $rs->populate([
            {
              artistid => 1,
              name => \"'foo'",
            },
            {
              artistid => 2,
              name => \"'bar'",
            }
        ]);
    }, qr/inconsistent/, 'literal sql must be the same in all slices');
}

sub stringify_object_first : Test(3) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    my $fn = Path::Class::File->new ('somedir/somefilename.tmp');
    my $other = 'some other name';

    $self->lives_ok( sub {
        my @dummy = $rs->populate([
            {
                name => 'supplied before stringifying object',
            },
            {
                name => $fn,
            },
        ]);
    }, 'stringifying objects pass through' );

    $self->ok( $rs->find({ name => $fn }), "Found name => $fn" );
    $self->ok( $rs->find({ name => $fn }), "Found name => $other" );
}

sub stringify_object_second : Test(3) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    my $fn = Path::Class::File->new ('somedir/somefilename.tmp');
    my $other = 'some other name';

    $self->lives_ok( sub {
        my @dummy = $rs->populate([
            {
                name => $fn,
            },
            {
                name => 'supplied before stringifying object',
            },
        ]);
    }, 'stringifying objects pass through' );

    $self->ok( $rs->find({ name => $fn }), "Found name => $fn" );
    $self->ok( $rs->find({ name => $fn }), "Found name => $other" );
}

sub stringify_object_first_void_context : Test(3) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    my $fn = Path::Class::File->new ('somedir/somefilename.tmp');
    my $other = 'some other name';

    $self->lives_ok( sub {
        $rs->populate([
            {
                name => 'supplied before stringifying object',
            },
            {
                name => $fn,
            },
        ]);
    }, 'stringifying objects pass through' );

    $self->ok( $rs->find({ name => $fn }), "Found name => $fn" );
    $self->ok( $rs->find({ name => $fn }), "Found name => $other" );
}

sub stringify_object_second_void_context : Test(3) {
    my $self = shift;

    my $rs = $self->schema->resultset('Artist');

    my $fn = Path::Class::File->new ('somedir/somefilename.tmp');
    my $other = 'some other name';

    $self->lives_ok( sub {
        $rs->populate([
            {
                name => $fn,
            },
            {
                name => 'supplied before stringifying object',
            },
        ]);
    }, 'stringifying objects pass through' );

    $self->ok( $rs->find({ name => $fn }), "Found name => $fn" );
    $self->ok( $rs->find({ name => $fn }), "Found name => $other" );
}

sub multicol_pk_has_many : Test(1) {
    my $self = shift;

    $self->lives_ok( sub {
        $self->schema->resultset('TwoKeys')->populate([{
            artist => 1,
            cd     => 5,
            fourkeys_to_twokeys => [{
                f_foo => 1,
                f_bar => 1,
                f_hello => 1,
                f_goodbye => 1,
                autopilot => 'a',
            },{
                f_foo => 2,
                f_bar => 2,
                f_hello => 2,
                f_goodbye => 2,
                autopilot => 'b',
            }]
        }])
    }, 'multicol-PK has_many populate works' );
}

1;
__END__
