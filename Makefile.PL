use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'P4',
    'VERSION_FROM'	=> 'P4.pm', # finds $VERSION
    'PREREQ_PM'		=> { 'P4::Client'	=> "1.1084" }, 
    'ABSTRACT'		=> "OO interface to the Perforce SCM system",
    'AUTHOR'		=> "Tony Smith <tony\@perforce.com>",
    
);
