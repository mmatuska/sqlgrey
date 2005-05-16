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

my $VERSION = '1.5.6';

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
    my $epoch_seconds = Time::Local::timelocal($sec, $min, $hour, $mday, $month, $self->{YEAR});
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
    # Get today 00:00:00 and deduce one day
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

sub parse_args {
    my $self = shift;
    my %opt = ();

    GetOptions(\%opt, 'help|h', 'man', 'version', 'yesterday|y', 'today|t',
	       'lasthour', 'lastday|d', 'lastweek|w', 'programname')
	or exit(1);

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

    if ($opt{programname}) {
	$self->{programname} = $opt{programname};
    }

    if ($opt{debug}) {
	$self->{debug} = 1;
    }
}

# quick debug function
sub debug {
    my $self = shift;
    if (defined $slef->{debug}) {
	print shift;
    }
}

sub split_date_event {
    my ($self, $line) = @_;

    if ($line =~ /^(\w{3} [\d ]\d \d\d:\d\d:\d\d) \w+ $self->{programname}: (\w+): (.*)$/) {
	my $time = validate_tstamp($1);
	return ($time, $2; $3);
    } else {
	$self->debug("not matched: $line\n");
	return (undef,undef,undef);
    }
}

sub parse_line {
    my ($self, $line) = @_;

    my ($time, $type, $event) = split_date_event($line);
    if (! defined $time) {
	return;
    }
    # else parse event
}

sub print_stats {
}

# create parser with no period limits
my $parser = bless {
    begin => 0,
    end => (1 << 31) - 1,
    programname => 'sqlgrey',
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

B<sqlgrey-logstats.pl> [I<options>...]

 -h, --help             display this help and exit
     --man              display man page
     --version          output version information and exit
     --debug            output detailed log parsing steps

 -y, --yesterday        compute stats for yesterday
 -t, --today            compute stats for today
     --lasthour         compute stats for last hour
 -d, --lastday          compute stats for last 24 hours
 -w, --lastweek         compute stats for last 7 days

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
