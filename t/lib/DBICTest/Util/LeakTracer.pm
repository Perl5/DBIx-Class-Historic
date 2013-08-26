package DBICTest::Util::LeakTracer;

use warnings;
use strict;

use Carp;
use Scalar::Util qw(isweak weaken blessed reftype refaddr);
use B 'svref_2object';
use DBICTest::Util ();

use base 'Exporter';
our @EXPORT_OK = qw(run_and_populate_weakregistry populate_weakregistry assert_empty_weakregistry);


use Devel::FindRef;

# this is compiled further down before we get here
*run_and_populate_weakregistry = \&DB::_LEAKTRACER_run_and_populate_weakregistry;
*populate_weakregistry = \&DB::_LEAKTRACER_populate_weakregistry;

my $has_padwalker;
my $refs_traced = 0;
my $leaks_found;
my %reg_of_regs;


sub CLONE {
  my @individual_regs = grep { scalar keys %{$_||{}} } values %reg_of_regs;
  %reg_of_regs = ();

  for my $reg (@individual_regs) {
    my @live_slots = grep { defined $reg->{$_}{weakref} } keys %$reg
      or next;

    my @live_instances = @{$reg}{@live_slots};

    $reg = {};  # get a fresh hashref in the new thread ctx
    weaken( $reg_of_regs{refaddr($reg)} = $reg );

    while (@live_slots) {
      my $slot = shift @live_slots;
      my $inst = shift @live_instances;

      my $refaddr = $inst->{refaddr} = refaddr($inst);

      $slot =~ s/\(0x[0-9A-F]+\)/sprintf ('(0x%x)', $refaddr)/ieg;

      $reg->{$slot} = $inst;
    }
  }
}

sub assert_empty_weakregistry {
  my ($weak_registry, $quiet) = @_;

  $quiet = 1;

  croak 'Expecting a registry hashref' unless ref $weak_registry eq 'HASH';

  return unless keys %$weak_registry;

  my $tb = eval { Test::Builder->new }
    or croak 'Calling test_weakregistry without a loaded Test::Builder makes no sense';

  for my $slot (sort keys %$weak_registry) {
    next if ! defined $weak_registry->{$slot}{weakref};
    $tb->BAILOUT("!!!! WEAK REGISTRY SLOT $slot IS NOT A WEAKREF !!!!")
      unless isweak( $weak_registry->{$slot}{weakref} );
  }


  # compile a list of refs stored as CAG class data, so we can skip them
  # intelligently below
  my ($classdata_refcounts, $symwalker, $refwalker);

  $refwalker = sub {
    return unless length ref $_[0];

    my $seen = $_[1] || {};
    return if $seen->{refaddr $_[0]}++;

    $classdata_refcounts->{refaddr $_[0]}++;

    my $type = reftype $_[0];
    if ($type eq 'HASH') {
      $refwalker->($_, $seen) for values %{$_[0]};
    }
    elsif ($type eq 'ARRAY') {
      $refwalker->($_, $seen) for @{$_[0]};
    }
    elsif ($type eq 'REF') {
      $refwalker->($$_, $seen);
    }
  };

  $symwalker = sub {
    no strict 'refs';
    my $pkg = shift || '::';

    # any non-weak cref is an installed sub - these are
    # "clasdata" in all possible sense
    # so are any lexicals declared in them (not their contents!!!)
    # exempt the @s and %s if we did track them
    for my $glob (
        map { (! defined $_ or length ref $_ ) ? () : $_ }
          values %$pkg
    ) {
      my $cref = *{$glob}{CODE};
      next unless defined $cref and ! isweak($cref);

      $classdata_refcounts->{refaddr $cref}++;

      if ($has_padwalker) {
        my $lexicals = PadWalker::peek_sub($cref);
        for (grep { $_ =~ /^[\@\%]/ } keys %$lexicals) {
          $classdata_refcounts->{refaddr $lexicals->{$_}}++;
        }
      }
    };

    $refwalker->(${"${pkg}$_"}) for grep { $_ =~ /__cag_(?!pkg_gen__|supers__)/ } keys %$pkg;

    $symwalker->("${pkg}$_") for grep { $_ =~ /(?<!^main)::$/ } keys %$pkg;
  };

  $symwalker->();

  for my $slot (keys %$weak_registry) {
    if (
      defined $weak_registry->{$slot}{weakref}
        and
      my $expected_refcnt = $classdata_refcounts->{$weak_registry->{$slot}{refaddr}}
    ) {
      # need to store the SVref and examine it separately,
      # to push the weakref instance off the pad
      my $sv = svref_2object($weak_registry->{$slot}{weakref});
      delete $weak_registry->{$slot} if $sv->REFCNT == $expected_refcnt;
    }
  }

  for my $slot (sort keys %$weak_registry) {
    ! defined $weak_registry->{$slot}{weakref} and next if $quiet;

    my $desc = "No leaks of $slot";
    $desc .= " ($weak_registry->{$slot}{note})" if $weak_registry->{$slot}{note};

    $tb->ok (! defined $weak_registry->{$slot}{weakref}, $desc) or do {
      $leaks_found = 1;

      my $diag = '';

      $diag .= Devel::FindRef::track ($weak_registry->{$slot}{weakref}, 20) . "\n"
        if ( ($ENV{TEST_VERBOSE}) && eval { require Devel::FindRef });

      if (my $stack = $weak_registry->{$slot}{stacktrace}) {
        $diag .= "    Reference $slot first seen$stack";
      }

      $diag .= do { require Data::Dumper; local $Data::Dumper::Maxdepth = 1; Data::Dumper::Concise::Dumper( $weak_registry->{$slot}{weakref} ) };

      $tb->diag($diag) if $diag;

      exit 1;
    };
  }
}

