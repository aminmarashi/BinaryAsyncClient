package BinaryAsync::Timeout;

use strict;
use warnings;

use parent qw(IO::Async::Notifier);

sub _add_to_loop {
    my ($self, $loop) = @_;

    $self->{timeout_future} = $self->loop->new_future;
}

sub reset {
    my $self = shift;

    $self->cancel;
    $self->{delay_future} =
        $self->loop->delay_future(after => $self->timeout)->then(sub { $self->timeout_future->fail({error => 'Stall timeout reached'}) });
}

sub cancel {
    my $self = shift;

    $self->delay_future->cancel if exists $self->{delay_future};

    delete $self->{delay_future};
}

sub configure {
    my ($self, %args) = @_;

    for my $k (qw(timeout)) {
        $self->{$k} = delete $args{$k} if exists $args{$k};
    }
    $self->next::method(%args);
}

sub timeout { shift->{timeout} }

sub timeout_future { shift->{timeout_future} }

sub delay_future { shift->{delay_future} }

1;
