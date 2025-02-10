#!/usr/bin/perl

package BalancedBayes;

use strict;
use warnings;

use Cwd;
use File::MimeInfo;
use File::Slurp;

sub new {
	my $class = shift || "BalancedBayes";
	my %args = @_;
	my $this = {
		'rootdir' => '/var/mailcleaner/BalancedBayes',
		'sender' => 'root@gate-pp1.mailcleaner.net',
		'recipient' => 'support@mailcleaner.net',
		'smtp_server' => 'localhost:2525',
	};
	foreach my $key (keys(%args)) {
		print "Overwriting $key = $args{$key}\n";
		$this->{$key} = $args{$key};
	}
	$this->{rootdir} =~ s|/$||;
	check_dir($class, $this->{rootdir});
	return bless $this, $class;
}

sub load_message {
	my $this = shift;
	my $raw = shift;

	$this->{msg} = $raw;
}

sub detect_mc {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
}

sub detect_nicebayes {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
}

sub detect_bogospam {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
}

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
		$this->send_report($this->{recipient}, 'Balanced Bayes queue report', $report);
	}
}

sub send_report {
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

1;
