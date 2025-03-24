#!/usr/bin/perl
# This excutable should be used to add a message to the relevant Balanced Bayes queue. See usage.

use strict;
use warnings;
use BalancedBayes;

sub usage {
	my $error = shift;
	print "$error\n" if $error;
	print "usage: $0 <file_path> [FP|FN|TP|TN] --process\n\n";
	print "file_path\tactual path to input email file\n";
	print "FP\t\ttreat message as a False-Positive\n\t\t(item which should have been treated as Ham but was detected as Spam).\n";
	print "FN\t\ttreat message as a False-Negative\n\t\t(item which should have been treated as Spam but was detected as Ham).\n";
	print "TP\t\ttreat message as a True-Positive\n\t\t(item which should have been treated as Spam and was).\n";
	print "TN\t\ttreat message as a True-Negative\n\t\t(item which should have been treated as Ham and was).\n";
	print "--process\tstart a processing run for queued messages once this message is added. Otherwise, just run process_bayes.pl afterwards\n";
	exit shift;
}

my ($file, $type, $process, $excess) = @ARGV;
usage("Missing required message path argument.\n", 1) unless defined($file);
usage("", 0) if $file =~ m/^-?-?h(elp)?$/;
usage("Provided message path argument $file not found\n", 1) unless -e $file;
usage("Missing required spam/ham type argument\n", 1) unless defined($type);
usage("Invalid spam/ham type argument\n", 1) unless $type =~ m/^[FT][PN]$/;
usage("Invalid argument $process", 1) if (defined($process) && $process ne '--process');
usage("Excess argument $excess", 1) if defined($excess);

my $bb = BalancedBayes->new( vendor => 'MailCleaner' );
$bb->load_message($file) || die "Could not open file $file\n";
if ($type =~ m/^F/) {
	my $mc = $bb->validate_vendor();
	unless ($mc) {
		$type = 'TP' if ($type eq 'FN');
		$type = 'FN' if ($type eq 'TP');
	}
	if ($type =~ m/P$/) {
		$bb->validate_spam() || die "Not originally treaded as spam\n";
	} else {
		$bb->validate_ham() || die "Originally treated as spam\n";
	}
}

my $queue_path;
if ($type eq 'FP') {
	$queue_path = $bb->false_positive();
	$bb->train_fp($queue_path) if (defined($process));
} elsif ($type eq 'FN') {
	$queue_path = $bb->false_negative();
	$bb->train_fn($queue_path) if (defined($process));
} elsif ($type eq 'TP') {
	$queue_path = $bb->true_positive();
	$bb->train_tp($queue_path) if (defined($process));
} else {
	$queue_path = $bb->true_negative();
	$bb->train_tn($queue_path) if (defined($process));
}
