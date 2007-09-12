package MDBATest::Schema::Site;
use strict;
use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('site');

__PACKAGE__->add_columns(qw(id url description));

1;