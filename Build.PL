use strict;
use warnings FATAL => 'all';
use Module::Build;

my %arguments = (
    license            => 'perl',
    module_name        => 'DBIx::Class',
    build_requires     => {
        'File::Spec'       => '3.01',
        'Test::Exception'  => '0.21',
        'Test::NoWarnings' => '0.08',
        'Test::Manifest'   => '1.11',
        'Test::More'       => '0.60',
    },
    requires           => {
        'Data::Page'                => 0,
        'DBI'                       => 0,
        'UNIVERSAL::require'        => 0,
        'NEXT'                      => 0,
        'SQL::Abstract'             => 1.20,
        'SQL::Abstract::Limit'      => 0.101,
        'Scalar::Util'              => 1.14,
        'DBD::SQLite'               => 1.08,
	'Tie::IxHash'               => 0,
        'Storable'                  => 0,
        'Carp'                 => '1.03',
        'Class::Std'           => '0.0.4',
        'List::MoreUtils'      => '0.10',
        'base'                 => '2.060',
        'strict'               => '1.030',
        'version'              => '0.420',
        'warnings'             => '1.03',
    },
    create_makefile_pl => 'passthrough',
    create_readme      => 1,
    add_to_cleanup     => [ qw( MANIFEST.bak cover_db .DS_Store Makefile t/var ) ],
);

my $build_class = test_manifest_subclass();
my $build       = $build_class->new(%arguments)->create_build_script();

# use Test::Manifest to prioritize test cases
# rather than a naming convention
sub test_manifest_subclass {
    return Module::Build->subclass(
        class => 'Module::Build::Test::Manifest',
        code  => q{
            sub ACTION_test {
                my ($self, @args ) = @_;

                if( exists $self->{properties}{test_files} ) {
                    return $self->SUPER::ACTION_test(@args);
                }

                local $^X = $self->{config}{perlpath};

                require Test::Manifest;
                require File::Spec;

                Test::Manifest::run_t_manifest(
                    $self->{properties}{verbose} || 0,
                    File::Spec->catdir(qw(blib lib)),
                    File::Spec->catdir(qw(blib arch)),
                );

                return;
            }
        },
    );
}
