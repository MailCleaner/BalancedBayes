#!/usr/bin/perl

use strict;
use warnings;

use BalancedBayes;

my $bb = BalancedBayes->new( vendor => "MailCleaner" );
if (scalar(@ARGV)) {
	my $address = shift;
	die "$address is not a valid address.\n" unless ($address =~ m/([^\s@]+@[^\s@]+\.[^\s@]+|1|default)$/);
	$bb->queue_report($address);
} else {
	$bb->queue_report;
}
