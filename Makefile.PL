use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'BalancedBayes',
	VERSION_FROM => 'lib/BalancedBayes.pm',
	AUTHOR => 'John Mertz',
	PREREQ_PM => {
		'File::MimeInfo' => '0.35',
		'File::Slurp' => '9999.14',
		'MIME::Entity' => '5.515',
		'Net::SMTP' => '3.15',
		'Lingua::Identify::Any' => '0.002',
	}
);
