package # Hide from PAUSE
    XUnit;

use strict;
use warnings FATAL => 'all';

use base qw( Test::Class );

INIT { Test::Class->runtests }

BEGIN {
    # XXX Need a better way to do this.
    my $subs_for = sub {
        my $pkg = shift;
        no strict 'refs';
        return grep { defined &{"${pkg}::${_}"} } keys %{"${pkg}::"};
    };

    my @packages = qw(
        Test::More
    );

    foreach my $pkg ( @packages ) {
        eval "use $pkg ();";
        die $@ if $@;
        foreach my $subroutine ( $subs_for->($pkg) ) {
            next if __PACKAGE__->can($subroutine);
            eval qq| sub $subroutine { shift; goto &{"${pkg}::${subroutine}"} } |;
            die $@ if $@;
        }
    }
}

1;
__END__
