
use Test::More tests => 17; 
use Test::Exception;
use Scalar::Util ();
use lib qw(t/lib);

use_ok('DBICTest');
ok(my $schema = DBICTest->init_schema(), 'got schema');

SKIP: {
  skip "Need to resolve what a bad script statement does", 1;
  throws_ok {
    $schema->storage->_execute_single_statement(qw/asdasdasd/);
  } qr/DBI Exception: DBD::SQLite::db do failed:/, 'Correctly died!';
}

throws_ok {
  $schema->storage->_normalize_fh (qw/t share scriptXXX.sql/);
} qr/Can't open file/, 'Dies with bad filehandle';

my $fh = $schema->storage->_normalize_fh (qw/t share basic.sql/);
ok (Scalar::Util::openhandle ($fh), 'Got good filehandle');

my $storage = $schema->storage;

is_deeply [$storage->_split_sql_line_into_statements("aaa;bbb;ccc")],["aaa;", "bbb;", "ccc", ""],
 "Correctly split";

is_deeply [$storage->_split_sql_line_into_statements("aaa;'bb1;bb2';ccc")],["aaa;", "'bb1;bb2';", "ccc", ""],
 "Correctly split";

is_deeply [$storage->_split_sql_line_into_statements(qq[aaa;"bb1;bb2";ccc])],["aaa;", '"bb1;bb2";', "ccc", ""],
 "Correctly split";

is_deeply [$storage->_split_sql_line_into_statements("aaa;bbb;ccc;")],["aaa;", "bbb;", "ccc;", ""],
 "Correctly split";

is_deeply [$storage->_split_sql_line_into_statements("insert into artist(artistid,name) values(888888,'xxx;yyy;zzz');")],
  ["insert into artist(artistid,name) values(888888,'xxx;yyy;zzz');",""],
  "Correctly split";

ok my @lines = $storage->_normalize_sql_lines(<$fh>), 'Got some lines';

is_deeply [@lines], [
  "CREATE TABLE cd_to_producer (",
  "cd integer NOT NULL,",
  "producer integer NOT NULL,",
  "PRIMARY KEY (cd, producer)",
  ");",
  "CREATE TABLE artist (",
  "artistid INTEGER PRIMARY KEY NOT NULL,",
  "name varchar(100)",
  ");",
  "insert into artist(artistid,name) values(888888,'xxx;yyy;zzz');",
  "insert into artist(artistid,name) values(999999,\"aaa;ccc\");",
  "insert into artist(artistid,name) values(777777,'--commented');",
  "CREATE TABLE cd (",
  "cdid INTEGER PRIMARY KEY NOT NULL,",
  "artist integer NOT NULL,",
  "title varchar(100) NOT NULL,",
  "year varchar(100) NOT NULL",
  ");",
  "CREATE TABLE track (",
  "trackid INTEGER PRIMARY KEY NOT NULL,",
  "cd integer NOT NULL,",
  "position integer NOT NULL,",
  "title varchar(100) NOT NULL,",
  "last_updated_on datetime NULL",
  ");",
  "CREATE TABLE tags (",
  "tagid INTEGER PRIMARY KEY NOT NULL,",
  "cd integer NOT NULL,",
  "tag varchar(100) NOT NULL",
  ");",
  "CREATE TABLE producer (",
  "producerid INTEGER PRIMARY KEY NOT NULL,",
  "name varchar(100) NOT NULL",
  ");",	
], 'Got expected lines';

ok my @statements = $storage->_normalize_statements_from_lines(@lines),
   'Got Statements';

is_deeply [@statements], [
  [
    "CREATE TABLE cd_to_producer (",
    "cd integer NOT NULL,",
    "producer integer NOT NULL,",
    "PRIMARY KEY (cd, producer)",
    ");",
  ],
  [
    "CREATE TABLE artist (",
    "artistid INTEGER PRIMARY KEY NOT NULL,",
    "name varchar(100)",
    ");",
  ],
  [
    "insert into artist(artistid,name) values(888888,'xxx;yyy;zzz');",
  ],
  [
    "insert into artist(artistid,name) values(999999,\"aaa;ccc\");",
  ],
  [
    "insert into artist(artistid,name) values(777777,'--commented');",
  ],
  [
    "CREATE TABLE cd (",
    "cdid INTEGER PRIMARY KEY NOT NULL,",
    "artist integer NOT NULL,",
    "title varchar(100) NOT NULL,",
    "year varchar(100) NOT NULL",
    ");",
  ],
  [
    "CREATE TABLE track (",
    "trackid INTEGER PRIMARY KEY NOT NULL,",
    "cd integer NOT NULL,",
    "position integer NOT NULL,",
    "title varchar(100) NOT NULL,",
    "last_updated_on datetime NULL",
    ");",
  ],
  [
    "CREATE TABLE tags (",
    "tagid INTEGER PRIMARY KEY NOT NULL,",
    "cd integer NOT NULL,",
    "tag varchar(100) NOT NULL",
    ");",
  ],
  [
    "CREATE TABLE producer (",
    "producerid INTEGER PRIMARY KEY NOT NULL,",
    "name varchar(100) NOT NULL",
    ");",
  ], 
  ], 'Got expect Lines';

lives_ok {
  $storage->_execute_single_statement('insert into artist( artistid,name) values( 777777,"--commented" );');
} 'executed statement';

ok $storage->run_file_against_storage(qw/t share simple.sql/), 'executed the simple';
ok $storage->run_file_against_storage(qw/t share killer.sql/), 'executed the killer';

