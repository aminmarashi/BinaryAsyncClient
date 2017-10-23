use strict;
use warnings;

use BinaryAsyncConsumer;
use IO::Async::Loop;
use Data::Dumper; 

my $loop = IO::Async::Loop->new;
my $ws_client = BinaryAsyncConsumer->new(
    loop => $loop,
    url => 'wss://ws.binaryws.com/websockets/v3?l=EN&app_id=1'
);

my $req = {
    proposal      => 1,
    subscribe     => 1,
    amount        => 100,
    basis         => 'payout',
    currency      => 'USD',
    contract_type => 'CALL',
    symbol        => 'frxAUDJPY',
    duration      => 3,
    duration_unit => 'm'
};

my $count = 0;
my $observed;
my $subscription;
$subscription = sub {
    warn Dumper shift;

    if (++$count == 3) {
        $observed->unsubscribe($subscription);
        $loop->stop;
    }
};
$observed = $ws_client->request($req)->subscribe($subscription);

$loop->run;

1;

