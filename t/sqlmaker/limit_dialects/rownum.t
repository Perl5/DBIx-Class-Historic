use strict;
use warnings;

use Test::More;

use lib qw(t/lib);
use DBICTest;
use DBIC::SqlMakerTest;
use DBIx::Class::SQLMaker::LimitDialects;

my ($TOTAL, $OFFSET, $ROWS) = (
   DBIx::Class::SQLMaker::LimitDialects->__total_bindtype,
   DBIx::Class::SQLMaker::LimitDialects->__offset_bindtype,
   DBIx::Class::SQLMaker::LimitDialects->__rows_bindtype,
);

my $schema = DBICTest->init_schema;

$schema->storage->_sql_maker->renderer_class(
  Moo::Role->create_class_with_roles(qw(
    Data::Query::Renderer::SQL::Naive
    Data::Query::Renderer::SQL::Slice::RowNum
  ))
);

$schema->storage->_sql_maker->limit_requires_order_by_stability_check(1);

my $rs = $schema->resultset ('CD')->search({ id => 1 });

my $where_bind = [ { dbic_colname => 'id' }, 1 ];

for my $test_set (
  {
    name => 'Rownum subsel aliasing works correctly',
    rs => $rs->search_rs(undef, {
      rows => 1,
      offset => 3,
      columns => [
        { id => 'foo.id' },
        { 'bar.id' => 'bar.id' },
        { bleh => { '' => \'TO_CHAR (foo.womble, "blah")', -as => 'bleh' } },
      ]
    }),
    sql => '(
      SELECT foo.id, bar__id, bleh
      FROM (
        SELECT foo.id, bar__id, bleh, ROWNUM AS rownum__index
        FROM (
          SELECT foo.id, bar.id AS bar__id, TO_CHAR (foo.womble, "blah") AS bleh
            FROM cd me
          WHERE id = ?
        ) foo
      ) foo WHERE rownum__index BETWEEN ? AND ?
    )',
    binds => [
      $where_bind,
      [ $OFFSET => 4 ],
      [ $OFFSET => 4 ],
    ],
  }, {
    name => 'Rownum subsel aliasing works correctly with unique order_by',
    rs => $rs->search_rs(undef, {
      rows => 1,
      offset => 3,
      columns => [
        { id => 'foo.id' },
        { 'bar.id' => 'bar.id' },
        { bleh => { '' => \'TO_CHAR (foo.womble, "blah")', -as => 'bleh' } },
      ],
      order_by => [qw( artist title )],
    }),
    sql => '(
      SELECT foo.id, bar__id, bleh
      FROM (
        SELECT foo.id, bar__id, bleh, ROWNUM AS rownum__index
        FROM (
          SELECT foo.id, bar.id AS bar__id, TO_CHAR(foo.womble, "blah") AS bleh
            FROM cd me
          WHERE id = ?
          ORDER BY artist, title
        ) foo
        WHERE ROWNUM <= ?
      ) foo
      WHERE rownum__index >= ?
    )',
    binds => [
      $where_bind,
      [ $TOTAL => 4 ],
      [ $TOTAL => 4 ],
    ],
  },
 {
    name => 'Rownum subsel aliasing works correctly with non-unique order_by',
    rs => $rs->search_rs(undef, {
      rows => 1,
      offset => 3,
      columns => [
        { id => 'foo.id' },
        { 'bar.id' => 'bar.id' },
        { bleh => { '' => \'TO_CHAR (foo.womble, "blah")', -as => 'bleh' } },
      ],
      order_by => 'artist',
    }),
    sql => '(
      SELECT foo.id, bar__id, bleh
      FROM (
        SELECT foo.id, bar__id, bleh, ROWNUM AS rownum__index
        FROM (
          SELECT foo.id, bar.id AS bar__id, TO_CHAR(foo.womble, "blah") AS bleh
            FROM cd me
          WHERE id = ?
          ORDER BY artist
        ) foo
      ) foo
      WHERE rownum__index BETWEEN ? and ?
    )',
    binds => [
      $where_bind,
      [ $TOTAL => 4 ],
      [ $TOTAL => 4 ],
    ],
  }, {
    name => 'Rownum subsel aliasing #2 works correctly',
    rs => $rs->search_rs(undef, {
      rows => 2,
      offset => 3,
      columns => [
        { id => 'foo.id' },
        { 'ends_with_me.id' => 'ends_with_me.id' },
      ]
    }),
    sql => '(
      SELECT foo.id, ends_with_me__id
      FROM (
        SELECT foo.id, ends_with_me__id, ROWNUM AS rownum__index
        FROM (
          SELECT foo.id, ends_with_me.id AS ends_with_me__id
            FROM cd me
          WHERE id = ?
        ) foo
      ) foo WHERE rownum__index BETWEEN ? AND ?
    )',
    binds => [
      $where_bind,
      [ $TOTAL => 4 ],
      [ $TOTAL => 5 ],
    ],
  }, {
    name => 'Rownum subsel aliasing #2 works correctly with unique order_by',
    rs => $rs->search_rs(undef, {
      rows => 2,
      offset => 3,
      columns => [
        { id => 'foo.id' },
        { 'ends_with_me.id' => 'ends_with_me.id' },
      ],
      order_by => [qw( year artist title )],
    }),
    sql => '(
      SELECT foo.id, ends_with_me__id
      FROM (
        SELECT foo.id, ends_with_me__id, ROWNUM AS rownum__index
        FROM (
          SELECT foo.id, ends_with_me.id AS ends_with_me__id
            FROM cd me
          WHERE id = ?
          ORDER BY year, artist, title
        ) foo
        WHERE ROWNUM <= ?
      ) foo
      WHERE rownum__index >= ?
    )',
    binds => [
      $where_bind,
      [ $TOTAL => 5 ],
      [ $TOTAL => 4 ],
    ],
  }
) {
  is_same_sql_bind(
    $test_set->{rs}->as_query,
    $test_set->{sql},
    $test_set->{binds},
    $test_set->{name});
}