END {
  if ($INC{'Test/Builder.pm'}) {
    my $tb = Test::Builder->new;

    # we check for test passage - a leak may be a part of a TODO
    if ($leaks_found and !$tb->is_passing) {

      $tb->diag(sprintf
        "\n\n%s\n%s\n\nInstall Devel::FindRef and re-run the test with set "
      . '$ENV{TEST_VERBOSE} (prove -v) to see a more detailed leak-report'
      . "\n\n%s\n%s\n\n", ('#' x 16) x 4
      ) if ( !$ENV{TEST_VERBOSE} or !$INC{'Devel/FindRef.pm'} );

    }
    else {
      $tb->note("Auto checked $refs_traced references for leaks - none detected");
    }
  }
}


#    local $ENV{PERLDB_OPTS} = 'NonStop';
#    require Enbugger;
#    Enbugger->load_debugger('perl5db');
#  }


# all code below needs to be *originally* compiled in the DB namespace
# otherwise nothing works
{
  package #sigh pause
    DB;

  use warnings;
  use strict;

  # seems to catch on only at compile time >.<
  BEGIN { $DB::deep = 1_000 };

  my $current_weak_registry;
  my $collector = { active => 0 };

  sub DB::_LEAKTRACER_GUARD::DESTROY { $DB::trace = 0 }

  sub _LEAKTRACER_populate_weakregistry {
    # shut off the call tracer
    local *DB::sub;

    # shut off the line-based tracer
    local $collector->{active};

    my ($weak_registry, $target, $note, $recursion_seen) = @_;

    Carp::croak 'Expecting a registry hashref' unless ref $weak_registry eq 'HASH';
    Carp::croak 'Target is not a reference' unless length ref $target;

    # REs are essentially strings, some of which are mighty hard to track properly
    return $target if ref($target) eq 'Regexp';

    Scalar::Util::weaken( $reg_of_regs{ Scalar::Util::refaddr($weak_registry) } = $weak_registry )
      unless( $reg_of_regs{ Scalar::Util::refaddr($weak_registry) } );

    my $refaddr = Scalar::Util::refaddr $target;
    my $reftype = Scalar::Util::reftype $target;

    # a registry could be fed to itself or another registry via PadWalker sweeps
    return $target if $reg_of_regs{$refaddr};

    my $class;
    my $slot = (sprintf '%s%s(0x%x)', # so we don't trigger stringification
      (defined ($class = Scalar::Util::blessed $target)) ? "$class=" : '',
      $reftype,
      $refaddr,
    );

    my $decorated_slot = $slot . ($note ? " ($note)" : '' );

    # do not descend more than one level into foreign objects, but
    # drill down into anything non-blessed to the end
    if (
      ! $recursion_seen
        or
      ! defined $class
        or
      $class =~ / DBIx::Class | SQL::Abstract | SQL::Translator | Data::Query /x
    ) {

      $recursion_seen ||= {};

      if ($reftype eq 'ARRAY') {
        for my $i (0 .. $#$target) {
          if (
            length ref $target->[$i]
              and
            ! $recursion_seen->{Scalar::Util::refaddr $target->[$i]}++
          ) {
            _LEAKTRACER_populate_weakregistry(
              $weak_registry,
              $target->[$i],
              "element $i of array $decorated_slot",
              $recursion_seen,
            );
          }
        }
      }
      elsif ($reftype eq 'HASH') {
        for my $n (sort keys %$target) {
          if (
            length ref $target->{$n}
              and
            ! $recursion_seen->{Scalar::Util::refaddr $target->{$n}}++
          ) {
            _LEAKTRACER_populate_weakregistry(
              $weak_registry,
              $target->{$n},
              "element $n of hash $decorated_slot",
              $recursion_seen,
            );
          }
        }
      }
      elsif ($reftype eq 'REF' and ! $recursion_seen->{Scalar::Util::refaddr $$target}++ ) {
        _LEAKTRACER_populate_weakregistry(
          $weak_registry,
          $$target,
          "target of ref $decorated_slot",
          $recursion_seen,
        )
      }
    }

  #  $slot .= " ($note)" if $note;
  #  $slot = ( scalar keys %$weak_registry) . " $slot";

    if (defined $weak_registry->{$slot}{weakref}) {
      if ( $weak_registry->{$slot}{refaddr} != $refaddr ) {
        print STDERR "Bail out! Weak Registry slot collision '$slot': '$weak_registry->{$slot}{weakref}' vs '$target'\n";
        exit 255;
      }
    }
    else {
      $weak_registry->{$slot} = {
        stacktrace => DBICTest::Util::stacktrace(1),
        refaddr => $refaddr,
        note => $note,
      };
      Scalar::Util::weaken( $weak_registry->{$slot}{weakref} = $target );
      $refs_traced++;
    }

    $target;
  }

  sub _LEAKTRACER_run_and_populate_weakregistry (&;@) {
    die "Debugger not yet active - nothing will work" unless $^P;

    $has_padwalker = ( do { local $@; eval {
      require PadWalker;

      # FIXME - work around https://rt.cpan.org/Ticket/Display.html?id=89679
      require B;
      my $orig = \&PadWalker::peek_sub;
      no warnings 'redefine';
      *PadWalker::peek_sub = sub {
        my $cv = B::svref_2object($_[0]);
        if ($cv->ROOT and ! $cv->ROOT->isa('B::NULL') and ! $cv->XSUB and ! $cv->XSUBANY) {
          return &$orig
        }
        else {
          return {};
        }
      }
      # end of FIXME

    }; 1 } || 0 ) if not defined $has_padwalker;

    my $cref = shift;
    $current_weak_registry = shift;
    die 'Expecting a registry hashref' unless ref $current_weak_registry eq 'HASH';

    if ($has_padwalker) {

      my $lexicals = PadWalker::peek_sub($cref);

      for my $var (keys %$lexicals) {
        my $v = $lexicals->{$var};

        $v = $$v if ref $v eq 'REF';

        _LEAKTRACER_populate_weakregistry($current_weak_registry, $v, sprintf (
          '%s closed over by initially supplied coderef %s', $var, $cref
        ));
      }
    }

    # if we do not perform this cleanup exactly at this boundary, we will
    # get under- or over-reporting by the linetracer
    # an alternative would be to compile *everything* we need under DB::
    # which is untenable
    my $detracer;

    local *DB::DB if $has_padwalker;
    if ($has_padwalker) {
      *DB::DB = \&_LEAKTRACER_DB;
      $detracer = bless ([], 'DB::_LEAKTRACER_GUARD');
      $DB::trace = 1;
    }

    local *DB::sub;
    *DB::sub = \&_LEAKTRACER_sub;

    # inherits wantarray ctx
    $cref->();
  }

  sub _LEAKTRACER_sub {
    no strict 'refs';

    my ($namespace, $subname) = (caller(0))[0,3];
    $collector->{active} = 0 && (
      $namespace =~ /^ (?: DBIx::Class | DBICTest(?!::Util::LeakTracer) )/x
        and
      # collecting anything in a destructor is unwise
      $subname !~ /::DESTROY$/
    );

    # I have no fucking clue what is going on here, some
    # stack-hiding by DB it seems (note the negative depth)
    my @siteinfo = (caller(-1))[1,2];

    if ($collector->{active}) {

      for my $i (0..$#_) {
        _LEAKTRACER_populate_weakregistry(
          $current_weak_registry,
          $_[$i],
          sprintf ('$_[%d] to call at %s line %d', $i, @siteinfo),
        ) if length ref $_[$i];
      }
    }

    my @res;
    if (! defined wantarray) {
      &$DB::sub;
    }
    elsif (wantarray) {
      @res = &$DB::sub;
    }
    else {
      $res[0] = &$DB::sub;
    };

    if ($collector->{active}) {

      for my $i (0..$#_) {
        _LEAKTRACER_populate_weakregistry(
          $current_weak_registry,
          $_[$i],
          sprintf ('modified $_[%d] after call at %s line %d', $i, @siteinfo),
        ) if length ref $_[$i];
      }

      for my $i (0..$#res) {
        _LEAKTRACER_populate_weakregistry(
          $current_weak_registry,
          $res[$i],
          sprintf ('RV#%d from call at %s line %d', $i, @siteinfo),
        ) if length ref $res[$i];
      }
    }

    return wantarray ? @res : $res[0];
  }

  sub _LEAKTRACER_DB {
    if ($collector->{active}) {

      # this will prevent us from self-profiling
      local *DB::sub;

      # the correct callsite comes from caller(0)
      my @siteinfo = (caller(0))[1,2];
      #printf STDERR "%s at %d\n", (caller(0))[1,2];

      # yet the correct PadWalker stash lies a frame higher, wtf?
      my $mys = PadWalker::peek_my(1);

      for my $var (keys %$mys) {
        my $v = $mys->{$var};

        # PadWalker indiscriminately takes a \ of anything in a $scalar
        # if it isn't a SCALAR, it'll be a REF to a coderef or a hash or whathaveyou
        if ( $var =~ /^\$/ ) {

          $v = $$v;

          # tracking strings is too much work and unreliable
          # besides you can't leak it by self-reference
          next if (! length ref($v) or ref($v) eq 'Regexp');
        }

        _LEAKTRACER_populate_weakregistry($current_weak_registry, $v, sprintf (
          '%s at %s line %d', $var, @siteinfo
        ));
      }
    }
  }
}

1;

__END__


sub tracking_DB_SUB {
  die 'Makes no sense without an active debugger' unless $^P;


    if (1 or 
      ( (caller(0))[0] || '' ) =~ /^(?: DBIx::Class | DBICTest )/x
    ) {
      $collector_active++;

