package BinaryAsyncConsumer;

use strict;
use warnings;

use Medium;

use IO::Async::SSL;
use Net::Async::WebSocket::Client;
use Scalar::Util qw(weaken);
use JSON::MaybeXS;
use Encode;
use curry;
use URI;

my $json = JSON::MaybeXS->new;

sub dumper { use Data::Dumper; warn Dumper shift };

sub new {
    my ($class, %args) = @_;

    my $self = {
        loop => $args{loop},
        url => $args{url},
        receive_medium => {},
    };

    bless $self, $class;

    $self->{client} = Net::Async::WebSocket::Client->new(
        on_frame => $self->curry::weak::on_frame,
    );

    $args{loop}->add($self->{client});

    my $uri = URI->new($self->{url});

    $self->{client}->connect(
        url        => $self->{url},
        host       => $uri->host,
        ($uri->scheme eq 'wss'
         ? (
             service      => 443,
             extensions   => [ qw(SSL) ],
             SSL_hostname => $uri->host,
           ) : (
               service    => 80,
               ))
        )->get;

    return $self;
}

sub request {
    my ($self, $msg) = @_;

    return $self->create_medium_and_send({
        %{$msg},
        req_id => ++$self->{req_id},
    });
}

sub subscribe {
    my ($self, $msg) = @_;

    return $self->request({ %{$msg}, subscribe => 1 });
}

sub create_medium_and_send {
    my ($self, $msg) = @_;

    my $receive_medium = Medium->new($msg);
    $self->{receive_medium}->{$msg->{req_id}} = $receive_medium; 

    $self->{client}->send_frame($json->encode($msg));

    return $receive_medium->{receiver};
}

sub on_frame {
    my ($self, $ws, $bytes) = @_;
    my $text = Encode::decode_utf8($bytes);

    my $payload;
    eval {
        $payload = $json->decode($text);
    } or do {
        warn "Discarding corrupted frame: " . Dumper $text;
    };

    return $self->dispatch($payload);
}

sub dispatch {
    my ($self, $payload) = @_;

    my $req_id = $payload->{req_id};

    return unless exists $self->{receive_medium}->{$req_id}, 

    return $self->{receive_medium}->{$req_id}->dispatch($payload);
}

1;

