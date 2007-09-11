use strict;
use Test::More (tests => 3);
use POE;
BEGIN
{
    use_ok("POE::Component::MDBA");
}

my $alias = 'MDBATest';
POE::Component::MDBA->spawn(
    alias        => $alias,
    backend_args => [
        [ 'dbi:SQLite:dbname=t/02_dbi.db' ],
        [ 'dbi:SQLite:dbname=t/02_dbi.db' ],
        [ 'dbi:SQLite:dbname=t/02_dbi.db' ],
    ]
);

POE::Session->create(
    heap => { results => [] },
    inline_states => {
        _start => sub {
            $_[KERNEL]->alias_set('me');
            $_[KERNEL]->yield('query');
        },
        _stop => sub {
            $_[KERNEL]->alias_remove( 'me' );
        },
        query => sub {
            $_[KERNEL]->post($alias, 'execute', {
                select => 'fetchrow_arrayref',
                args => [
                    { sql => 'SELECT 1', select_method => 'fetchrow_arrayref' },
                    { sql => 'SELECT 2', select_method => 'fetchrow_arrayref' },
                    { sql => 'SELECT 3', select_method => 'fetchrow_arrayref' },
                ],
                aggregate => $_[SESSION]->postback('aggregate'),
                finalize => $_[SESSION]->postback('finalize')
            });
        },
        aggregate => sub {
            my $res_pack = $_[ARG1];
            my @results = @{$_[HEAP]->{results}};
            push @results, $res_pack->[1]->{rows}->[0]->[0];
            $_[HEAP]->{results} = [ sort @results ];
        },
        finalize => sub {
            ok(1, "finalize properly called");
            is_deeply($_[HEAP]->{results}, [ 1, 2, 3 ], "results are as expected");
            $_[KERNEL]->post($alias, 'shutdown');
            $_[KERNEL]->yield('_stop');
        }
    }
);

POE::Kernel->run;