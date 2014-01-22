package DBICTest::Util::LeakTracer;

use warnings;
use strict;

use Carp;
use Scalar::Util qw(isweak weaken blessed reftype);
use DBIx::Class::_Util 'refcount';
use DBIx::Class::Optional::Dependencies;
use Data::Dumper::Concise;
use DBICTest::Util 'stacktrace';
use constant {
  CV_TRACING => DBIx::Class::Optional::Dependencies->req_ok_for ('test_leaks_heavy'),
  SKIP_SCALAR_REFS => ( $] > 5.017 ) ? 1 : 0,
};

use Devel::MAT::Dumper -max_string => -1;

use base 'Exporter';
our @EXPORT_OK = qw(populate_weakregistry assert_empty_weakregistry hrefaddr visit_refs);

my $refs_traced = 0;
my $leaks_found = 0;
my %reg_of_regs;

sub hrefaddr { sprintf '0x%x', &Scalar::Util::refaddr }

# so we don't trigger stringification
sub _describe_ref {
  sprintf '%s%s(%s)',
    (defined blessed $_[0]) ? blessed($_[0]) . '=' : '',
    reftype $_[0],
    hrefaddr $_[0],
  ;
}

warn "\nPID $$\n";

my ($cycle_cnt, $max, $dumpnext) = (0, 0);
sub populate_weakregistry {
  my ($weak_registry, $target, $note) = @_;

  croak 'Expecting a registry hashref' unless ref $weak_registry eq 'HASH';
  croak 'Target is not a reference' unless length ref $target;

  my $refaddr = hrefaddr $target;

  # a registry could be fed to itself or another registry via recursive sweeps
  return $target if $reg_of_regs{$refaddr};

  weaken( $reg_of_regs{ hrefaddr($weak_registry) } = $weak_registry )
    unless( $reg_of_regs{ hrefaddr($weak_registry) } );

  # an explicit "garbage collection" pass every time we store a ref
  # if we do not do this the registry will keep growing appearing
  # as if the traced program is continuously slowly leaking memory
  for my $reg (values %reg_of_regs) {
    (defined $reg->{$_}{weakref}) or delete $reg->{$_}
      for keys %$reg;

    $max = scalar keys %$reg if $max < scalar keys %$reg;
  }

  # FIXME/INVESTIGATE - something fishy is going on with refs to plain
  # strings, perhaps something to do with the CoW work etc...
  return $target if SKIP_SCALAR_REFS and reftype($target) eq 'SCALAR';

  if (! defined $weak_registry->{$refaddr}{weakref}) {
    $weak_registry->{$refaddr} = {
      stacktrace => stacktrace(1),
      weakref => $target,
    };
    weaken( $weak_registry->{$refaddr}{weakref} );
    $refs_traced++;
  }

  my $desc = _describe_ref($target);
  $weak_registry->{$refaddr}{slot_names}{$desc} = 1;
  if ($note) {
    $note =~ s/\s*\Q$desc\E\s*//g;
    $weak_registry->{$refaddr}{slot_names}{$note} = 1;
  }

  $max = 0 if $cycle_cnt == 8000;
  $dumpnext = 1 unless ( ++$cycle_cnt % 100_000 );
  unless (++$cycle_cnt % 10_000) {
    if (-f "/proc/$$/stat") {
      my $proc_stat = do { local (@ARGV, $/) = "/proc/$$/stat"; <> };
        my ($vsz) = map { $_ / 1024 }
        (split (/\s+/, $proc_stat))[-22];  # go backwards because the %s of the pr

      printf STDERR "#\n# VSIZE:%dKiB\n", $vsz

    }
  }

#  if ($dumpnext and ( (scalar keys %$weak_registry) == $max )) {
#    undef $dumpnext;
#    Devel::MAT::Dumper::dump( "/tmp/dump_$cycle_cnt" );
#    exit if $cycle_cnt >= 900_000;
#  }

  $target;
}

# Regenerate the slots names on a thread spawn
sub CLONE {
  my @individual_regs = grep { scalar keys %{$_||{}} } values %reg_of_regs;
  %reg_of_regs = ();

  for my $reg (@individual_regs) {
    my @live_slots = grep { defined $_->{weakref} } values %$reg
      or next;

    $reg = {};  # get a fresh hashref in the new thread ctx
    weaken( $reg_of_regs{hrefaddr($reg)} = $reg );

    for my $slot_info (@live_slots) {
      my $new_addr = hrefaddr $slot_info->{weakref};

      # replace all slot names
      $slot_info->{slot_names} = { map {
        my $name = $_;
        $name =~ s/\(0x[0-9A-F]+\)/sprintf ('(%s)', $new_addr)/ieg;
        ($name => 1);
      } keys %{$slot_info->{slot_names}} };

      $reg->{$new_addr} = $slot_info;
    }
  }
}

