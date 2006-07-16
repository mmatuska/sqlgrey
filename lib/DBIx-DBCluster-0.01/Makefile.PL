use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'DBIx::DBCluster',
    'VERSION_FROM'	=> 'DBCluster.pm',
    'PREREQ_PM'	=> { DBI => 1.37 },
    ($] >= 5.005 ?
      (ABSTRACT_FROM	=> 'DBCluster.pm',
       AUTHOR			=> 'Alex Rak <arak@storesonline.com>') : ()),
);
