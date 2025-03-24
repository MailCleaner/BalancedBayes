=head1 NAME

BalancedBayes::Vendor::Stub - Example vendor module

=cut

package BalancedBayes::Vendor::Stub 0.001;

=head1 DESCRIPTION

This module provides stubs for all necessary methods to implement a new BalancedBayes vendor.
Stub.

=head1 EXPORT

None by default. Initialize a BalancedBayes object with C<new> and the vendor, then access
these functions by calling them as methods to the BalancedBayes object.

=head1 SYNOPSIS

  # Import Stub vendor configuration when initializing BalancedBayes object
  my $bb = BalancedBayes->new( vendor => 'Stub' );

=head1 DEPENDENCIES

  Depends on BalancedBayes::Vendor base module.
  File::Copy::move used for OS compatibility in this example.

=cut

use strict;
use warnings;

use base "BalancedBayes::Vendor";
use File::Copy qw( move );

=head1 METHODS

=head2 defaults

Load default settings for Stub vendor.

=cut

sub defaults {
	my ($this) = @_;
	$this->{rootdir} = '/var/Stub/BalancedBayes';   # Base directory for storing messages and DB
	$this->{sender} = 'root@localhost';             # Sender address for reporting function
	$this->{recipient} = 'support@mailcleaner.net'; # Default recipient for reports
	$this->{smtp_server} = 'localhost:2525';        # SMTP server for reports
}

=head2 validate_vendor

Verify that the working message was previously scanned by Stub.

=cut

sub validate_vendor {
	my $this = shift;
	my $msg = shift;
	# Provide some method of detecting whether the provided message actually used this vendor,
	# such as checking a header
	return 1 if (defined($msg->{headers}->{'X-Stub'}));
	return 0;
}

=head2 validate_spam

Verify that the working message was actually detected as a spam previously by Stub.

=cut

sub validate_spam {
	my $this = shift;
	my $msg = shift;
	# Provide some method to detect if this vendor had actually determined the message to be
	# spam, such as checking a header
	return 1 if ($msg->{headers}->{'X-Stub'} =~ m/Found spam/);
	return 0;
}

=head2 validate_ham

Verify that the working message was not detected as a spam previously by Stub.

=cut

sub validate_ham {
	my $this = shift;
	my $msg = shift;
	# Provide some method to detect if this vendor did not determine the message to be spam,
	# such as checking a header
	return 1 if ($msg->{headers}->{'X-Stub'} =~ m/Found ham/);
	return 0;
}

=head2 false_positive

Add item to false positive queue.

=cut 

sub false_positive {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	# Move the item to the false-positive queue.
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/queue/$lang/fp/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/queue/$lang/fp/$basename: $!\n";
	# Return the updated message path
	return "$this->{rootdir}/queue/$lang/fp/$basename";
}

=head2 false_negative

Add item to false negative queue.

=cut 

sub false_negative {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	# Move the item to the false-negative queue.
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/queue/$lang/fn/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/queue/$lang/fn/$basename: $!\n";
	# Return the updated message path
	return "$this->{rootdir}/queue/$lang/fn/$basename";
}

=head2 true_positive

Add item to true positive queue.

=cut 

sub true_positive {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	# Move the item to the true-positive queue.
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/queue/$lang/tp/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/queue/$lang/tp/$basename: $!\n";
	# Return the updated message path
	return "$this->{rootdir}/queue/$lang/tp/$basename";
}

=head2 true_negative

Add item to true negative queue.

=cut 

sub true_negative {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	# Move the item to the true-negative queue.
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/queue/$lang/tn/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/queue/$lang/tn/$basename: $!\n";
	# Return the updated message path
	return "$this->{rootdir}/queue/$lang/tn/$basename";
}

=head2 train_ham

Train as Ham for NiceBayes and SpamC databases.

=cut 

sub train_ham {
	my $this = shift;
	my $msg_path = shift;
	# Perform the actual action to train the message as Ham in the bayes database
	run("/usr/local/bin/sa-learn", "-p", "/etc/spam.assassin.prefs.conf", "--ham", "$msg_path");
	return 0 if ($?);
	return 1;
}

=head2 train_spam

Train as Spam for NiceBayes and SpamC databases.

=cut 

sub train_spam {
	my $this = shift;
	my $msg_path = shift;
	# Perform the actual action to train the message as Ham in the bayes database
	run("/usr/local/bin/sa-learn", "-p", "/etc/spam.assassin.prefs.conf", "--spam", "$msg_path");
	return 0 if ($?);
	return 1;
}

=head2 sweep

Moves input file to completed directory.

=cut

sub sweep {
	my $this = shift;
	my $msg_path = shift;
	# Move the completed message to a final directory, or delete it.
	my ($out_path) = $msg_path =~ m#.*/([^/]*)$#;
	$out_path = "$this->{rootdir}/done/$out_path";
	move($msg_path, $out_path) || die "Failed to move $msg_path to $out_path: $!\n";
}

1;
