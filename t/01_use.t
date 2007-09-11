use strict;
use Test::More (tests => 2);

BEGIN
{
    use_ok("POE::Component::MDBA");
    use_ok("POE::Component::MDBA::Backend::DBI");
}
