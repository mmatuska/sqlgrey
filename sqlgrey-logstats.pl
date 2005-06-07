#!/usr/bin/perl -w

# sqlgrey: a postfix greylisting policy server using an SQL backend
# based on postgrey
# Copyright 2004 (c) ETH Zurich
# Copyright 2004 (c) Lionel Bouton

#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

package sqlgrey_logstats;
use strict;
use Pod::Usage;
use Getopt::Long qw(:config posix_default no_ignore_case);
use Time::Local;
use Date::Calc;

my $VERSION = "1.5.9";

######################
# Time-related methods
my %months = ( "Jan" => 0, "Feb" => 1, "Mar" => 2, "Apr" => 3, "May" => 4, "Jun" => 5,
	       "Jul" => 6, "Aug" => 7, "Sep" => 8, "Oct" => 9, "Nov" => 10, "Dec" => 11 );

sub validate_tstamp {
    my $self = shift;
    my $value = shift;
    my ($monthname, $mday, $hour, $min, $sec);
    if ($value =~ /^(\w{3}) ([\d ]\d) (\d\d):(\d\d):(\d\d)$/) {
        ($monthname, $mday, $hour, $min, $sec) = ($1, $2, $3, $4, $5);
    } else {
	$self->debug("invalid date format: $value\n");
        return undef;
    }
    my $month = $months{$monthname};
    my $year = $self->{year};
    if ($month > $self->{month}) {
	# yes we can compute stats across years...
	$year--;
    }
    my $epoch_seconds = Time::Local::timelocal($sec, $min, $hour, $mday, $month, $year);
    if (! $epoch_seconds) {
	$self->debug("can't compute timestamp from: $value\n");
        return undef;
    }
    if ($epoch_seconds < $self->{begin} or $epoch_seconds > $self->{end}) {
	$self->debug("date out of range: $value\n");
        return undef;
    }
    return $epoch_seconds;
}

# What was the tstamp yesterday at 00:00 ?
sub yesterday_tstamp {
    # Get today 00:00:00 and deduce one day
    my ($day, $month, $year) = reverse Date::Calc::Add_Delta_Days(Date::Calc::Today(), -1 );
    # Adjust Date::Calc 1-12 month to 0-11
    $month--;
    return Time::Local::timelocal(0,0,0,$day,$month,$year);
}

# What was the tstamp today at 00:00 ?
sub today_tstamp {
    # Get today 00:00:00
    return Time::Local::timelocal(0, 0, 0, ((localtime())[3,4,5]));
}

# set time period
sub yesterday {
    my $self = shift;
    $self->{begin} = $self->yesterday_tstamp();
    $self->{end} = $self->{begin} + (60 * 60 * 24);
}

sub today {
    my $self = shift;
    $self->{begin} = $self->today_tstamp();
    $self->{end} = time();
}

sub lasthour {
    my $self = shift;
    my $now = time();
    $self->{begin} = $now - (60 * 60);
    $self->{end} = $now;
}

sub lastday {
    my $self = shift;
    my $now = time();
    $self->{begin} = $now - (60 * 60 * 24);
    $self->{end} = $now;
}

sub lastweek {
    my $self = shift;
    my $now = time();
    $self->{begin} = $now - (60 * 60 * 24 * 7);
    $self->{end} = $now;
}

##################
# Argument parsing
sub parse_args {
    my $self = shift;
    my %opt = ();

    GetOptions(\%opt, 'help|h', 'man', 'version', 'yesterday|y', 'today|t',
	       'lasthour', 'lastday|d', 'lastweek|w', 'programname', 'debug',
	       'top-domain=i', 'top-from=i', 'top-spam=i', 'print-delayed')
	or pod2usage(1);

    if ($opt{help})    { pod2usage(1) }
    if ($opt{man})     { pod2usage(-exitstatus => 0, -verbose => 2) }
    if ($opt{version}) { print "sqlgrey-logstats.pl $VERSION\n"; exit(0) }

    my $count = 0;
    if ($opt{yesterday}) {
	$self->yesterday();
	$count++;
    }
    if ($opt{today}) {
	$self->today();
	$count++;
    }
    if ($opt{lasthour}) {
	$self->lasthour();
	$count++;
    }
    if ($opt{lastday}) {
	$self->lastday();
	$count++;
    }
    if ($opt{lastweek}) {
	$self->lastweek();
	$count++;
    }
    if ($count > 1) {
	pod2usage(1);
    }

    if ($opt{'top-domain'}) {
	$self->{top_domain} = $opt{'top-domain'};
    }
    if ($opt{'top-from'}) {
	$self->{top_from} = $opt{'top-from'};
    }
    if ($opt{'top-spam'}) {
	$self->{top_spam} = $opt{'top-spam'};
    }

    if ($opt{'print-delayed'}) {
	$self->{print_delayed} = 1;
    }

    # compute year and month for end of data
    ($self->{month}, $self->{year}) = (localtime($self->{end}))[4,5];

    if ($opt{programname}) {
	$self->{programname} = $opt{programname};
    }

    if ($opt{debug}) {
	$self->{debug} = 1;
    }
}

