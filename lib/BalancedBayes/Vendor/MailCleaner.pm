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

  Also depends on File::Copy::move for OS compatible moving of files and IPC::Run::run for the safe
  running of system commands.

=cut

use strict;
use warnings;

use base "BalancedBayes::Vendor";
use File::Copy qw( move );
use IPC::Run qw( run );

=head1 GLOBALS

Global variables used by this vendor. Mostly related to paths.

=cut

our $QUEUE = 'queue';
our $DONE = 'done';
our $FPDIR = 'fp';
our $FNDIR = 'fn';
our $TPDIR = 'tp';
our $TNDIR = 'tn';

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
	mkdir "$this->{rootdir}/$QUEUE" unless ( -e "$this->{rootdir}/$QUEUE" );
	mkdir "$this->{rootdir}/$DONE" unless ( -e "$this->{rootdir}/$DONE" );
}

=head2 validate_vendor

Verify that the working message was previously scanned by MailCleaner.

=cut

sub validate_vendor {
	my $this = shift;
	my $msg = shift;
	return 1 if (defined($msg->{headers}->{'X-MailCleaner'}));
	return 0;
}

=head2 validate_spam

Verify that the working message was actually detected as a spam previously by MailCleaner.

=cut

sub validate_spam {
	my $this = shift;
	my $msg = shift;
	return 1 if ($this->detect_nicebayes($msg) || $this->detect_bogospam($msg));
	return 0;
}

=head2 validate_ham

Verify that the working message was not detected as a spam previously by MailCleaner.

=cut

sub validate_ham {
	my $this = shift;
	my $msg = shift;
	return 1 unless ($this->detect_nicebayes($msg) || $this->detect_bogospam($msg));
	return 0;
}

=head2 detect_nicebayes

Verify that the working message was actually detected as a spam by NiceBayes.

=cut

sub detect_nicebayes {
	my $this = shift;
	my $msg = shift;
	return 0 unless defined($msg->{headers}->{'X-MailCleaner-SpamCheck'});
	my $spamcheck = $msg->{'headers'}->{'X-MailCleaner-SpamCheck'};
	$spamcheck =~ s/\n//g;
	$spamcheck =~ s/\s\s+/ /g;
	return 0 unless $spamcheck =~ m/NiceBayes \([^\)]+, spam decisive/g;
	return 1;
}

=head2 detect_bogospam

Verify that the working message was actually detected as a spam by Bogospam.

=cut

sub detect_bogospam {
	my $this = shift;
	my $msg = shift;
	return 0 unless defined($msg->{headers}->{'X-MailCleaner-SpamCheck'});
	my $spamcheck = $msg->{'headers'}->{'X-MailCleaner-SpamCheck'};
	$spamcheck =~ s/\n//g;
	$spamcheck =~ s/\s\s+/ /g;
	return 0 unless $spamcheck =~ m/Spamc \([^\)]*BAYES_[5-9][0-9]/;
	return 1;
}

=head2 false_positive

Add item to false positive queue.

=cut 

sub false_positive {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	mkdir "$this->{rootdir}/$QUEUE/$lang" unless ( -e "$this->{rootdir}/$QUEUE/$lang" );
	mkdir "$this->{rootdir}/$QUEUE/$lang/$FPDIR" unless ( -e "$this->{rootdir}/$QUEUE/$lang/$FPDIR" );
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/$QUEUE/$lang/$FPDIR/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/$QUEUE/$lang/$FPDIR/$basename: $!\n";
	return "$this->{rootdir}/$QUEUE/$lang/$FPDIR/$basename";
}

=head2 false_negative

Add item to false negative queue.

=cut 

sub false_negative {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	mkdir "$this->{rootdir}/$QUEUE/$lang" unless ( -e "$this->{rootdir}/$QUEUE/$lang" );
	mkdir "$this->{rootdir}/$QUEUE/$lang/$FNDIR" unless ( -e "$this->{rootdir}/$QUEUE/$lang/$FNDIR" );
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/$QUEUE/$lang/$FNDIR/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/$QUEUE/$lang/$FNDIR/$basename: $!\n";
	return "$this->{rootdir}/$QUEUE/$lang/$FNDIR/$basename";
}

=head2 true_positive

Add item to true positive queue.

=cut 

sub true_positive {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	mkdir "$this->{rootdir}/$QUEUE/$lang" unless ( -e "$this->{rootdir}/$QUEUE/$lang" );
	mkdir "$this->{rootdir}/$QUEUE/$lang/$TPDIR" unless ( -e "$this->{rootdir}/$QUEUE/$lang/$TPDIR" );
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/$QUEUE/$lang/$TPDIR/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/$QUEUE/$lang/$TPDIR/$basename: $!\n";
	return "$this->{rootdir}/$QUEUE/$lang/$TPDIR/$basename";
}

=head2 true_negative

Add item to true negative queue.

=cut 

sub true_negative {
	my $this = shift;
	my $msg = shift;
	my $msg_path = shift;
	my $lang = shift;
	mkdir "$this->{rootdir}/$QUEUE/$lang" unless ( -e "$this->{rootdir}/$QUEUE/$lang" );
	mkdir "$this->{rootdir}/$QUEUE/$lang/$TNDIR" unless ( -e "$this->{rootdir}/$QUEUE/$lang/$TNDIR" );
	my ($basename) = $msg_path =~ m#.*/([^/]*)$#;
	move($msg_path, "$this->{rootdir}/$QUEUE/$lang/$TNDIR/$basename")
		|| die "Failed to move $msg_path to $this->{rootdir}/$QUEUE/$lang/$TNDIR/$basename: $!\n";
	return "$this->{rootdir}/$QUEUE/$lang/$TNDIR/$basename";
}

=head2 train_ham

Train as Ham for NiceBayes and SpamC databases.

=cut 

sub train_ham {
	my $this = shift;
	my $msg_path = shift;
	run("/opt/bogofilter/bin/bogofilter", "-c", "/usr/mailcleaner/etc/mailscanner/prefilters/bogo_nicebayes.cf", "-n", "-I", "$msg_path");
	return 0 if ($?);
	run("/usr/local/bin/sa-learn", "-p", "/usr/mailcleaner/etc/mailscanner/spam.assassin.prefs.conf", "--ham", "$msg_path");
	return 0 if ($?);
	return 1;
}

=head2 train_spam

Train as Spam for NiceBayes and SpamC databases.

=cut 

sub train_spam {
	my $this = shift;
	my $msg_path = shift;
	run("/opt/bogofilter/bin/bogofilter", "-c", "/usr/mailcleaner/etc/mailscanner/prefilters/bogo_nicebayes.cf", "-s", "-I", "$msg_path");
	return 0 if ($?);
	run("/usr/local/bin/sa-learn", "-p", "/usr/mailcleaner/etc/mailscanner/spam.assassin.prefs.conf", "--spam", "$msg_path");
	return 0 if ($?);
	return 1;
}

=head2 sweep

Moves input file to completed directory.

=cut

sub sweep {
	my $this = shift;
	my $msg_path = shift;
	my ($out_path) = $msg_path =~ m#.*/([^/]*)$#;
	$out_path = "$this->{rootdir}/$DONE/$out_path";
	move($msg_path, $out_path) || die "Failed to move $msg_path to $out_path: $!\n";
}

1;
	
