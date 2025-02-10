#!/usr/bin/perl
# This excutable should be used to add a message to the relevant Balanced Bayes queue. See usage.

use strict;
use warnings;

usage("Missing required message path argument\n", 1) unless (defined($ARGV[0]));
usage("", 0) if ($ARGV[0] =~ m/^-?-?h(elp)?$/);
usage("Provided message path argument $ARGV[0] not found\n", 1) unless (-e $ARGV[0]);
usage("Missing required spam/ham type argument\n", 1) unless (defined($ARGV[1]));
usage("Invalid spam/ham type argument\n", 1) unless ($ARGV[1] =~ m/^[FT][PN]$/);
usage("Invalid argument $ARGV[2]", 1) if (defined($ARGV[2]) && $ARGV[2] ne '--process');
usage("Excess argument $ARGV[2]", 1) if (defined($ARGV[3]));

sub usage {
	print( shift ."\n");
	print("usage: $0 <file_path> [FP|FN|TP|TN] --process\n\n");
	print("file_path\tactual path to input email file\n");
	print("FP\t\ttreat message as a False-Positive\n\t\t(item which should have been treated as Ham but was detected as Spam).\n");
	print("FN\t\ttreat message as a False-Negative\n\t\t(item which should have been treated as Spam but was detected as Ham).\n");
	print("TP\t\ttreat message as a True-Positive\n\t\t(item which should have been treated as Spam and was).\n");
	print("TN\t\ttreat message as a True-Negative\n\t\t(item which should have been treated as Ham and was).\n");
	print("--process\tstart a processing run for queued messages once this message is added. Otherwise, just run process_bayes.pl afterwards\n");
	exit( shift );
}

print "TODO: detect language, verify type (ie. FP must have NiceBayes/Bogo hit, FN must not), then place in appropriate queue"

if (defined($ARGV[2])) {
	print "TODO: optionally start queue run\n";
}
