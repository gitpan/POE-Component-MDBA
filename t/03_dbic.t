use strict;
use Test::More;
use POE;
use DBI;
BEGIN
{
    eval "require DBD::SQLite";
    if ($@) {
        plan(skip_all => "This test requires SQLite");
    } else {
        plan(tests => 9);
    }
    use_ok("POE::Component::MDBA");
}
use lib("t/lib");
use MDBATest::Schema;

my $dbname = 't/03_dbic.db';

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", undef, undef, { RaiseError => 1, AutoCommit => 1 });
$dbh->do(<<EOSQL);
    CREATE TABLE site (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        url TEXT,
        description TEXT
    );
EOSQL
$dbh->do("INSERT INTO site (url, description) VALUES(?, ?)", undef, "http://www.perl.com", "perl.com");
$dbh->do("INSERT INTO site (url, description) VALUES(?, ?)", undef, "http://search.cpan.org", "CPAN");
$dbh->do("INSERT INTO site (url, description) VALUES(?, ?)", undef, "http://www.minico.jp", "minico");

my $alias = 'MDBATest';
POE::Component::MDBA->spawn(
    alias        => $alias,
    backend      => 'DBIC',
    backend_args => [
        ([ schema => 'MDBATest::Schema', connect_info => [ "dbi:SQLite:dbname=$dbname" ] ]) x 3
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
                args => [
                    { moniker => 'Site', attrs => { rows => 1, limit => 1, page => 1 } },
                    { moniker => 'Site', attrs => { rows => 1, limit => 1, page => 2 } },
                    { moniker => 'Site', attrs => { rows => 1, limit => 1, page => 3 } },
                ],
                aggregate => $_[SESSION]->postback('aggregate'),
                finalize => $_[SESSION]->postback('finalize')
            });
        },
        aggregate => sub {
            my $res_pack = $_[ARG1];
            my @results = @{$_[HEAP]->{results}};
            my $result  = $res_pack->[1];
            ok(! $result->{error}, "query produced no errors");
            push @results, $result->{rows}->[0];
            $_[HEAP]->{results} = [ sort { $a->get_column('url') cmp $b->get_column('url') } @results ];
        },
        finalize => sub {
            ok(1, "finalize properly called");
            my @results = @{ $_[HEAP]->{results} };
            is(scalar @results, 3, "3 items returned");
            is($results[0]->url, "http://search.cpan.org");
            is($results[1]->url, "http://www.minico.jp");
            is($results[2]->url, "http://www.perl.com");
            $_[KERNEL]->post($alias, 'shutdown');
            $_[KERNEL]->yield('_stop');
        }
    }
);

POE::Kernel->run;

END
{
    unlink $dbname;
}