################
# percent string
sub percent {
    my $portion = shift;
    my $total = shift;
    if ($total == 0) {
	return "N/A%";
    }
    return sprintf ("%.2f%%", ($portion / $total) * 100);
}

# quick debug function
sub debug {
    my $self = shift;
    if (defined $self->{debug}) {
	print shift;
    }
}

sub split_date_event {
    my ($self, $line) = @_;

    if ($line =~
	m/^(\w{3} [\d ]\d \d\d:\d\d:\d\d) \w+ $self->{programname}: (\w+): (.*)$/o
	) {
	my $time = $self->validate_tstamp($1);
	if (! defined $time) {
	    return (undef,undef,undef);
	} else {
	    #$self->debug("match: $time, $2, $3\n");
	    return ($time, $2, $3);
	}
    } else {
	$self->debug("not matched: $line\n");
	return (undef,undef,undef);
    }
}

sub parse_grey {
    my ($self, $time, $event) = @_;
    if ($event =~ /^domain awl match: updating ([\d\.]+), (.*)$/) {
	$self->{events}++;
	$self->{passed}++;
	$self->{domain_awl_match}{$1}{$2}++;
	$self->{domain_awl_match_count}++;
    } elsif ($event =~ /^from awl match: updating ([\d\.]+), (.*)$/) {
	$self->{events}++;
	$self->{passed}++;
	$self->{from_awl_match}{$1}{$2}++;
	$self->{from_awl_match_count}++;
    } elsif ($event =~ /^new: ([\d\.]+), (.*) -> (.*)$/) {
	$self->{events}++;
	$self->{new}{$1}++;
	$self->{new_count}++;
    } elsif ($event =~ /^early reconnect: ([\d\.]+), (.*) -> (.*)$/) {
	$self->{events}++;
	$self->{early}{$1}++;
	$self->{early_count}++;
    } elsif ($event =~ /^reconnect ok: ([\d\.]+), (.*) -> (.*) \((.*)\)/) {
	$self->{events}++;
	$self->{passed}++;
	$self->{reconnect}{$1}{$2}++;
	$self->{reconnect_count}++;
    } elsif ($event =~ /^domain awl: ([\d\.]+), (.*) added$/) {
	## what?
    } elsif ($event =~ /^from awl: ([\d\.]+), (.*) added$/) {
	## what?
    } elsif ($event =~ /^from awl: [\d\.]+, .* added/) {
	## what?
    } elsif ($event =~ /^domain awl: [\d\.]+, .* added/) {
	## what?
    } else {
	$self->debug("unknown grey event at $time: $event\n");
    }
}

sub parse_whitelist {
    my ($self, $time, $event) = @_;
    if ($event =~ /^(.*), ([\d\.]+)\((.*)\) -> (.*)$/) {
	$self->{events}++;
	$self->{passed}++;
	$self->{whitelisted}++;
	$self->{whitelisted_ip}{$2}++;
	$self->{whitelisted_fqdn}{$3}++;
    } else {
	$self->debug("unknown whitelist event at $time: $event\n");
    }
}

sub parse_spam {
    my ($self, $time, $event) = @_;
    if ($event =~ /^([\d\.]+): (.*) -> (.*) at (.*)$/) {
	$self->{rejected_count}++;
	$self->{rejected}{$1}{$2}++;
    } else {
	$self->debug("unknown spam event at $time: $event\n");
    }
}

sub parse_perf {
}

sub parse_line {
    my ($self, $line) = @_;

    my ($time, $type, $event) = $self->split_date_event($line);
    if (! defined $time) {
	return;
    }
    # else parse event
    if ($type eq 'grey') {
	$self->parse_grey($time, $event);
    } elsif ($type eq 'whitelist') {
	$self->parse_whitelist($time, $event);
    } elsif ($type eq 'spam') {
	$self->parse_spam($time, $event);
    } elsif ($type eq 'perf') {
	$self->parse_perf($time, $event);
    } # don't care for other types
}

sub print_awl {
    my $self = shift;
    $self->print_domain_awl();
    $self->print_from_awl();
}

