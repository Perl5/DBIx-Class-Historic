package # hide from PAUSE
    DBICTest::Schema::TrackUpdate;

use base qw/DBICTest::BaseResult/;
use Carp qw/confess/;

__PACKAGE__->load_components(qw{
    +DBICTest::DeployComponent
    InflateColumn::DateTime
    Ordered
});

__PACKAGE__->table('track_updates');
__PACKAGE__->add_columns(
  'cdid' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  last_updated_on => {
    data_type => 'datetime',
    accessor => 'updated_date',
    is_nullable => 1
  }
);
__PACKAGE__->set_primary_key('cdid');

__PACKAGE__->belongs_to( cd => 'DBICTest::Schema::CD', 'cdid');

1;
