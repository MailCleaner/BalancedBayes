#!/usr/bin/perl

use strict;
use warnings;

use BalancedBayes;

my $bb = BalancedBayes->new( vendor => 'MailCleaner' );
my $msgs = $bb->get_counts();

foreach my $lang (keys(%$msgs)) {
	foreach my $type (keys(%{$msgs->{$lang}})) {
		my $trained = 0;
		print "Processing $msgs->{$lang}->{$type}->{trainable} messages for $lang $type\n";
		while ($trained++ < $msgs->{$lang}->{$type}->{trainable} ) {
			if ($type eq 'fp') {
				$bb->train_fp($lang);
			} elsif ($type eq 'fn') {
				$bb->train_fn($lang);
			} elsif ($type eq 'tp') {
				$bb->train_tp($lang);
			} else {
				$bb->train_tn($lang);
			}
		}
	}
}
