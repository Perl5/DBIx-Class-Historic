package
    XUnit::LoadNameSpace;

use strict;
use warnings FATAL => 'all';

use base qw( XUnit );

sub test1 : Tests(8) {
    my $self = shift;

    my $warnings;
    eval {
        local $SIG{__WARN__} = sub { $warnings .= shift };
        package DBICNSTest;
        use base qw/DBIx::Class::Schema/;
        __PACKAGE__->load_namespaces;
    };
    $self->ok(!$@) or diag $@;
    $self->like($warnings, qr/load_namespaces found ResultSet class C with no corresponding Result class/);

    my $source_a = DBICNSTest->source('A');
    $self->isa_ok($source_a, 'DBIx::Class::ResultSource::Table');
    my $rset_a   = DBICNSTest->resultset('A');
    $self->isa_ok($rset_a, 'DBICNSTest::ResultSet::A');

    my $source_b = DBICNSTest->source('B');
    $self->isa_ok($source_b, 'DBIx::Class::ResultSource::Table');
    my $rset_b   = DBICNSTest->resultset('B');
    $self->isa_ok($rset_b, 'DBIx::Class::ResultSet');

    for my $moniker (qw/A B/) {
        my $class = "DBICNSTest::Result::$moniker";
        $self->ok(!defined($class->result_source_instance->source_name));
    }
}

sub test2 : Tests(6) {
    my $self = shift;

    my $warnings;
    eval {
        local $SIG{__WARN__} = sub { $warnings .= shift };
        package DBICNSTest;
        use base qw/DBIx::Class::Schema/;
        __PACKAGE__->load_namespaces(
            result_namespace => 'Rslt',
            resultset_namespace => 'RSet',
        );
    };
    $self->ok(!$@) or diag $@;
    $self->like($warnings, qr/load_namespaces found ResultSet class C with no corresponding Result class/);

    my $source_a = DBICNSTest->source('A');
    $self->isa_ok($source_a, 'DBIx::Class::ResultSource::Table');
    my $rset_a   = DBICNSTest->resultset('A');
    $self->isa_ok($rset_a, 'DBICNSTest::RSet::A');

    my $source_b = DBICNSTest->source('B');
    $self->isa_ok($source_b, 'DBIx::Class::ResultSource::Table');
    my $rset_b   = DBICNSTest->resultset('B');
    $self->isa_ok($rset_b, 'DBIx::Class::ResultSet');
}

sub test3 : Tests(7) {
    my $self = shift;

    my $warnings;
    eval {
        local $SIG{__WARN__} = sub { $warnings .= shift };
        package DBICNSTestOther;
        use base qw/DBIx::Class::Schema/;
        __PACKAGE__->load_namespaces(
            result_namespace => [ '+DBICNSTest::Rslt', '+DBICNSTest::OtherRslt' ],
            resultset_namespace => '+DBICNSTest::RSet',
        );
    };
    $self->ok(!$@) or diag $@;
    $self->like($warnings, qr/load_namespaces found ResultSet class C with no corresponding Result class/);

    my $source_a = DBICNSTestOther->source('A');
    $self->isa_ok($source_a, 'DBIx::Class::ResultSource::Table');
    my $rset_a   = DBICNSTestOther->resultset('A');
    $self->isa_ok($rset_a, 'DBICNSTest::RSet::A');

    my $source_b = DBICNSTestOther->source('B');
    $self->isa_ok($source_b, 'DBIx::Class::ResultSource::Table');
    my $rset_b   = DBICNSTestOther->resultset('B');
    $self->isa_ok($rset_b, 'DBIx::Class::ResultSet');

    my $source_d = DBICNSTestOther->source('D');
    $self->isa_ok($source_d, 'DBIx::Class::ResultSource::Table');
}

sub test4 : Tests(6) {
    my $self = shift;

    my $warnings;
    eval {
        local $SIG{__WARN__} = sub { $warnings .= shift };
        package DBICNSTest;
        use base qw/DBIx::Class::Schema/;
        __PACKAGE__->load_namespaces( default_resultset_class => 'RSBase' );
    };
    $self->ok(!$@) or diag $@;
    $self->like($warnings, qr/load_namespaces found ResultSet class C with no corresponding Result class/);

    my $source_a = DBICNSTest->source('A');
    $self->isa_ok($source_a, 'DBIx::Class::ResultSource::Table');
    my $rset_a   = DBICNSTest->resultset('A');
    $self->isa_ok($rset_a, 'DBICNSTest::ResultSet::A');

    my $source_b = DBICNSTest->source('B');
    $self->isa_ok($source_b, 'DBIx::Class::ResultSource::Table');
    my $rset_b   = DBICNSTest->resultset('B');
    $self->isa_ok($rset_b, 'DBICNSTest::RSBase');
}

sub exception : Tests(1) {
    my $self = shift;

    eval {
        package DBICNSTest;
        use base qw/DBIx::Class::Schema/;
        __PACKAGE__->load_namespaces(
            result_namespace => 'Bogus',
            resultset_namespace => 'RSet',
        );
    };

    $self->like ($@, qr/are you sure this is a real Result Class/, 'Clear exception thrown');
}

sub rt41083_case1 : Tests(4) {
    my $self = shift;

    my $warnings;
    eval {
        local $SIG{__WARN__} = sub { $warnings .= shift };
        package DBICNSTest::RtBug41083;
        use base 'DBIx::Class::Schema';
        __PACKAGE__->load_namespaces(
            result_namespace => 'Schema_A',
            resultset_namespace => 'ResultSet_A',
            default_resultset_class => 'ResultSet'
        );
    };

    $self->ok(!$@) or diag $@;
    $self->check_warnings($warnings);
    $self->verify_sources(qw/A A::Sub/);
}

sub rt41083_case2 : Tests(4) {
    my $self = shift;

    my $warnings;
    eval {
        local $SIG{__WARN__} = sub { $warnings .= shift };
        package DBICNSTest::RtBug41083;
        use base 'DBIx::Class::Schema';
        __PACKAGE__->load_namespaces(
            result_namespace => 'Schema',
            resultset_namespace => 'ResultSet',
            default_resultset_class => 'ResultSet'
        );
    };
    $self->ok(!$@) or diag $@;
    $self->check_warnings($warnings);
    $self->verify_sources(qw/A A::Sub Foo Foo::Sub/);
}

sub check_warnings {
    my $self = shift;
    my ($warnings) = @_;

    if ( defined $warnings ) {
        $self->unlike(
            qr/We found ResultSet class '([^']+)' for '([^']+)', but it seems that you had already set '([^']+)' to use '([^']+)' instead/,
            "Have a warning, but it's ok"
        )
        and
        $self->unlike(
            qr/already has a source, use register_extra_source for additional sources/,
            "Have a warning, but it's ok"
        )
        or $self->diag( $warnings );
    }
    else {
        $self->ok( 1, "No complaints" );
        $self->ok( 1, "No complaints" );
    }
}

sub verify_sources {
    my $self = shift;
    my @monikers = @_;
    $self->is_deeply (
        [ sort DBICNSTest::RtBug41083->sources ],
        \@monikers,
        'List of resultsource registrations',
    );
}

1;
__END__
