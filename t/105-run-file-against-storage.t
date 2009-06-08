
use Test::More tests => 13; 
use Test::Exception;
use lib qw(t/lib);

use_ok( 'DBIx::Class::Schema::ScriptDo' );
use_ok('DBICTest');
ok(my $schema = DBICTest->init_schema(), 'got schema');

throws_ok {
	$schema->_execute_single_statement(qw/asdasdasd/);
} qr/DBI Exception: DBD::SQLite::db do failed:/, 'Correctly died!';

throws_ok {
	$schema->_normalize_fh_from_args(qw/t share scriptXXX.sql/);	
} qr/Can't open file/, 'Dies with bad filehandle';

ok my $fh = $schema->_normalize_fh_from_args(qw/t share script1.sql/),
  'Got good filehandle';

ok my @lines = $schema->_normalize_lines_from_fh($fh), 'Got some lines';

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

ok my @statements = $schema->_normalize_statements_from_lines(@lines),
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
	
	
ok $schema->_execute_single_statement(
	'insert into artist( artistid,name )',
	'values( 777777,"--commented" );',
	), 'executed statement';

ok $schema->run_file_against_storage(qw/t share simple.sql/), 'executed the simple';
ok $schema->run_file_against_storage(qw/t share killer.sql/), 'executed the killer';