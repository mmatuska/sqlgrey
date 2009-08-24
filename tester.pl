#!/usr/bin/perl

# Tester for SQLgrey
# Michal Ludvig <mludvig@logix.net.nz> (c) 2009

use strict;
use IO::Socket::INET;
use Getopt::Long;

my $host = "localhost";
my $port = 2501;
my $client_address = "";
my $client_name = "";
my $sender = "";
my $recipient = "";

GetOptions (
	'host|server=s' => \$host,
	'port=i' => \$port,
	'client-ip|client-address=s' => \$client_address,
	'name|client-name=s' => \$client_name,
	'sender|from=s' => \$sender,
	'recipient|to=s' => \$recipient,
	'help' => sub { &usage(); },
);

if (not $client_address) {
	&usage();
}

my %connect_args = (
	PeerAddr => $host,
	PeerPort => $port,
	Proto => 'tcp',
	Timeout => 5);

my $sock = IO::Socket::INET->new(%connect_args) or die ("Connect failed: $@\n");

$sock->print("request=smtpd_access_policy
protocol_state=RCPT
protocol_name=SMTP
client_address=$client_address
client_name=$client_name
reverse_client_name=$client_name
helo_name=$client_name
sender=$sender
recipient=$recipient
recipient_count=0
queue_id=
instance=abc.defghi.jklm.no
size=0
etrn_domain=
sasl_method=
sasl_username=
sasl_sender=
ccert_subject=
ccert_issuer=
ccert_fingerprint=
encryption_protocol=
encryption_cipher=
encryption_keysize=0

");

print $sock->getline();

exit(0);

sub usage()
{
	print(
"Test tool for SQLgrey daemon.

Author: Michal Ludvig <mludvig\@logix.net.nz> (c) 2009
        http://www.logix.net.nz

Usage: tester.pl --client-ip <address> [--options]

        --host          address to talk to (default: 127.0.0.1)
        --port          TCP port SQLgrey daemon listens on (2501)

        --client-ip     IP or IPv6 address of the 'client' (Required).
        --client-fqdn   Domain name corresponding to --ip
        --sender / --from
                        Envelop MAIL FROM value
        --recipient / --to
                        Envelop RCPT TO value
        
        --help          Guess what ;-)
");
	exit(0);
}
