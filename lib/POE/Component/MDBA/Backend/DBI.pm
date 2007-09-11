# $Id: /mirror/perl/POE-Component-MDBA/trunk/lib/POE/Component/MDBA/Backend/DBI.pm 2541 2007-09-11T13:25:08.143151Z daisuke  $
#
# Copyright (c) 2007 Daisuke Maki <daisuke@endeworks.jp>
# All rights reserved.

package POE::Component::MDBA::Backend::DBI;
use strict;
use warnings;
use base qw(POE::Component::MDBA::Backend);
use DBI;

__PACKAGE__->mk_accessors($_) for qw(_dbh connect_info);

sub new
{
    my $class = shift;
    $class->SUPER::new({ connect_info => [ @_ ] });
}

sub dbh
{
    my ($self) = @_;
    my $dbh = $self->_dbh;
    if (! $dbh || ! $dbh->ping) {
        $dbh = DBI->connect( @{ $self->connect_info } );
    }
    return $dbh;
}

sub execute
{
    my ($self, $args, $opts) = @_;

    my ($error, $rv, @rows);
    eval { 
        my $dbh = $self->dbh();
        my $sth = $dbh->prepare( $args->{sql} );
           $rv  = $sth->execute(@{ $args->{placeholders} });
        if (my $select_method = $args->{select_method}) {
            while( my $row = $sth->$select_method ) {
                push @rows, $row;
            }
        }
        $sth->finish; # just to make sure.
    };
    if ($@) {
        $error = $@;
    }

    return +{
        rv    => $rv,
        rows  => \@rows,
        error => $error,
    };
}


1;

__END__

=head1 NAME

POE::Component::MDBA::Backend::DBI - Simple DBI Backend

=head1 SYNOPSIS

  use POE qw(Component::MDBA);

  POE::Component::MDBA->spawn(
    alias        => $alias,
    backend      => 'DBI', # optional
    backend_args => [ ... list of connection sources ... ]
  );

  # else where in your code...
  POE::Kernel->post($alias, 'execute', {
    args => [ ... list database arguments ... ]
  });

=head1 DESCRIPTION

This module allows you simple access to DBI via POE::Component::MDBA.

=head1 MDBA ARGUMENTS

POE::Component::MDBA::Backend::DBI influences the arguments passed to
POE::Component::MDBA methods:

=head2 spawn ARGUMENTS

=over 4

=item backend_args

backend_args takes an arrayref of arrayrefs. Each arrayref contains the
arguments to DBI-E<lt>connect(). 

  POE::Component::MDBA->spawn(
    backend_args => [
      [ 'dbi:Pg:dbname=foo1', 'username1', 'password1', \%attr ],
      [ 'dbi:Pg:dbname=foo2', 'username2', 'password2', \%attr ],
      [ 'dbi:Pg:dbname=foo3', 'username3', 'password3', \%attr ],
      ...
    ]
  );

=back

=head2 execute ARGUMENTS

execute takes a list of hashref which each contain the following:

=over 4

=item sql

This specifies the raw SQL string that needs to be executed. Placeholders
are allowed - see I<placeholders> below.

=item placeholders

This specifies the list of placeholders passed to $sth-E<lt>execute()

=item select_method

This specifies the method to use when selecting data from the statement
handle. If you are not using SELECT'able sql, then you can leave it as
it is.

=back

  POE::Kernel->post( $alias, 'execute', {
    args => [
      {
        select_method => 'fetchrow_hashref', # optional
        sql           => 'SELECT foo FROM bar',
        placeholders  => [ $arg1, $arg2, $arg3 ... ]
      }
    ]
  });

=head2 aggregate ARGUMENTS

aggregate function takes the usual arguments received from 
POE::Component::Generic. ARG0 contains $ref, which is a cookie sent by
POE::Component::MDBA. ARG1 contains $result, which is the return value from
POE::Component::MDBA::Backend::DBI::execute(). 

The $result value is a hashref containing the following keys:

=over 4

=item rv

The value returned by $sth-E<lt>execute().

=item rows

An arrayref containing the rows resulting from executing the SQL and fetching
results from it. The type of each value depends on the value of C<select_mode>
passed to execute().

Note that if select_mode is not specified, then the value of this slot is
always an empty list.

=item error

If execute() fails at any point because of an error, then this value is
populated with the value of the error

=back

  {
    rv => $rv,
    rows => [
      { col1 => $val1, col2 => $val2 ... }, # if you specified fetchrow_hashref
      ...
    ],
    error => undef, # undef if no error
  }

=head1 METHODS

=head2 new

Creates a new POE::Component::MDBA::Backend::DBI instance. Takes a list of
arguments, which are directly passed to DBI-E<lt>connect()

=head2 dbh

Returns a connect database handle.

=head2 execute

Executes the given query

=head1 AUTHOR

Copyright (c) 2007 Daisuke Maki E<lt>daisuke@endeworks.jpE<gt>

=head1 SEE ALSO

L<POE::Component::MDBA|POE::Component::MDBA>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
