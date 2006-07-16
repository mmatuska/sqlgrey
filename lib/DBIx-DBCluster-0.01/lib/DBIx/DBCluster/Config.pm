package DBIx::DBCluster::Config;

our $VERSION = "0.01";

$DBIx::DBCluster::CLUSTERS = {
	'ExampleP'	=> {
		'WRITE_HOSTS'	=> ['host1','host2'],
		'READ_HOSTS'	=> ['host3','host4','host5','host6','host7'],
	},
};

@DBIx::DBCluster::WRITE_COMMANDS = qw( ALTER CREATE DELETE DROP INSERT LOCK RENAME REPLACE SET TRUNCATE UNLOCK UPDATE );
