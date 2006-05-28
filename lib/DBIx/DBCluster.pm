######################################################################
# Description: Wrapper around DBI's database handler that allows     #
#              connecting to multiple mirrored DB servers in order   #
#              to distribute load                                    #
# Author:      Alex Rak (arak@cpan.org)                              #
# Version:     0.01 (17-June-2003)                                   #
# Copyright:   See COPYRIGHT section in POD text below for usage and #
#              distribution rights                                   #
######################################################################

package DBIx::DBCluster;

use 5.006;
use strict;
use warnings;

use Carp;
use Data::Dumper;
use DBI;
DBI->require_version(1.37);


our $VERSION = "0.01";


our $AUTOLOAD;
our $CLUSTERS;
our $DEBUG;
our @WRITE_COMMANDS;
our $WRITE_HOSTS_NEVER_READ;

my %PRIVATE;


eval "require DBIx::DBCluster::Config";


sub connect {
	my $class = shift;
	my ($dsn, $user, $pass, $attr, $old_driver) = my @orig_args = @_;

	my ($write_dbh,$read_dbh);
	my $hostname = _get_hostname($dsn);

	_debug("Analyzing this hostname/label: $hostname");
	_debug("No such label found in cluster definitions - will try this as a hostname") unless defined $CLUSTERS->{$hostname};


	return DBI->connect(@orig_args) unless defined $CLUSTERS->{$hostname};

	my $cluster = $CLUSTERS->{$hostname};

	croak "WRITE_HOSTS are not declared in $hostname cluster configuration" unless (defined $cluster->{'WRITE_HOSTS'} && $#{$cluster->{'WRITE_HOSTS'}} != -1);
	croak "READ_HOSTS are not declared in $hostname cluster configuration" unless (defined $cluster->{'READ_HOSTS'} && $#{$cluster->{'READ_HOSTS'}} != -1);


	##  Set up WRITE host
	_debug("Loading WRITE_HOSTS for $hostname: '" . join("','",@{$cluster->{'WRITE_HOSTS'}}), "'");

	my $start_point = int(rand($#{$cluster->{'WRITE_HOSTS'}} + 1));
	my $write_host;
	for (0 .. $#{$cluster->{'WRITE_HOSTS'}}){
		$write_host = @{$cluster->{'WRITE_HOSTS'}}[$start_point];
		_debug("Trying $write_host...");

		my $new_dsn = _rebuild_dsn($dsn,$hostname,$write_host);
		$write_dbh = DBI->connect($new_dsn, $user, $pass, $attr, $old_driver);
		if ($write_dbh){
			_debug("Looks good - will use this one for writing");
			last;
		}

		_debug("$write_host is no good");
		$start_point++;
		$start_point = 0 if $start_point > $#{$cluster->{'WRITE_HOSTS'}};
	}

	unless ($write_dbh){
		carp "Could not connect to any server in WRITE_HOSTS";
		return;
	}


	##  Set up READ host
	_debug("Loading READ_HOSTS for $hostname: '" . join("','",@{$cluster->{'READ_HOSTS'}}), "'");

	$start_point = int(rand($#{$cluster->{'READ_HOSTS'}} + 1));
	for (0 .. $#{$cluster->{'READ_HOSTS'}}){
		my $read_host = @{$cluster->{'READ_HOSTS'}}[$start_point];
		_debug("Trying $read_host...");

		if ($read_host eq $write_host){
			$read_dbh = $write_dbh;
			_debug("This one is good and is used for writing - will use for reading too");
			last;
		}

		my $new_dsn = _rebuild_dsn($dsn,$hostname,$read_host);
		$read_dbh = DBI->connect($new_dsn, $user, $pass, $attr, $old_driver);
		if ($read_dbh){
			_debug("Looks good - will use this one for reading");
			last;
		}

		_debug("$read_host is no good");
		$start_point++;
		$start_point = 0 if $start_point > $#{$cluster->{'READ_HOSTS'}};
	}

	unless ($read_dbh){
		carp "Could not connect to any server in READ_HOSTS";
		return;
	}


	my $read_value = $#{$cluster->{'READ_HOSTS'}} + 1;
	my $write_value = $#{$cluster->{'WRITE_HOSTS'}} + 1;

	_debug("Effective RW_RATIO set to ${read_value}:${write_value}");
	_debug("Database handler created");

	if ($write_dbh->{AutoCommit} != $read_dbh->{AutoCommit}){
		carp "READ and WRITE databases have different default AutoCommit value - set AutoCommit explicitly diring connect statement";
	}

	my @tables;
	foreach ($write_dbh->tables(undef,undef,undef,undef)){
		$_ =~ s/\.//g;
		push @tables, $_ if $_;
	}

	my $self = bless ( {}, __PACKAGE__ . "::db" );


	$PRIVATE{$self} = {
		ALL_TABLES	=> \@tables,
		LAST_ACTIVE	=> 'WRITE_DBH',
		MOD_TABLES	=> {},
		ORIG_ARGS		=> \@orig_args,
		QUERY_STATE	=> 'NORMAL',
		READ_COUNT	=> 0,
		READ_DBH 		=> $read_dbh,
		RW_RATIO		=> ($read_value / $write_value),
		WRITE_COUNT	=> 0,
		WRITE_DBH		=> $write_dbh,
	};

	return $self;
}


sub _debug {
	my $message = shift;           	
	print STDERR __PACKAGE__ . "  $message\n" if $DBIx::DBCluster::DEBUG;
}


sub _get_hostname {
	my $driver_args = (split(':', shift))[2];


	return '' unless $driver_args;

	$driver_args =~ /^.+\@((.+))$/;
	return $2 if $2;
#	$driver_args =~ /^.+\@(.+)$/;
#	if ($1){ return $1 } ;

# For some strange resaon $1 ALWAYS contains programname (like $0) under some scripts
# Coulndt figure out why, so came up with the above ugly little hack.
#	$driver_args =~ /^.+\@(.+)$/;
#	return $1 if $1;



	$driver_args =~ /host=([^;]+)/;
	return $1 if $1;

	croak "Could not extract hostname from DSN; non-ODBC compliant DSN format?";
}


sub _rebuild_dsn {
	my ($dsn,$cluster_name,$hostname) = @_;

	my ($dbi,$driver,$driver_args) = split(':',$dsn);
	if ($driver_args =~ m/^.+\@$cluster_name$/){
		$driver_args =~ s/\@$cluster_name$/\@$hostname/;
		return "$dbi:$driver:$driver_args";

	} elsif ($driver_args =~ m/host=$cluster_name/){
		$driver_args =~ s/host=$cluster_name/host=$hostname/;
		return "$dbi:$driver:$driver_args";

	}
	croak "Could not rebuild DSN with modified hostname; non-ODBC compliant DSN format?";
}


sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) || return;

	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	if (@_){
		return DBI->$name(@_);
	} else {
		return DBI->$name;
	}
}


sub DESTROY {}


######################################################################

package DBIx::DBCluster::db;

use Carp;

our $AUTOLOAD;


sub begin_work {
	my $self = shift;
	return $self->_transaction_method('begin_work','TRANSACTION_SELECT');
}


sub commit {
	my $self = shift;
	return $self->_transaction_method('commit','NORMAL');
}


sub clone {
	my ($old_dbh, $attr) = @_;

	_debug("Trying to create a clone");

	my @new_args = @{$PRIVATE{$old_dbh}->{ORIG_ARGS}};
	push @new_args, $attr if $attr;

	return DBIx::DBCluster->connect(@new_args);
}


sub do {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('do', $sql, @_);
}


sub prepare {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('prepare', $sql, @_);
}


sub prepare_cached {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('prepare_cached', $sql, @_);
}


sub rollback {
	my $self = shift;
	return $self->_transaction_method('rollback','NORMAL');
}


sub selectall_arrayref {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('selectall_arrayref', $sql, @_);
}


sub selectcol_arrayref {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('selectcol_arrayref', $sql, @_);
}


sub selectrow_array {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('selectrow_array', $sql, @_);
}


sub selectrow_arrayref {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('selectrow_arrayref', $sql, @_);
}


sub selectrow_hashref {
	my $self = shift;
	my $sql = shift;
	return $self->_query_method('selectrow_hashref', $sql, @_);
}


sub _choose_server {
	my $self = shift;
	my $param = shift || '';

	my $vars = $PRIVATE{$self};

	if ($param eq 'READ_DBH'){
		$vars->{READ_COUNT} ++;
		return $vars->{LAST_ACTIVE} = 'READ_DBH';

	} elsif ($param eq 'WRITE_DBH'){
		$vars->{WRITE_COUNT} ++;
		return $vars->{LAST_ACTIVE} = 'WRITE_DBH';
	}

	unless ($vars->{READ_COUNT}){
		$vars->{READ_COUNT} = 1;
		return $vars->{LAST_ACTIVE} = 'READ_DBH';
	}

	unless ($vars->{WRITE_COUNT}){
		$vars->{WRITE_COUNT} = 1;
		return $vars->{LAST_ACTIVE} = 'WRITE_DBH';
	}

	if ( ($vars->{READ_COUNT} / $vars->{WRITE_COUNT}) < $vars->{RW_RATIO} ){
		$vars->{READ_COUNT} ++;
		return $vars->{LAST_ACTIVE} = 'READ_DBH';

	} else {
		$vars->{WRITE_COUNT} ++;
		return $vars->{LAST_ACTIVE} = 'WRITE_DBH';
	}
}


sub _compare_tables_used {
	my $self = shift;
	my $sql = shift;

	foreach ($self->_get_tables_used($sql)){
		return 1 if $PRIVATE{$self}->{MOD_TABLES}->{$_};
	}

	return 0;
}


sub _debug {
	my $message = shift;
	print STDERR __PACKAGE__ . "  $message\n" if $DBIx::DBCluster::DEBUG;
}


sub _dumper {
	my $self = shift;
	return $PRIVATE{$self};
}


sub _get_tables_used {
	my $self = shift;
	my $sql = shift;

	my %tables;
	for (@{$PRIVATE{$self}->{ALL_TABLES}}){
		$tables{$_} = 1 if $sql =~ m/\b$_\b/ig;
	}

	return keys %tables;
}


sub _is_write_statement {
	my $sql = shift;

	for (@WRITE_COMMANDS){
		return 1 if $sql =~ m/\b$_\b/ig;
	}

	return;
}


sub _query_method {
	my $self = shift;
	my $command = shift;
	my $sql = shift;

	_debug("Issuing '$command' on the following sql: $sql");

	if ($PRIVATE{$self}->{WRITE_DBH}->{AutoCommit} == 0 && $PRIVATE{$self}->{QUERY_STATE} eq 'NORMAL'){
		$PRIVATE{$self}->{QUERY_STATE} = 'TRANSACTION_SELECT';
	}

	my $result;
	if (_is_write_statement($sql)){
		foreach ($self->_get_tables_used($sql)){
			$PRIVATE{$self}->{MOD_TABLES}->{$_} = 1;
		}

		my $server = $self->_choose_server('WRITE_DBH');

		_debug("Statement directed to $server");

		$PRIVATE{$self}->{QUERY_STATE} = 'TRANSACTION_WRITE' if $PRIVATE{$self}->{QUERY_STATE} eq 'TRANSACTION_SELECT';

		$result = $PRIVATE{$self}->{$server}->$command($sql, @_);

	} else {
		my $selection;
		if ($PRIVATE{$self}->{QUERY_STATE} eq 'TRANSACTION_WRITE' || $self->_compare_tables_used($sql)){
			$selection = 'WRITE_DBH';
		} else {
			$selection = ($WRITE_HOSTS_NEVER_READ)?'READ_DBH':'AUTO';
		}

		my $server = $self->_choose_server($selection);

		_debug("Read Statement directed to $server");

		$result = $PRIVATE{$self}->{$server}->$command($sql, @_);
	}

	if ($sql =~ m/\b(create|alter|drop)\b/ig){
		my @tables;
		foreach ($PRIVATE{$self}->{WRITE_DBH}->tables(undef,undef,undef,undef)){
			$_ =~ s/\.//g;
			push @tables, $_ if $_;
		}

		$PRIVATE{$self}->{ALL_TABLES} = \@tables;

		foreach ($self->_get_tables_used($sql)){
			$PRIVATE{$self}->{MOD_TABLES}->{$_} = 1;
		}
	}

	return $result;
}


sub _transaction_method {
	my $self = shift;
	my ($command, $state) = @_;
	my $vars = $PRIVATE{$self};

	$vars->{MOD_TABLES} = {};

	$vars->{WRITE_DBH}->$command;
	$vars->{READ_DBH}->$command unless $vars->{WRITE_DBH} == $vars->{READ_DBH};

	if ($vars->{WRITE_DBH}->err){
		$vars->{LAST_ACTIVE} = 'WRITE_DBH';
		carp $vars->{WRITE_DBH}->err;
	}

	if ($vars->{READ_DBH}->err){
		$vars->{LAST_ACTIVE} = 'READ_DBH';
		carp $vars->{READ_DBH}->err;
	}

	$vars->{QUERY_STATE} = $state;

	return 1;
}


sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) || return;

	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	my $vars = $PRIVATE{$self};

	if (exists $vars->{$vars->{LAST_ACTIVE}}->{$name} && @_){
		my $r_1 = $vars->{READ_DBH}->{$name} = @_;
		my $r_2 = $vars->{WRITE_DBH}->{$name} = @_;
		return (defined $r_1 && defined $r_2 ? $r_1 : undef);

	} elsif (exists $vars->{$vars->{LAST_ACTIVE}}->{$name}){
		return $vars->{$vars->{LAST_ACTIVE}}->{$name};

	} elsif (@_){
		my $r_1 = $vars->{READ_DBH}->$name(@_);
		my $r_2 = $vars->{WRITE_DBH}->$name(@_);
		return (defined $r_1 && defined $r_2 ? $r_1 : undef);

	} else {
		return $vars->{$vars->{LAST_ACTIVE}}->$name;
	}
}

sub DESTROY {
	my $self = shift;
	delete $PRIVATE{$self};
}

######################################################################

1;

__END__

=head1 NAME

DBIx::DBCluster - Distribute load among mirrored database servers

=head1 VERSION

This document describes version 0.01 of DBIx::DBCluster,
released June 17, 2003.

=head1 STATUS

This module is currently being tested in development environment and should
be considered beta code.

=head1 SYNOPSIS

     use DBIx::DBCluster;

     my $dbh = DBIx::DBCluster->connect($data_source, $username, $auth, \%attr);

=head1 BACKGROUND

=head2 The problem

The idea of having multiple database servers that mirror the same database
seems fairly simple. Most modern databases provide built-in tools and mechanisms
for seamless, virtually instant automatic replication. If you're not trying to
just back up your primary database, but actually use all your mirrors in
production trying to achieve load balancing -- you will face the
challenge of maintaining data integrity. Somewhere, you will need a mechanism
that could filter your requests to the database and decide whether it is safe
to direct specific request to any available server, or to a specific one.

=head2 The solution

Since most perl-based applications use DBI module for interacting with databases,
a wrapper around DBI's database handler seemed to be the right place to implement
the logic. It also requires bare minimum of changes to your existing code.

=head1 DESCRIPTION

C<DBIx::DBCluster> creates a database handler object that acts like, and has exactly
the same properties and methods as DBI's database handler. In the background it creates
multiple database connections to mirrored database servers. Acts as an
application level load balancer.

It is assumed that you have a cluster of database servers set up with one-way
or two-way replication. Load balancing in two-way replication set-up is
comparatively simple since you can both read and write to any server. This
module is designed primarily for one-way replication set-up. In the latter case
you can write only to the master server and read from any read-only slave server.
Since the number of reads usually dominates anyway, there is a real advantage to
having multiple read-only servers and deligate most read requests to them.

This database handler object creates two transparent database connections - one
designated for modifying statements, the other one for non-modifying statements.
Any statement you issue is analyzed and directed to one server or the other.
Servers are randomly picked from the list you pre-define.

In order to utilize multiple connection capabilities you need to define a 
server cluster. Each cluster has (1) a list of servers that can be used for
modifying statements, i.e. WRITE_SERVERS, and (2) a list of servers that can be used
for non-modifying statements, i.e. READ_SERVERS.

=head1 METHODS AND ATTRIBUTES

=over

=item connect

This method takes the same arguments as C<DBI-E<gt>connect()> method. A special note about
$data_source argument or DSN. In order to utilize load balancing capabilities
your DSN should (1) explicitly specify hostname and (2) be ODBC compliant, i.e be in
one of the following formats:

    dbi:DriverName:database_name@hostname:port
    dbi:DriverName:database=database_name;host=hostname;port=port


The hostname will be extracted from the DSN and analyzed. If you have a cluster
with the same label configured - your cluster configuration will override actual
hostname when establishing database connection(s). For that matter the C<hostname>
portion of your DSN doesn't even have to be a valid hostname - it can be just a
label of your cluster. If your hostname doesn't correspond with one of the
pre-defined cluster labels though, it will be treated as a real hostname and the
module will try to connect to it. No load balancing will happen in the latter case.

=back

All other methods and attributes are inherited from DBI's database handler. See
documentation for DBI package, section "DBI DATABASE HANDLE OBJECTS".

=head1 CONFIGURATION VARIABLES

Any of the variables below can be set explicitly in your script or placed
in a configuration file and loaded via C<require>. By default, configuration
data is pulled from C<DBIx::DBCluster::Config> module. Feel free to edit
this file directly if you need to set up universal configuration.

=over

=item $DBIx::DBCluster::CLUSTERS

This is a hashref that defines your clusters. This variable I<must> be defined somewhere
or you will not have load balancing. Here's the format:

    $DBIx::DBCluster::CLUSTERS = {
        'cluster_label'  => {
            'WRITE_HOSTS'  => ['db1.mydomain.com'],
            'READ_HOSTS'   => ['db2.mydomain.com','db3.mydomain.com','db4.mydomain.com'],
        },
    };

=item @DBIx::DBCluster::WRITE_COMMANDS

An array of SQL keywords that will denote your statement as modifying or write statement.
You probably won't have to modify this, but you can if you need to. The difault is:

    @DBIx::DBCluster::WRITE_COMMANDS = qw( ALTER CREATE DELETE DROP INSERT LOCK RENAME REPLACE SET TRUNCATE UNLOCK UPDATE );

=item $DBIx::DBCluster::DEBUG

When set to true debug infromation is printed to STDERR.

=back

=head1 EXAMPLES

Traditionally you would use DBI in way similar to

    use DBI;

    my $dbh = DBI->connect('DBI:mysql:test@db1.mydomain.com:3306', 'testuser', 'testpassword');

    my $sth = $dbh->prepare('select * from test');
    $sth->execute;
    while (my $data = $sth->fetchrow_hashref){
        ##  do something with $data
    }

In a cluster set-up you would need to replace the top two lines. Instead of

    use DBI;

    my $dbh = DBI->connect('DBI:mysql:test@db1.mydomain.com:3306', 'testuser', 'testpassword');

you will have

    use DBIx::DBCluster;

    my $dbh = DBIx::DBCluster->connect('DBI:mysql:test@db1.mydomain.com:3306', 'testuser', 'testpassword');

The rest of your code needs no modifications. It is recommended that you put all your cluster definitions
in DBIx::DBCluster::Config module so that you don't have to define clusters in every script. Alternatively,
you can put your definitions in a central file, say Config.pl and load it up with C<require>:

    use DBIx::DBCluster;
    require "/path/to/config_file/Config.pl";

    my $dbh = DBIx::DBCluster->connect('DBI:mysql:test@db1.mydomain.com:3306', 'testuser', 'testpassword');

Yet another way to define your clusters is to do so explicitly in your script

    use DBIx::DBCluster;

    $DBIx::DBCluster::CLUSTERS = {
        'db1.mydomain.com'  => {
            'WRITE_HOSTS'  => ['db1.mydomain.com'],
            'READ_HOSTS'   => ['db2.mydomain.com','db3.mydomain.com','db4.mydomain.com'],
        },
    };

    my $dbh = DBIx::DBCluster->connect('DBI:mysql:test@db1.mydomain.com:3306', 'testuser', 'testpassword');


=head1 AUTHOR

Alex Rak B<arak@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2003 Alex Rak.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

The DBI module

=cut
