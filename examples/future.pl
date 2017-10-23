use strict;
use warnings;

use BinaryAsyncConsumer;
use IO::Async::Loop;
use Variable::Disposition qw(retain_future);
use Data::Dumper;

my $loop = IO::Async::Loop->new;
my $ws_client = BinaryAsyncConsumer->new(
    loop => $loop,
    url => 'wss://ws.binaryws.com/websockets/v3?l=EN&app_id=1'
);

my $req = {
    proposal      => 1,
    amount        => 100,
    basis         => 'payout',
    currency      => 'USD',
    contract_type => 'CALL',
    symbol        => 'frxAUDJPY',
    duration      => 3,
    duration_unit => 'm'
};

retain_future($ws_client->request($req)->then(sub {
    warn Dumper shift;
    $loop->stop;
}));

$loop->run;

1;

