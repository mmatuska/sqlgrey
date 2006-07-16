use Test::Simple tests => 7;
use DBIx::DBCluster;
use Data::Dumper;

$DBIx::DBCluster::DEBUG = 0;


my $dbh = DBIx::DBCluster->connect('dbi:ExampleP:test@ExampleP', '', '', { PrintError => 0 });
ok( $dbh, 'Cluster initiated');


my $vars = $dbh->_dumper;

my $read_dbh = $vars->{READ_DBH};
ok( $read_dbh && ref($read_dbh) eq 'DBI::db' && $read_dbh->ping, 'Read handler is good' );

my $write_dbh = $vars->{WRITE_DBH};
ok( $write_dbh && ref($write_dbh) eq 'DBI::db' && $write_dbh->ping, 'Write handler is good' );


## Issue 14 statements
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("insert whatever");

$dbh->do("insert whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");

$vars = $dbh->_dumper;
ok( $vars->{READ_COUNT} == 10 && $vars->{WRITE_COUNT} == 4, 'Simple statements are good' );


$dbh->begin_work;
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");

$vars = $dbh->_dumper;
ok( $vars->{READ_COUNT} == 15 && $vars->{WRITE_COUNT} == 6, 'Transactions phase 1 is good' );


$dbh->do("insert whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("insert whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");

$vars = $dbh->_dumper;
ok( $vars->{READ_COUNT} == 15 && $vars->{WRITE_COUNT} == 13, 'Transactions phase 2 is good' );


$dbh->commit;
$dbh->do("insert whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");
$dbh->do("insert whatever");
$dbh->do("select whatever");
$dbh->do("select whatever");

$vars = $dbh->_dumper;
ok( $vars->{READ_COUNT} == 20 && $vars->{WRITE_COUNT} == 15, 'Transactions phase 3 is good' );


