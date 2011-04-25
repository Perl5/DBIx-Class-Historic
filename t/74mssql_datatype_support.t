use strict;
use warnings;

# use this if you keep a copy of DBD::Sybase linked to FreeTDS somewhere else
BEGIN {
  if (my $lib_dirs = $ENV{DBICTEST_MSSQL_PERL5LIB}) {
    unshift @INC, $_ for split /:/, $lib_dirs;
  }
}

use Test::More;
use Test::Exception;
use Try::Tiny;
use Scope::Guard ();
use Storable 'dclone';
use lib qw(t/lib);
use DBICTest;

my $env2optdep = {
  DBICTEST_MSSQL => 'test_rdbms_mssql_sybase',
  DBICTEST_MSSQL_ADO => 'test_rdbms_mssql_ado',
  DBICTEST_MSSQL_ODBC => 'test_rdbms_mssql_odbc',
};

plan skip_all => join (' ',
  'Set $ENV{DBICTEST_MSSQL_ODBC_DSN} and/or $ENV{DBICTEST_MSSQL_DSN}',
  'and/or $ENV{DBICTEST_MSSQL_ADO_DSN},',
  '_USER and _PASS to run these tests.',
  'WARNING: these tests create and drop the table mssql_types_test.',
) unless grep { $ENV{"${_}_DSN"} } keys %$env2optdep;

ok(1);

my $dsns;
for my $prefix (keys %$env2optdep) { SKIP: {
  my ($dsn, $user, $pass) = map { $ENV{"${prefix}_$_"} } qw/DSN USER PASS/;

  skip ("$prefix - ${prefix}_DSN not set", 1)
    unless  $ENV{"${prefix}_DSN"};

  skip ("Testing with ${prefix}_DSN - needs " . DBIx::Class::Optional::Dependencies->req_missing_for( $env2optdep->{$prefix} ), 1)
    unless  DBIx::Class::Optional::Dependencies->req_ok_for($env2optdep->{$prefix});

  $dsns->{$prefix} = [
    (map { $ENV{"${prefix}_$_"} } qw/DSN USER PASS/),
    { on_connect_call => 'datetime_setup' },
  ];

  if ($prefix eq 'DBICTEST_MSSQL_ODBC') {
    $dsns->{"${prefix}_dyncursor"} = [
      (map { $ENV{"${prefix}_$_"} } qw/DSN USER PASS/),
      { on_connect_call => [qw/use_dynamic_cursors datetime_setup/] },
    ];
  }
} }

unless (keys %$dsns) {
  done_testing;
  exit 0;
}

DBICTest::Schema->load_classes('MSSQLTypes');
my $schema;