sub visit_refs {
  my $args = { (ref $_[0]) ? %{$_[0]} : @_ };

  $args->{seen_refs} ||= {};

  my $visited_cnt = '0E0';
  for my $i (0 .. $#{$args->{refs}} ) {
    next if isweak($args->{refs}[$i]);

    my $r = $args->{refs}[$i];

    next unless length ref $r;

    next if $args->{seen_refs}{my $dec_addr = Scalar::Util::refaddr($r)}++;

    $visited_cnt++;
    $args->{action}->($r) or next;

    my $type = reftype $r;
    if ($type eq 'HASH') {
      $visited_cnt += visit_refs({ %$args, refs => [ map {
        ( !isweak($r->{$_}) ) ? $r->{$_} : ()
      } keys %$r ] });
    }
    elsif ($type eq 'ARRAY') {
      $visited_cnt += visit_refs({ %$args, refs => [ map {
        ( !isweak($r->[$_]) ) ? $r->[$_] : ()
      } 0..$#$r ] });
    }
    elsif ($type eq 'REF' and !isweak($$r)) {
      $visited_cnt += visit_refs({ %$args, refs => [ $$r ] });
    }
    elsif (CV_TRACING and $type eq 'CODE') {
      $visited_cnt += visit_refs({ %$args, refs => [ map {
        ( !isweak($_) ) ? $_ : ()
      } scalar PadWalker::closed_over($r) ] }); # scalar due to RT#92269
    }
  }
  $visited_cnt;
}

sub assert_empty_weakregistry {
  my ($weak_registry, $quiet) = @_;

  # in case we hooked bless any extra object creation will wreak
  # havoc during the assert phase
  local *CORE::GLOBAL::bless;
  *CORE::GLOBAL::bless = sub { CORE::bless( $_[0], (@_ > 1) ? $_[1] : caller() ) };

  croak 'Expecting a registry hashref' unless ref $weak_registry eq 'HASH';

  return unless keys %$weak_registry;

  my $tb = eval { Test::Builder->new }
    or croak "Calling assert_empty_weakregistry in $0 without a loaded Test::Builder makes no sense";

  for my $addr (keys %$weak_registry) {
    $weak_registry->{$addr}{display_name} = join ' | ', (
      sort
        { length $a <=> length $b or $a cmp $b }
        keys %{$weak_registry->{$addr}{slot_names}}
    );

    $tb->BAILOUT("!!!! WEAK REGISTRY SLOT $weak_registry->{$addr}{display_name} IS NOT A WEAKREF !!!!")
      if defined $weak_registry->{$addr}{weakref} and ! isweak( $weak_registry->{$addr}{weakref} );
  }

  # compile a list of refs stored as globals (possibly even catching
  # class data in the form of method closures), so we can skip them
  # further on
  my ($seen_refs, $classdata_refs) = ({}, undef);

  # the walk is very expensive - if we are $quiet (running in an END block)
  # we do not really need to be too thorough
  unless ($quiet) {
    my ($symwalker, $symcounts);
    $symwalker = sub {
      no strict 'refs';
      my $pkg = shift || '::';

      # any non-weak globals are "clasdata" in all possible sense
      #
      # the unless regex at the end skips some dangerous namespaces outright
      # (but does not prevent descent)
      $symcounts->{$pkg} += visit_refs (
        seen_refs => $seen_refs,
        action => sub { ++$classdata_refs->{hrefaddr $_[0]} },
        refs => [ map { my $sym = $_;
          # *{"$pkg$sym"}{CODE} won't simply work - MRO-cached CVs are invisible there
          ( CV_TRACING ? Class::MethodCache::get_cv("${pkg}$sym") : () ),

          ( defined *{"$pkg$sym"}{SCALAR} and length ref ${"$pkg$sym"} and ! isweak( ${"$pkg$sym"} ) )
            ? ${"$pkg$sym"} : ()
          ,
          ( map {
            ( defined *{"$pkg$sym"}{$_} and ! isweak(defined *{"$pkg$sym"}{$_}) )
              ? *{"$pkg$sym"}{$_}
              : ()
          } qw(HASH ARRAY IO GLOB) ),
        } keys %$pkg ],
      ) unless $pkg =~ /^ :: (?:
        DB | next | B | .+? ::::ISA (?: ::CACHE ) | Class::C3
      ) :: $/x;

      $symwalker->("${pkg}$_") for grep { $_ =~ /(?<!^main)::$/ } keys %$pkg;
    };

    $symwalker->();

#    use Devel::Dwarn;
#    Ddie [ map
#      { { $_ => $symcounts->{$_} } }
#      sort
#        {$symcounts->{$a} <=> $symcounts->{$b} }
#        keys %$symcounts
#    ];
  }

  delete $weak_registry->{$_} for keys %$classdata_refs;

  for my $addr (sort { $weak_registry->{$a}{display_name} cmp $weak_registry->{$b}{display_name} } keys %$weak_registry) {

    next if ! defined $weak_registry->{$addr}{weakref};

    $leaks_found++ unless $tb->in_todo;
    $tb->ok (0, "Leaked $weak_registry->{$addr}{display_name}");

    my $diag = do {
      local $Data::Dumper::Maxdepth = 1;
      sprintf "\n%s (refcnt %d) => %s\n",
        $weak_registry->{$addr}{display_name},
        refcount($weak_registry->{$addr}{weakref}),
        (
          ref($weak_registry->{$addr}{weakref}) eq 'CODE'
            and
          B::svref_2object($weak_registry->{$addr}{weakref})->XSUB
        ) ? '__XSUB__' : Dumper( $weak_registry->{$addr}{weakref} )
      ;
    };

    # FIXME - need to add a circular reference seeker based on the visitor
    # (will need a bunch of modifications, punting with just a stub for now)

    $diag .= Devel::FindRef::track ($weak_registry->{$addr}{weakref}, 50) . "\n"
      if ( $ENV{TEST_VERBOSE} && eval { require Devel::FindRef });

    $diag =~ s/^/    /mg;

    if (my $stack = $weak_registry->{$addr}{stacktrace}) {
      $diag .= "    Reference first seen$stack";
    }

    $tb->diag($diag);
  }

  if (! $quiet and !$leaks_found and ! $tb->in_todo) {
    $tb->ok(1, sprintf "No leaks found at %s line %d", (caller())[1,2] );
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

1;
