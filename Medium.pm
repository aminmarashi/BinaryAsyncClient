package Medium;

use strict;
use warnings;

use Ryu::Observable;
use Future;

sub new {
    my ($class, $msg) = @_;

    my $self = {};

    $self->{receiver} = $msg->{subscribe} ? Ryu::Observable->new : Future->new;

    return bless $self, $class;
}

sub dispatch {
    my ($self, $msg) = @_;
    
    my $receiver = $self->{receiver};
    return handle_future($receiver, $msg) if ref $receiver eq 'Future';

    return $receiver->set($msg);
}

sub handle_future {
    my ($future, $msg) = @_;

    if ($msg->{error}) {
        $future->fail($msg);
    } else {
        $future->done($msg);
    }

    return;
}

1;