sub print_domain_awl {
    my $self = shift;
    my @top;
    my $idx;
    foreach my $ip (keys(%{$self->{domain_awl_match}})) {
	my $hash;
	$hash->{count} = 0;
	$hash->{ip} = $ip;
	foreach my $domain (keys(%{$self->{domain_awl_match}{$ip}})) {
	    $hash->{count} += $self->{domain_awl_match}{$ip}{$domain};
	}
	$top[$#top+1] = $hash;
	@top = reverse sort { $a->{count} <=> $b->{count} } @top;
	pop @top if (($self->{top_domain} != -1) && ($#top >= $self->{top_domain}));
    }
    if ($self->{top_domain} != -1) {
	print "--------------------------------\n". 
	    "  Domain AWL top " . ($#top + 1) . " sources\n" .
	    "--------------------------------\n\n";
    } else {
	print "---------------------\n" .
	    "  Domain AWL full\n" .
	    "---------------------\n\n";
    }
    for ($idx = 0; $idx <= $#top; $idx++) {
	my @dtop;
	foreach my $domain (keys(%{$self->{domain_awl_match}{$top[$idx]->{ip}}})) {
	    my $hash;
	    $hash->{count} = $self->{domain_awl_match}{$top[$idx]->{ip}}{$domain};
	    $hash->{domain} = $domain;
	    $dtop[$#dtop+1] = $hash;
	    @dtop = sort { $a->{count} <=> $b->{count} } @dtop;
	}
	@dtop = reverse @dtop;
	print "$top[$idx]->{ip}: $top[$idx]->{count}\n";
	for (my $didx = 0; $didx <= $#dtop; $didx++) {
	    print "            $dtop[$didx]->{domain}: $dtop[$didx]->{count}\n";
	}
    }
    print "\n";
}

sub print_from_awl {
    my $self = shift;
    my @top;
    my $idx;
    foreach my $ip (keys(%{$self->{from_awl_match}})) {
	my $hash;
	$hash->{count} = 0;
	$hash->{ip} = $ip;
	foreach my $from (keys(%{$self->{from_awl_match}{$ip}})) {
	    $hash->{count} += $self->{from_awl_match}{$ip}{$from};
	}
	$top[$#top+1] = $hash;
	@top = reverse sort { $a->{count} <=> $b->{count} } @top;
	pop @top if (($self->{top_from} != -1) && ($#top >= $self->{top_from}));
    }
    if ($self->{top_from} != -1) {
	print "----------------------------\n". 
	    "  From AWL top " . ($#top + 1) . " sources\n" .
	    "----------------------------\n\n";
    } else {
	print "-----------------\n" .
	    "  From AWL full\n" .
	    "-----------------\n\n";
    }
    for ($idx = 0; $idx <= $#top; $idx++) {
	my @ftop;
	foreach my $from (keys(%{$self->{from_awl_match}{$top[$idx]->{ip}}})) {
	    my $hash;
	    $hash->{count} = $self->{from_awl_match}{$top[$idx]->{ip}}{$from};
	    $hash->{from} = $from;
	    $ftop[$#ftop+1] = $hash;
	    @ftop = sort { $a->{count} <=> $b->{count} } @ftop;
	}
	@ftop = reverse @ftop;
	print "$top[$idx]->{ip}: $top[$idx]->{count}\n";
	for (my $didx = 0; $didx <= $#ftop; $didx++) {
	    print "            $ftop[$didx]->{from}: $ftop[$didx]->{count}\n";
	}
    }
    print "\n";
}

sub print_spam {
    my $self = shift;
    my @top;
    my $idx;
    foreach my $ip (keys(%{$self->{rejected}})) {
	my $hash;
	$hash->{count} = 0;
	$hash->{ip} = $ip;
	foreach my $from (keys(%{$self->{rejected}{$ip}})) {
	    $hash->{count} += $self->{rejected}{$ip}{$from};
	}
	$top[$#top+1] = $hash;
	@top = reverse sort { $a->{count} <=> $b->{count} } @top;
	pop @top if (($self->{top_spam} != -1) && ($#top >= $self->{top_spam}));
    }
    if ($self->{top_from} != -1) {
	print "--------------------\n". 
	    "   top " . ($#top + 1) . " sources\n" .
	    "--------------------\n\n";
    }
    for ($idx = 0; $idx <= $#top; $idx++) {
	my @stop;
	foreach my $from (keys(%{$self->{rejected}{$top[$idx]->{ip}}})) {
	    my $hash;
	    $hash->{count} = $self->{rejected}{$top[$idx]->{ip}}{$from};
	    $hash->{from} = $from;
	    $stop[$#stop+1] = $hash;
	    @stop = sort { $a->{count} <=> $b->{count} } @stop;
	}
	@stop = reverse @stop;
	print "$top[$idx]->{ip}: $top[$idx]->{count}\n";
	for (my $didx = 0; $didx <= $#stop; $didx++) {
	    print "            $stop[$didx]->{from}: $stop[$didx]->{count}\n";
	}
    }
    print "\n";
}

sub print_delayed {
    my $self = shift;
    if (! defined $self->{print_delayed}) {
	return;
    }
    my @top;
    my $idx;
    foreach my $ip (keys(%{$self->{reconnect}})) {
	my $hash;
	$hash->{count} = 0;
	$hash->{ip} = $ip;
	foreach my $from (keys(%{$self->{reconnect}{$ip}})) {
	    $hash->{count} += $self->{reconnect}{$ip}{$from};
	}
	$top[$#top+1] = $hash;
	@top = reverse sort { $a->{count} <=> $b->{count} } @top;
    }
    for ($idx = 0; $idx <= $#top; $idx++) {
	my @stop;
	foreach my $from (keys(%{$self->{reconnect}{$top[$idx]->{ip}}})) {
	    my $hash;
	    $hash->{count} = $self->{reconnect}{$top[$idx]->{ip}}{$from};
	    $hash->{from} = $from;
	    $stop[$#stop+1] = $hash;
	    @stop = sort { $a->{count} <=> $b->{count} } @stop;
	}
	@stop = reverse @stop;
	print "$top[$idx]->{ip}: $top[$idx]->{count}\n";
	for (my $didx = 0; $didx <= $#stop; $didx++) {
	    print "            $stop[$didx]->{from}: $stop[$didx]->{count}\n";
	}
    }
    print "\n";
}

sub print_stats {
    my $self = shift;
    print "##################\n" .
	"## Global stats ##\n" .
	"##################\n\n";
    print "Events      : " . $self->{events} . "\n";
    print "Passed      : " . $self->{passed} . "\n";
    print "Rejected    : " . $self->{rejected_count} . "\n";
    print "Early       : " . $self->{early_count} . "\n";
    print "\n###############################\n" .
	"## Whitelist/AWL performance ##\n" .
	"###############################\n\n";
    print "Whitelists  : " .
        percent($self->{whitelisted}, $self->{passed}) .
	"\t($self->{whitelisted})\n";
    print "Domain AWL  : " .
        percent($self->{domain_awl_match_count}, $self->{passed}) .
        "\t($self->{domain_awl_match_count})\n";
    print "From AWL    : " .
	percent($self->{from_awl_match_count}, $self->{passed}) .
	"\t($self->{from_awl_match_count})\n";
    print "Delayed     : " .
	percent($self->{reconnect_count},$self->{passed}) .
	"\t($self->{reconnect_count})\n";
#     print "\n#######################\n" .
# 	"## Whitelist details ##\n" .
# 	"#######################\n\n";
#     $self->print_whitelist();
    print "\n#################\n" .
	"## AWL details ##\n" .
	"#################\n\n";
    $self->print_awl();
    print "\n##################\n" .
	"## SPAM details ##\n" .
	"##################\n\n";
    $self->print_spam();
    print "#####################\n" .
	"## Delayed details ##\n" .
	"#####################\n\n";
    $self->print_delayed();
}

# create parser with no period limits
# and counters set to 0
my $parser = bless {
    begin => 0,
    end => (1 << 31) - 1,
    programname => 'sqlgrey',
    events => 0,
    passed => 0,
    whitelisted => 0,
    rejected_count => 0,
    new_count => 0,
    early_count => 0,
    domain_awl_match_count => 0,
    from_awl_match_count => 0,
    reconnect_count => 0,
    top_domain => -1,
    top_from => -1,
    top_spam => -1,
}, 'sqlgrey_logstats';

$parser->parse_args();

while (<STDIN>) {
    chomp;
    $parser->parse_line($_);
}

$parser->print_stats();

__END__

=head1 NAME

sqlgrey-logstats.pl - SQLgrey log parser

=head1 SYNOPSIS

B<sqlgrey-logstats.pl> [I<options>...] < syslogfile

 -h, --help             display this help and exit
     --man              display man page
     --version          output version information and exit
     --debug            output detailed log parsing steps

 -y, --yesterday        compute stats for yesterday
 -t, --today            compute stats for today
     --lasthour         compute stats for last hour
 -d, --lastday          compute stats for last 24 hours
 -w, --lastweek         compute stats for last 7 days

     --programname      program name looked into log file

     --top-from         how many from AWL entries to print (default: all)
     --top-domain       how many domain AWL entries to print (default: all)
     --top-spam         how many SPAM sources to print (default: all)
     --print-delayed    print delayed sources (default: don't)

=head1 DESCRIPTION

sqlgrey-logstats.pl ...

=head1 SEE ALSO

See L<http://www.greylisting.org/> for a description of what greylisting
is and L<http://www.postfix.org/SMTPD_POLICY_README.html> for a
description of how Postfix policy servers work.

=head1 COPYRIGHT

Copyright (c) 2004 by Lionel Bouton.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=head1 AUTHOR

S<Lionel Bouton E<lt>lionel-dev@bouton.nameE<gt>>

=cut
