package BinaryAsync::Client;

use strict;
use warnings;

use parent qw(IO::Async::Notifier);

use BinaryAsync::Medium;

use IO::Async::SSL;
use Net::Async::WebSocket::Client;
use Scalar::Util qw(weaken);
use Variable::Disposition qw(retain_future);
use JSON::MaybeXS;
use Encode;
use curry;
use URI;

my $json = JSON::MaybeXS->new;

sub connection {
    my ($self, %args) = @_;

    $self->{ws_connection} ||= do {
        my $ws_uri = $self->uri or die 'no websocket URI available';

        my $uri = URI->new($ws_uri);

        $self->{client}->connect(
            url  => $ws_uri,
            host => $uri->host,
            (
                $uri->scheme eq 'wss'
                ? (
                    service      => 443,
                    extensions   => [qw(SSL)],
                    SSL_hostname => $uri->host,
                    )
                : (
                    service => 80,
                )));
    };
}

sub request {
    my ($self, $msg) = @_;

    return $self->create_medium_and_send({
        %{$msg},
        req_id => $self->req_id,
    });
}

sub await_request {
    my ($self, $msg) = @_;

    return $self->loop->await($self->request($msg))->get;
}

sub create_medium_and_send {
    my ($self, $msg) = @_;

    my $medium = BinaryAsync::Medium->new($msg);
    $self->recv_mediums->{$msg->{req_id}} = $medium;

    retain_future(
        $self->connection->then(
            sub {
                shift->send_frame($json->encode($msg));
            }
            )->else(
            sub {
                $medium->dispatch({error => 'Cannot connect to the websocket server'});
            }));

    return $medium->receiver;
}

sub on_frame {
    my ($self, $ws, $bytes) = @_;
    my $text = Encode::decode_utf8($bytes);

    my $payload;
    eval { $payload = $json->decode($text); } or do {
        warn "Discarding corrupted frame: " . Dumper $text;
    };

    return $self->dispatch($payload);
}

sub dispatch {
    my ($self, $payload) = @_;

    my $req_id = $payload->{req_id};

    return unless exists $self->recv_mediums->{$req_id},

        return $self->recv_mediums->{$req_id}->dispatch($payload);
}

sub _add_to_loop {
    my ($self, $loop) = @_;

    $self->add_child(
        $self->{client} = Net::Async::WebSocket::Client->new(
            on_frame => $self->curry::weak::on_frame,
        ));
}

sub configure {
    my ($self, %args) = @_;

    for my $k (qw(uri)) {
        $self->{$k} = delete $args{$k} if exists $args{$k};
    }
    $self->next::method(%args);
}

sub recv_mediums { shift->{recv_mediums} //= {} }

sub uri { shift->{uri} }

sub req_id { ++shift->{req_id} }

1;

