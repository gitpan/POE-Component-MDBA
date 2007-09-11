# $Id: /mirror/perl/POE-Component-MDBA/trunk/lib/POE/Component/MDBA.pm 2541 2007-09-11T13:25:08.143151Z daisuke  $
#
# Copyright (c) 2007 Daisuke Maki <daisuke@endeworks.jp>
# All rights reserved.

package POE::Component::MDBA;
use strict;
use Digest::MD5  ();
use Data::Dumper ();
use POE qw(Component::Generic);
use vars qw($VERSION);
$VERSION = '0.01000';

sub spawn
{
    my $class = shift;
    my %args  = @_;

    my $alias   = $args{alias} || 'MDBA';
    my $backend = $args{backend} || 'DBI';
    if ($backend !~ s/^\+//) {
        $backend = "POE::Component::MDBA::Backend::$backend";
    }

    eval "require $backend";
    die if $@;

    my @backends;
    foreach my $args (@{ $args{backend_args} }) {
        push @backends, POE::Component::Generic->spawn(
            package => $backend,
            object_options => $args,
            methods => [ qw(execute) ],
        );
    }

    my %heap = (
        alias          => $alias,
        backends       => \@backends,
        active_queries => {},
    );
    POE::Session->create(
        heap => \%heap,
        package_states => [
            $class => {
                map { ($_ => "_evt_$_") }
                    qw(_start _stop shutdown execute aggregate)
            }
        ]
    );
}

sub _signature
{
    local $Data::Dumper::Indent = 1;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Sortkeys = 1;
    Digest::MD5::md5_hex( Data::Dumper::Dumper(\@_) );
}

sub _evt_shutdown
{
    my($kernel, $heap) = @_[KERNEL, HEAP];
    foreach my $backend (@{$heap->{backends}}) {
        $kernel->post($backend->session_id, 'shutdown');
    }
}

sub _evt__start
{
    my($kernel, $heap) = @_[KERNEL, HEAP];
    $kernel->alias_set( $heap->{alias} );
}

sub _evt__stop
{
    my($kernel, $heap) = @_[KERNEL, HEAP];
    $kernel->call($_[SESSION], 'cleanup');
    $kernel->alias_remove( $heap->{alias} );
}

sub _evt_execute
{
    my($kernel, $heap, $session, $args) = @_[KERNEL, HEAP, SESSION, ARG0];

    my $count         = 0;
    my $backends      = $heap->{backends};
    my $backend_count = scalar(@$backends);
    my $search_args   = $args->{args};
    my $query_id      = _signature('_evt_execute', $args, $$, {}, time());
    my %dispatched    = ();
    my %query_map     = (
        aggregate  => $args->{aggregate},
        finalize   => $args->{finalize},
        dispatched => \%dispatched
    );

    foreach my $sa (@$search_args) {
        my $idx     = $count++ % $backend_count;
        my $backend = $backends->[$idx];
        my $id      = join('.', $query_id, $count);
        my %cookie  = (
            session  => $session->ID,
            event    => 'aggregate',
            query_id => $query_id,
            id       => $id
        );
        my %opts    = (
            query_id => $query_id,
            id       => $id
        );
        $dispatched{ $id }++;
        $backend->execute(\%cookie, $sa, \%opts);
    }

    $heap->{active_queries}{ $query_id } = \%query_map;
}

sub _evt_aggregate
{
    my($kernel, $heap, $ref, $result) = @_[KERNEL, HEAP, ARG0, ARG1];

    my $query_map = $heap->{active_queries}{ $ref->{query_id} };
    my $dispatch_map = $query_map->{dispatched};
    delete $dispatch_map->{ $ref->{id} };

    if (my $fn = $query_map->{aggregate}) {
        $fn->($ref, $result);
    }

    if (keys %$dispatch_map == 0) {
        # cleanup
        delete $heap->{active_queries}{ $ref->{query_id} };
        if (my $fn = $query_map->{finalize}) {
            $fn->($ref, $result);
        }
    }
}

1;

__END__

=head1 NAME

POE::Component::MDBA - Multi-Database Aggregation with POE

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

WARNING: Alpha grade software! API still subject to change.

MDBA Stands for Multi-Database Aggregation. This module is a helper module 
that allows you to send multiple (possibly all different) queries to multiple
databases.

One application that this might be useful is when you access a 
vertically-partitioned database cluster. A vertically-partitioned database 
cluster is a set of databases whose table definitions are same across each
database instance, but the each database instance is responsible for a
different set of data.

This type of application typically requires that you send slightly differing
SQL queries to each database instance, then aggregate the results into a
single result. With normal DBI operation, it would look something like:

  my @connect_info;
  my @sql;
  my @args;
  my @results;
  for my $x (0..$n) {
    # connect to a database
    my $dbh = DBI->connect( @{ $connect_info[$x] } );

    # get the applicable sql and arguments for this database
    my $sql  = $sql[$x];
    my $args = $args[$x]; 
    my $sth  = $dbh->prepare( $sql );

    $sth->execute(@$args);
    while (my $row = $sth->fetchrow_hashref) {
      push @results, $row;
    }
  }
  return @results;

But of course, this will make the client wait while it queries $n database
instances - it would be nice if we just parallelized all of these, and be
able to merge the results.

POE::Component::MDBA acomplishes this by pre-spawning multiple databases, and
sending asynchronous queries to those database instances. As soon as each
query is done, an I<aggregator> function is called so you can merge the results
to your liking.

However, the main complexity lies in the fact that usually each application 
likes to run these queries in their own way, hence making (1) query
partitioning (2) sql handling, and (3) results merging completely different
from application to application.

POE::Component::MDBA attempts to solve this by separating each of these
steps from the module logic and thus making each step configurable.

But no worries if you just want to run a simple query. 
The POE::Component::MDBA::Backend modules that come with this module
will handle most of the simple cases for you.

Please see L<POE::Component::MDBA::Backend::DBI> for the details on how to
send these queries.

=head1 METHODS

=head2 spawn %args

Creates a new instance of POE::Component::MDBA. Possible arguments are:

=over 4

=item backend

Specify the backend package to use. The default is 'DBI'.
By default the namespace 'POE::Component::MDBA::Backend::' is prepended to
this argument. If you want so specify something that's not in this namespace,
put a leading '+' in the argument (e.g. '+My::Backend').

=item backend_args

An arrayref of whatever options you would like to pass to the backend
constructor. POE::Component::MDBA will spawn as many backends as there are
arguments in this list.

The actual argument format depends on each backend.

=back

=head1 AUTHOR

Copyright (c) 2007 Daisuke Maki E<lt>daisuke@endeworks.jpE<gt>

=head1 SEE ALSO

L<POE|POE> L<POE::Component::Generic|POE::Component::Generic> L<POE::Component::MDBA::Backend|POE::Component::MDBA::Backend> L<POE::Component::MDBA::Backend::DBI|POE::Component::MDBA::Backend::DBI>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut