=head1 NAME

BalancedBayes::Vendor::MailCleaner - Vender-specific settings and functions for MailCleaner

=cut

package BalancedBayes::Vendor::MailCleaner 0.001;

=head1 DESCRIPTION

This module provides vendor-specific settings and functions for use by BalancedBayes with
MailCleaner.

=head1 EXPORT

None by default. Initialize a BalancedBayes object with C<new> and the MailCleaner vendor and
access these functions by calling the exposed functions directly in that object.

You may have some legitimate reason export C<detect_nicebayes>, C<detect_bogospam>,
C<feed_nicebayes>, and C<feed_bogospam> within your script if you would like to train one
but not the other.

=head1 SYNOPSIS

  # Import MailCleaner vendor configuration when initializing BalancedBayes object
  my $bb = BalancedBayes->new( vendor => 'MailCleaner' );

=head1 DEPENDENCIES

  Depends on BalancedBayes::Vendor base module.

=cut

use strict;
use warnings;

use base "BalancedBayes::Vendor";

=head1 METHODS

=head2 defaults

Load default settings for MailCleaner vendor.

=cut

sub defaults {
	my ($this) = @_;
	$this->{rootdir} = '/var/MailCleaner/BalancedBayes';
	$this->{sender} = 'root@gate-pp1.maillcleaner.net';
	$this->{recipient} = 'support@mailcleaner.net';
	$this->{smtp_server} = 'localhost:2525';
}

=head2 validate_vendor

Verify that the working message was previously scanned by MailCleaner.

=cut

sub validate_vendor {
	my $this = shift;
	#TODO find X-MailCleaner header
	return 0;
	return 1;
}

=head2 validate_ham

Verify that the working message was actually detected as a ham previously by MailCleaner.

=cut

sub validate_ham {
	my $this = shift;
	return 0 if ($this->detect_nicebayes || $this->detect_bogospam);
	return 1;
}

=head2 validate_ham

Verify that the working message was actually detected as a spam previously by MailCleaner.

=cut

sub validate_spam {
	my $this = shift;
	return 1 if ($this->detect_nicebayes || $this->detect_bogospam);
	return 0;
}

=head2 detect_nicebayes

Verify that the working message was actually detected as a spam by NiceBayes.

=cut

sub detect_nicebayes {
	my $this = shift;
	my $raw = shift;
	#TODO find NiceBayes result in X-SpamCheck header
	$this->load_message($raw) if (defined($raw));
}

=head2 detect_bogospam

Verify that the working message was actually detected as a spam by Bogospam.

=cut

sub detect_bogospam {
	my $this = shift;
	my $raw = shift;
	#TODO find BAYES_* rules in SpamC results in X-SpamCheck header
	$this->load_message($raw) if (defined($raw));
}

1;
