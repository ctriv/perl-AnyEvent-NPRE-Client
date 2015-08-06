package AnyEvent::NRPE::Client;

use strict;
use warnings;
use Nagios::NRPE::Packet qw(
    NRPE_PACKET_VERSION_2 NRPE_PACKET_QUERY MAX_PACKETBUFFER_LENGTH
    STATE_UNKNOWN STATE_CRITICAL STATE_WARNING STATE_OK
);
use AnyEvent::Socket;
use AnyEvent::Handle;
use base qw(Exporter);

our @EXPORT = qw(npre_request);

=head1 NAME

AnyEvent::NRPE::Client - Non blocking NPRE Client

=head1 SYNOPSIS

    npre_request
        host     => '12.23.34.45',
        port     => 1234,
        timeout  => 15,
        ssl      => 1,
        check    => 'check_command',
        argslist => [qw/foo bar/],
        sub {
            my ($result) = @_;
            # result would be something like:
            # {
            #   version => NRPE_VERSION,
            #   type => RESPONSE_TYPE,
            #   crc32 => CRC32_CHECKSUM,
            #   code => RESPONSE_CODE,
            #   buffer => CHECK_OUTPUT
            # }
        };

=head1 DESCRIPTION

NPRE is a protocal for running a nagios check on a remote server.  This module
provides an AnyEvent native non-blocking client for NPRE.

=cut

sub npre_request {
    my $cb   = pop;
    my %args = @_;

    if (scalar @{$args{arglist}}) {
        $args{check} = join('!', $args{check}, @{$args{arglist}});
    }

    tcp_connect $args{host}, $args{port}, sub {
        my ($fh) = @_;
        my $buf  = '';

        my $packet = Nagios::NPRE::Packet->new(
            type    => NRPE_PACKET_QUERY,
            check   => $args{check},
            version => NRPE_PACKET_VERSION_2
        );

        my $hdl  = AnyEvent::Handle->new(
            fh => $fh,
            on_error => sub {
                my ($handle, $fatal, $msg) = @_;
                $handle->destroy;
                die $msg;
            },
            on_read => sub {
                my ($handle) = @_;
                $buf .= $handle->rbuf;
            },
            on_eof => sub {
                $cb->($packet->deassemble($buf));
            }
        );

        $hdl->push_write($packet->assemble);
    };
}


1;
__END__
