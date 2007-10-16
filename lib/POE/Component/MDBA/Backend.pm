# $Id: /mirror/perl/POE-Component-MDBA/trunk/lib/POE/Component/MDBA/Backend.pm 3522 2007-10-16T07:07:54.182447Z daisuke  $
#
# Copyright (c) 2007 Daisuke Maki <daisuke@endeworks.jp>
# All rights reserved.

package POE::Component::MDBA::Backend;
use strict;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors($_) for qw(timeout);

1;

__END__

=head1 NAME

POE::Component::MDBA::Backend - Base Backend 

=cut