for my $tst (keys %$dsns) {

  $schema = DBICTest::Schema->connect(@{$dsns->{$tst}});

  my $sg = Scope::Guard->new(sub { cleanup($schema) });

  my $ver = $schema->storage->_server_info->{normalized_dbms_version} || 0;

  $schema->storage->dbh_do(sub {
    my ($storage, $dbh) = @_;
    local $^W = 0; # for ADO
    $dbh->do(<<'EOF');
IF OBJECT_ID('mssql_types_test', 'U') IS NOT NULL DROP TABLE mssql_types_test
EOF
    $dbh->do(<<"EOF");
CREATE TABLE mssql_types_test (
  id int identity primary key,
  bigint_col bigint,
  smallint_col smallint,
  tinyint_col tinyint,
  money_col money,
  smallmoney_col smallmoney,
  bit_col bit,
  real_col real,
  double_precision_col double precision,
  numeric_col numeric,
  decimal_col decimal,
  datetime_col datetime,
  smalldatetime_col smalldatetime,
  char_col char(3),
  varchar_col varchar(100),
  nchar_col nchar(3),
  nvarchar_col nvarchar(100),
  binary_col binary(4),
  varbinary_col varbinary(100),
  text_col text,
  ntext_col ntext,
  image_col image,
  uniqueidentifier_col uniqueidentifier,
  sql_variant_col sql_variant,
  xml_col xml,
@{[ $ver >= 10 ? '
  date_col date,
  time_col time,
  datetimeoffset_col datetimeoffset,
  datetime2_col datetime2,
  hierarchyid_col hierarchyid
' : '
  date_col varchar(100),
  time_col varchar(100),
  datetimeoffset_col varchar(100),
  datetime2_col varchar(100),
  hierarchyid_col varchar(100)
' ]}
)
EOF
  });

  my $data = {
    bigint_col => 33,
    smallint_col => 22,
    tinyint_col => 11,
# FIXME Causes "Cannot convert a char value to money. The char value has
# incorrect syntax" on populate.
    money_col => '55.5500',
    smallmoney_col => '44.4400',
    bit_col => 1,
    real_col => '66.666',
    double_precision_col => '77.7777777777778',
    numeric_col => 88,
    decimal_col => 99,
    datetime_col => '2011-04-25 09:37:37.377',
    smalldatetime_col => '2011-04-25 09:38:00',
    char_col => 'foo',
    varchar_col => 'bar',
    nchar_col => 'baz',
    nvarchar_col => 'quux',
    text_col => 'text',
    ntext_col => 'ntext',
# FIXME Binary types cause "implicit conversion...is not allowed" errors on
# identity_insert, and "Invalid character value for cast speicification" on
# populate.
    binary_col => "\0\1\2\3",
    varbinary_col => "\4\5\6\7",
    image_col => "\10\11\12\13",
    uniqueidentifier_col => '966CD933-6C4C-1014-9F40-FB912B1D7AB5',
# FIXME "Operand type clash: sql_variant is incompatible with text (SQL-22018)"
# from MS ODBC driver.
    sql_variant_col => 'sql_variant',
# FIXME needs a CAST in _select_args, otherwise select causes
# "String data, right truncation"
# With LongTruncOk, it looks like binary data is returned.
    xml_col => '<foo>bar</foo>',
    date_col => '2011-04-25',
# FIXME need to bind with full .XXXXXXX precision
    time_col => '09:43:43.0000000',
    datetimeoffset_col => '2011-04-25 09:37:37.0000000 -05:00',
# this one allows full precision for some reason
    datetime2_col => '2011-04-25 09:37:37.3777777',
# FIXME needs a CAST in _select_args
    hierarchyid_col => '/',
  };

  my $rs = $schema->resultset('MSSQLTypes');

  is_deeply (
    { map { $_ => 1 } $rs->result_source->columns },
    { map { $_ => 1 } ('id', keys %$data) },
    '%data contents match source columnlist'
  );

  my $next_id = 1;

  for my $populate ('', 'via bulk insert ') {
    for my $identity_insert ('', 'with identity insert ') {
      for my $col (sort keys %$data) {

        my $to_db = $data->{$col};  # to detect mangle-bugs

        # try regular insert
        lives_ok {
          my $insert = { $col => $to_db };
          $insert->{id} = $next_id if $identity_insert;

          if ($populate) {
            $rs->populate([$insert]);
            1;
          }
          else {
            $rs->create($insert);
          }

          is_deeply ($to_db, $data->{$col}, "inserted $col value untouched" );

          my $proto = $rs->new($insert);
          $proto->id($next_id);
          $next_id++;

          # sybase has a weird setup_datetime formatter
          if (
            $schema->storage->dbh->{Driver}{Name} eq 'Sybase'
              and
            $col =~ /^ (?:small)? datetime_col $/x
          ) {
            my $v = $proto->$col;
            $v =~ s/ /T/;
            $v .= ($col eq 'smalldatetime_col' ? '.000Z' : 'Z');
            $proto->$col($v);
          }

          cmp_rowobj ($proto->get_from_storage, $proto, 'Inserted data matches');

          cmp_rowobj ($rs->find({ $col => $data->{$col} }), $proto, 'find() works');
        } "insert of $col ${populate}${identity_insert}survived";

        $rs->delete;
      }
    }
  }
}

done_testing;

sub cmp_rowobj {
  my ($retrieved, $original, $test_name) = @_;
  $_ = { $_ ? $_->get_columns : ()} for ($retrieved, $original);

  foreach my $k (keys %$original) {
    next if ($k eq 'id' and $retrieved->{id} == $original->{id});

    if (my ($decimal_part) = $original->{$k} =~ /^\d+\.(\d+)\z/) {
      is sprintf('%.'.(length $decimal_part).'f', $retrieved->{$k}),
        $original->{$k},
        "$test_name: $k";
    }
    else {
      is $retrieved->{$k}, $original->{$k}, "$test_name: $k";
    }
  }
}

sub cleanup {
  my $schema = shift;
  if (my $dbh = eval { $schema->storage->dbh }) {
    local $^W = 0; # for ADO
    $dbh->do(<<'EOF');
IF OBJECT_ID('mssql_types_test', 'U') IS NOT NULL DROP TABLE mssql_types_test
EOF
  }
}
# vim:sts=2 sw=2 et:
