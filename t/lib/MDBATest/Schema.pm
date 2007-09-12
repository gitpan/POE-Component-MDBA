package MDBATest::Schema;
use strict;
use base qw(DBIx::Class::Schema);

__PACKAGE__->load_classes('Site');

1;