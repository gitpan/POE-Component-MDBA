# $Id: /mirror/perl/POE-Component-MDBA/trunk/lib/POE/Component/MDBA/Backend/DBIC.pm 2545 2007-09-12T02:38:30.521360Z daisuke  $
#
# Copyright (c) 2007 Daisuke Maki <daisuke@endeworks.jp>
# All rights reserved.

package POE::Component::MDBA::Backend::DBIC;
use strict;
use warnings;
use base qw(POE::Component::MDBA::Backend);

__PACKAGE__->mk_accessors($_) for qw(schema);

sub new
{
    my $class = shift;
    my %args  = @_;
    my $schema = $args{schema};
    my $connect_info = $args{connect_info};

    if (! $schema) {
        die "No schema provided";
    }

    if (! ref $schema ) {
        if (! Class::Inspector->loaded($schema)) {
            eval "require $schema";
            die if $@;
        }

        $schema = $schema->connection(@$connect_info);
    }

    $class->SUPER::new({ schema => $schema });
}

sub execute
{
    my ($self, $args, $opts) = @_;

    my $rs_method = $args->{rs_method} || 'search';
    my $ret;
    eval {
        $ret = $self->$rs_method($args, $opts);
    };
    if ($@) {
        $ret = { error => $@ };
    }
    return $ret;
}

sub search
{
    my ($self, $args, $opts) = @_;

    my $schema  = $self->schema;
    my $moniker = $args->{moniker};
    my $where   = $args->{where};
    my $attrs   = $args->{attrs};
    my ($error, @rows);
    eval {
        my $rs = $schema->resultset($moniker)->search($where, $attrs);
        # There's no point in using this module unless we actually
        # fetch all the results!
        while (my $row = $rs->next) {
            push @rows, $row;
        }
    };
    if ($@) {
        $error = $@;
    }

    return +{
        rows  => \@rows,
        error => $error,
    };
}


1;

__END__

=head1 NAME

POE::Component::MDBA::Backend::DBIC - DBIx::Class Backend

=head1 SYNOPSIS

  use POE qw(Component::MDBA);

  POE::Component::MDBA->spawn(
    alias        => $alias,
    backend      => 'DBIC',
    backend_args => [ { schema => $schema1 }, { schema => $schema2 } ]
  );

  # else where in your code...
  POE::Kernel->post($alias, 'execute', {
    args => [ ... list method arguments ... ]
  });

=head1 DESCRIPTION

This module allows you simple access to DBIx::Class via POE::Component::MDBA.

=head1 MDBA ARGUMENTS

POE::Component::MDBA::Backend::DBIC influences the arguments passed to
POE::Component::MDBA methods:

=head2 spawn ARGUMENTS

=over 4

=item backend_args

backend_args takes an arrayref of arrayrefs. Each arrayref contains a key
value pair. The "schema" key is required, and it should be either a schema
class name, or an already connected schema object.

If a class name is passed to the schema argument, you need to specify the
connect_info key as well.

  POE::Component::MDBA->spawn(
    backend_args => [
      [
        schema => $schema_object
      ],
      # or 
      [
        schema => $schema_class,
        connect_info => [ 'dbi:Pg:dbname=foo2', 'username2', 'password2', \%attr ]
      ],
      ...
    ]
  );

=back

=head2 execute ARGUMENTS

For DBIC, execute() is just a thin dispatcher to each underlying method,
which is specified by the rs_method key.

  POE::Kernel->post($alias, 'execute', {
    moniker   => 'Table',
    rs_method => 'search', # default
    ... other arguments to search() ...
  });

  POE::Kernel->post($alias, 'execute', {
    moniker   => 'Table',
    rs_method => 'update',
    ... other arguments to update() ...
  });

Please note that at the time of writing, only search() is supported
(because that's the only thing I<I> need for now. patches welcome), and the
above "update" example doesn't actually work.

=head2 search ARGUMENTS

=over 4

=item moniker

The moniker for the resultset you want to operate against.

=item where

This specifies the WHERE condition given to search()

=item attrs

The attributes has given to search()

=back

  POE::Kernel->post( $alias, 'execute', {
    args => [
      {
        rs_method => 'search',
        moniker   => 'Foo',
        where     => \%where,
        attrs     => \%attrs,
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

=item rows

An arrayref containing the rows resulting from executing the SQL and fetching
results from it. The type of each value depends on the value of C<select_mode>
passed to execute().

Note that if select_mode is not specified, then the value of this slot is
always an empty list.

=item error

If execute() fails at any point because of an error, then this value is
populated with the value of the error. It is likely that if you DBIx::Class
failed during execution of a query, you will receive an object in this field.

=back

  {
    rows => [
      $row,
      $row,
      ...
    ],
    error => undef, # undef if no error
  }

=head1 METHODS

=head2 new

Creates a new POE::Component::MDBA::Backend::DBI instance. Takes a list of
arguments, which are directly passed to DBI-E<gt>connect()

=head2 execute

Executes the given query. For DBIC, this just delegates to the appropriate
method, denoted by rs_method

=head2 search

Runs search() against the moniker you provided.

=head1 CAVEATS

You need to use() your schema in your main class (or wherever you're using
the returned values), as POE::Component::Generic will execute these in a
different memory space.

Because data that's passed from/to POE::Component::Generic goes through
serialization, you need to use DBIx::Class::Serialize::Storable if you're
using DBIx::Class < 0.08

=head1 AUTHOR

Copyright (c) 2007 Daisuke Maki E<lt>daisuke@endeworks.jpE<gt>

=head1 SEE ALSO

L<POE::Component::MDBA|POE::Component::MDBA>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut