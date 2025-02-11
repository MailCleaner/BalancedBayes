package BalancedBayes::Vendor::Stub 0.001;
use strict;
use warnings;

use base "BalancedBayes::Vendor";

sub defaults {
	my ($this) = @_;
	$this->{rootdir} = '/tmp/BalancedBayes';
	$this->{sender} = 'root@localhost';
	$this->{recipient} = 'root@localhost';
	$this->{smtp_server} = 'localhost:25';
}

1;
