package BalancedBayes::Vendor::MailCleaner 0.001;
use strict;
use warnings;

use base "BalancedBayes::Vendor";

sub defaults {
	my ($this) = @_;
	$this->{rootdir} = '/var/MailCleaner/BalancedBayes';
	$this->{sender} = 'root@gate-pp1.maillcleaner.net';
	$this->{recipient} = 'support@mailcleaner.net';
	$this->{smtp_server} = 'localhost:2525';
}

1;
