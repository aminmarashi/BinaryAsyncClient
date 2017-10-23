package BinaryAsync::Medium;

use strict;
use warnings;

use Ryu::Observable;
use Future;

sub new {
    my ($class, $msg) = @_;

    my $self = {};
    bless $self, $class;

    $self->{subscribe} = $msg->{subscribe};

    $self->{receiver} = $self->subscribe ? Ryu::Observable->new : Future->new;

    return $self;
}

sub dispatch {
    my ($self, $msg) = @_;

    return $self->handle_future($msg) unless $self->subscribe;

    return $self->receiver->set($msg);
}

sub handle_future {
    my ($self, $msg) = @_;

    if ($msg->{error}) {
        $self->receiver->fail($msg);
    } else {
        $self->receiver->done($msg);
    }

    return;
}

sub receiver { shift->{receiver} };

sub subscribe { shift->{subscribe} };

1;
