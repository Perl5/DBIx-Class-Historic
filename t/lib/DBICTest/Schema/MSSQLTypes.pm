package # hide from PAUSE 
    DBICTest::Schema::MSSQLTypes;

use base qw/DBICTest::BaseResult/;

__PACKAGE__->table('mssql_types_test');

# These are all the internal types, we don't bother with type aliases like
# varchar(max) (which is text.)
# MSSQL 2008 types are at the bottom.

__PACKAGE__->add_columns(
  'id' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'bigint_col' => {
    data_type => 'bigint',
    is_nullable => 1,
  },
  'smallint_col' => {
    data_type => 'smallint',
    is_nullable => 1,
  },
  'tinyint_col' => {
    data_type => 'tinyint',
    is_nullable => 1,
  },
  'money_col' => {
    data_type => 'money',
    is_nullable => 1,
  },
  'smallmoney_col' => {
    data_type => 'smallmoney',
    is_nullable => 1,
  },
  'bit_col' => {
    data_type => 'bit',
    is_nullable => 1,
  },
  'real_col' => {
    data_type => 'real',
    is_nullable => 1,
  },
  'double_precision_col' => {
    data_type => 'double precision',
    is_nullable => 1,
  },
  'numeric_col' => {
    data_type => 'numeric',
    is_nullable => 1,
  },
  'decimal_col' => {
    data_type => 'decimal',
    is_nullable => 1,
  },
  'datetime_col' => {
    data_type => 'datetime',
    is_nullable => 1,
  },
  'smalldatetime_col' => {
    data_type => 'smalldatetime',
    is_nullable => 1,
  },
  'char_col' => {
    data_type => 'char',
    size => 3,
    is_nullable => 1,
  },
  'varchar_col' => {
    data_type => 'varchar',
    size => 100,
    is_nullable => 1,
  },
  'nchar_col' => {
    data_type => 'nchar',
    size => 3,
    is_nullable => 1,
  },
  'nvarchar_col' => {
    data_type => 'nvarchar',
    size => 100,
    is_nullable => 1,
  },
  'binary_col' => {
    data_type => 'binary',
    size => 4,
    is_nullable => 1,
  },
  'varbinary_col' => {
    data_type => 'varbinary',
    size => 100,
    is_nullable => 1,
  },
  'text_col' => {
    data_type => 'text',
    is_nullable => 1,
  },
  'ntext_col' => {
    data_type => 'ntext',
    is_nullable => 1,
  },
  'image_col' => {
    data_type => 'image',
    is_nullable => 1,
  },
  'uniqueidentifier_col' => {
    data_type => 'uniqueidentifier',
    is_nullable => 1,
  },
  'sql_variant_col' => {
    data_type => 'sql_variant',
    is_nullable => 1,
  },
  'xml_col' => {
    data_type => 'xml',
    is_nullable => 1,
  },

# MSSQL 2008 types, created as varchar(50) on < 2008

  'date_col' => {
    data_type => 'date',
    is_nullable => 1,
  },
  'time_col' => {
    data_type => 'time',
    is_nullable => 1,
  },
  'datetimeoffset_col' => {
    data_type => 'datetimeoffset',
    is_nullable => 1,
  },
  'datetime2_col' => {
    data_type => 'datetime2',
    is_nullable => 1,
  },
  'hierarchyid_col' => {
    data_type => 'hierarchyid',
    is_nullable => 1,
  },
);

__PACKAGE__->set_primary_key('id');

1;