{
my $subq = $schema->resultset('Owners')->search({
   'count.id' => { -ident => 'owner.id' },
}, { alias => 'owner' })->count_rs;

my $rs_selectas_rel = $schema->resultset('BooksInLibrary')->search ({}, {
  columns => [
     { owner_name => 'owner.name' },
     { owner_books => { '' => $subq->as_query, -as => 'owner_books' } },
  ],
  join => 'owner',
  rows => 2,
  offset => 3,
});

is_same_sql_bind(
  $rs_selectas_rel->as_query,
  '(
    SELECT owner.name, owner_books
      FROM (
        SELECT owner.name, owner_books, ROWNUM AS rownum__index
          FROM (
            SELECT  owner.name,
              ( SELECT COUNT( * ) FROM owners owner WHERE (count.id = owner.id)) AS owner_books
              FROM books me
              JOIN owners owner ON owner.id = me.owner
            WHERE ( source = ? )
          ) owner
      ) owner
    WHERE rownum__index BETWEEN ? AND ?
  )',
  [
    [ { sqlt_datatype => 'varchar', sqlt_size => 100, dbic_colname => 'source' }
      => 'Library' ],
    [ $TOTAL => 4 ],
    [ $TOTAL => 5 ],
  ],

  'pagination with subquery works'
);

}

{
  $rs = $schema->resultset('Artist')->search({}, {
    columns => 'name',
    offset => 1,
    order_by => 'name',
  });
  local $rs->result_source->{name} = "weird \n newline/multi \t \t space containing \n table";

  like (
    ${$rs->as_query}->[0],
    qr| weird \s \n \s newline/multi \s \t \s \t \s space \s containing \s \n \s table|x,
    'Newlines/spaces preserved in final sql',
  );
}

{
my $subq = $schema->resultset('Owners')->search({
   'books.owner' => { -ident => 'owner.id' },
}, { alias => 'owner', select => ['id'] } )->count_rs;

my $rs_selectas_rel = $schema->resultset('BooksInLibrary')->search( { -exists => $subq->as_query }, { select => ['id','owner'], rows => 1 } );

is_same_sql_bind(
  $rs_selectas_rel->as_query,
  '(
    SELECT me.id, me.owner FROM (
      SELECT me.id, me.owner  FROM books me WHERE ( ( EXISTS (SELECT COUNT( * ) FROM owners owner WHERE ( books.owner = owner.id )) AND source = ? ) )
    ) me
    WHERE ROWNUM <= ?
  )',
  [
    [ { sqlt_datatype => 'varchar', sqlt_size => 100, dbic_colname => 'source' } => 'Library' ],
    [ $ROWS => 1 ],
  ],
  'Pagination with sub-query in WHERE works'
);

}

done_testing;
