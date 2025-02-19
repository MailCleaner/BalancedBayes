=head1 NAME

BalancedBayes - Tools for maintaining a Bayes DB with balanced training data

=cut

package BalancedBayes 0.001;

=head1 DESCRIPTION

This module provides tools to help you maintain a balanced Bayes training database.

It will maintain separate queues for 'False-Postives', 'False-Negatives', 'True-Positives' and
'True-Negatives', for each detected language. This should help to ensure that there is never a
disproportionate number of items of one disposition which could poison the filter.

The tool allows for vendor specific functions to be implemented in order to specify how to verify
and train messages for that product.

=head1 EXPORT

None by default. Initialize an object with C<new> and access all functions as methods.

=head1 SYNOPSIS

  # Load Module
  use BalancedBayes;

  # Initialize BalancedBayes object and import vendor configuration
  my $bb = BalancedBayes->new( vendor => 'MailCleaner' );

  # Load a message file
  $bb->load_message($eml_file);

  # Validate the message and feed to bayes. Here we adjust for a false-positive:
  die "$eml_file was not scranned by MailCleaner\n" unless $bb->validate_vendor();
  die "$eml_file was not detected as Spam" unless $bb->validate_spam();
  $bb->false_positive();

  # Run queues
  $bb->process_queues();

=head1 DEPENDENCIES

  Depends on CPAN distributions:

  Cwd
  File::MimeInfo
  File::Slurp

  See child modules for additional specific dependencies.

=cut

use strict;
use warnings;

use Cwd;
use File::MimeInfo;
use File::Slurp;

=head1 METHODS

=head2 new

Initialize an object.

  my $bb = Balanced::Bayes->new( vendor => 'MailCleaner' );

Vendor settings can also be included in argument hash to override defaults:

  my $bb = Balanced::Bayes->new( vendor => 'MailCleaner', rootdir => '/tmp/BalancedBayes' );

=cut 

sub new {
	my $class = shift || "BalancedBayes";
	my %args = @_;
	my $this = {
		'vendor' => $args{vendor} || "Stub"
	};
	delete($args{vendor}) if defined($args{vendor});
	bless($this, $class);
	$this->_load_vendor($this->{vendor});
	foreach my $key (keys(%args)) {
		$this->{vendor}->{$key} = $args{$key};
	}
	$this->{vendor}->{rootdir} =~ s|/$||;
	check_dir($class, $this->{vendor}->{rootdir});
	return $this;
}

=head2 _load_vendor

Internal function to import methods and settings from defined vendor.

=cut

sub _load_vendor {
	my ($this, $vendor) = @_;
	my $pkg = "BalancedBayes::Vendor::$vendor";
	eval "use $pkg";
	if ($@) {
		die("Unable to load Vendor package BalancedBayes::Vendor::$vendor : $@");
	}
	$this->{vendor} = $pkg->new($this);
	$this->{vendor}->defaults();
}

=head2 rootdir

Getter/setter for rootdir setting.

=cut

sub rootdir {
	my ($this, @args) = @_;
	return $this->{vendor}->rootdir(@args);
}

=head2 recipient

Getter/setter for email recipient setting.

=cut

sub recipient {
	my ($this, @args) = @_;
	return $this->{vendor}->recipient(@args);
}

=head2 sender

Getter/setter for email sender setting.

=cut

sub sender {
	my ($this, @args) = @_;
	return $this->{vendor}->sender(@args);
}

=head2 smtp_server

Getter/setter for email smtp_server setting.

=cut

sub smtp_server {
	my ($this, @args) = @_;
	return $this->{vendor}->smtp_server(@args);
}

=head2 load_message

Accepts a path to an email file and loads it in as the working message.

=cut

sub load_message {
	my $this = shift;
	my $raw = shift;

	$this->{msg} = $raw;
}

=head2 validate_vendor

Request passed to Vendor method. Returns true/false for whether the message should be processed for
that vendor. ie. Don't train MailCleaner with messages which were not already scanned previously
by MailCleaner.

Using this method is optional, but should be used for corrective training (ie. False-Positive/
False-Negative reports), not necessarily reinforcement training (ie. known Spam or Ham from
external sources).
 
=cut

sub validate_vendor {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->validate_vendor();
}

=head2 validate_ham

Request passed to Vendor method. Returns true/false for whether the message was previously detected
as spam by the vendor.

This should be used after C<validate_vendor> has been confirmed and is only necessary for corrective
training.

=cut

sub validate_ham {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->validate_spam();
}

=head2 validate_spam

Request passed to Vendor method. Returns true/false for whether the message was previously detected
as spam by the vendor.

This should be used after C<validate_vendor> has been confirmed and is only necessary for corrective
training.

=cut

sub validate_spam {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->validate_spam();
}

=head2 false_negative

Request passed to Vendor method. Add message to relevant False-Negative queue.

=cut

sub false_negavite {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->false_negative();
}

=head2 false_positive

Request passed to Vendor method. Add message to relevant True-Positive queue.

=cut

sub false_positive {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->false_positive();
}

=head2 true_negative

Request passed to Vendor method. Add message to relevant True-Negative queue.

=cut

sub true_negative {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->true_negative();
}

=head2 true_positive

Request passed to Vendor method. Add message to relevant True-Positive queue.

=cut

sub true_positive {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->true_positive();
}

=head2 check_dir

Verify that the queue directory (or others) exist and create it if it does not.

=cut

sub check_dir {
	my ($this, $dir) = @_;
	return 1 if ( -d $dir );
	die "$dir exists but is not a directory\n" if ( -e $dir );
	my $path = '';
	$dir =~ s/\~/$ENV{HOME}/;
	foreach my $part ( split('/', $dir)) {
		$path.=$part.'/';
		next if ($part eq '');
		$path = getcwd().'/'.$path if ($part ne ''  && $part.'/' eq $path);
		unless (-d $path) {
			mkdir($path) || die "Failed to create $path: $!\n";
		}
	}
}

=head2 queue_report

Generate a report with the number of items currently available in each queue and the number of
messages which can potentially be processed at this time as well as giving an indication of which
message types are needed to do additional training.

=cut

sub queue_report {
	my ($this, $email) = @_;
	$email = $this->{rcpt} if (defined($email) && $email =~ m/^(1|default)$/);

	my %langs = ();
	my $can_process = 0;

	my $report = "We have the following number of items in the queue for each language\n\n";
	foreach my $lang (glob($this->{rootdir}."/*")) {
		$lang =~ s|^.*/([^/]*)$|$1|;
		foreach my $type (glob($this->{rootdir}."/".$lang."/*")) {
			$type =~ s|^.*/([^/]*)$|$1|;
			my @files = glob($this->{rootdir}."/".$lang."/".$type."/*");
			$langs{$lang}{$type} = scalar(@files) if (scalar(@files));
		}
		if (scalar(keys(%{$langs{$lang}})) == 4) {
			foreach my $type (keys(%{$langs{$lang}})) {
				if (!defined($langs{$lang}{can_process})) {
					$langs{$lang}{can_process} = $langs{$lang}{$type};
				} elsif ($langs{$lang}{can_process} > $langs{$lang}{$type}) {
					$langs{$lang}{can_process} = $langs{$lang}{$type};
				}
			}
		}
		$report .= "$lang (can process ".(defined($langs{$lang}{can_process}) ? $langs{$lang}{can_process} : 0)."):\n";
		foreach my $type (qw( FP FN TP TN )) {
			if (defined($langs{$lang}{$type})) {
				$report .= "  $type $langs{$lang}{$type}\n";
			} else {
				$report .= "  $type 0\n";
			}
		}
	}

	if (defined($email)) {
		print "Send email to $email\n";
	} else {
		$this->_send_report($this->{recipient}, 'Balanced Bayes queue report', $report);
	}
}

=head2 _send_report

Internal method. Email generated report to configured recipient.

=cut

sub _send_report {
	my ($this, $to, $subject, $body, @attach) = @_;
	use MIME::Entity;
	use Net::SMTP;

	my $msg = MIME::Entity->build(
		'From' => $this->{sender},
		'To' => $to,
		'Subject' => $subject,
		'Data' => $body
	);
	foreach (@attach) {
		$msg->attach(
			Type => mimetype($_),
			Filename => $_,
			Data => read_file($_)
		);
	}
	my $smtp;
	my $retries = 3;
	while ($retries) {
		last if ($smtp = Net::SMTP->new($this->{smtp_server}));
		$retries--;
		unless ($retries) {
			print "Failed to connect to $this->{smtp_server}\n";
			return 0;
			sleep 60;
		}
	}
	$smtp->mail($this->{sender});
	$smtp->to($to);
	my $err = $smtp->code();
	if ($err >= 400) {
		print "RCPT TO failed with error $err $smtp->message()\n";
	}
	$smtp->data();
	$smtp->datasend("Date:".`date -R`);
	$smtp->datasend($msg->stringify());
	$smtp->dataend();
	$err = $smtp->code();
	if ($err < 200 || $err >= 400) {
		print "Sending failed after DATA with error $err $smtp->message()\n";
	}
	if ($smtp->message() =~ m/id=(\S+)/) {
		print "Send successfully with message ID $1\n";
		return 0;
	} else {
		print "Status unknown: ".$smtp->message()."\n";
	}
}

=head1 CHILD MODULES

=over 8

=item BalancedBayes::Vendor::Stub

A stub file which exists to be copied and modified to simplify the creation of a new Vendor module.

=item BalancedBayes::Vendor::MailCleaner

Vendor-specific functionality for MailCleaner

=item BalancedBayes::Languages

A module to detect the primary language of an input email for sorting into the proper queue.

=back

=head1 HISTORY

=over 8

=item 0.01

Initial release with enough functionality to train NiceBayes and SpamC Bogospam

=back

=head1 SEE ALSO

Github repository for issues and contributions:

https://github.com/MailCleaner/BalancedBayes

=head1 AUTHOR

John Mertz <git@john.me.tz>

=head1 COPYRIGHT

Copyright (C) 2025 by Alinto AG

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU
General Public License version 3 or later. This license is included in full with this software
distribution and must be included with any modifications or redistributions.

=cut

1;
