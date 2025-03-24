#TODO: Read in MIME message body (currently reading as plain text)
#TODO: New bin to process as many trainable messages as possible
#TOOO: Train a fresh DB from good starting data
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

  # Validate the message and feed to bayes. Here we check that it was actually a false-positive:
  die "$eml_file was not scranned by MailCleaner\n" unless $bb->validate_vendor();
  die "$eml_file was not detected as Spam" unless $bb->validate_spam();

  # Feed to false positive queue. Queue file location returned.
  my $queue_path = $bb->false_positive();

  # Force the given path to be trained immediately.
  $bb->train_fp($queue_path);

  # Train the most recent item for a given language:
  $bb->train_fp('en');

  # Train the maximum available queued items; balance the training if forced to unbalanced state:
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
use File::Copy qw( move );
use BalancedBayes::Language qw(detect_language);
use DBI;
use Digest::SHA1 qw( sha1_hex );

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
	if (-e "$this->{vendor}->{rootdir}/trained.sqlite") {
		$this->_db_connect();
	} else {
		$this->_db_create();
	}
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
	my $file = shift || die "No file provided\n";
	$this->{msg} = {};
	$this->{msg}->{path} = $file;
	my @contains = ();

	my $eml;
    	if (!open($eml, '<', $file) ) {
        	return 0;
    	}
	$this->{msg}->{time} = (stat($file))[9];

	my $last = '';
	$this->{msg}->{headers} = {};
	while (my $line = <$eml>) {
			last if ($line) =~ m/^\s*$/;
			chomp($line);
			if (my ($key, $value) = $line =~ m/^(\S+): (\S.*)$/) {
				$last = $key;
				if ($key eq 'Received') {
					if (defined($this->{msg}->{headers}->{$key})) {
						push(@{$this->{msg}->{headers}->{$key}}, $value);
					} else {
						$this->{msg}->{headers}->{$key} = [ $value ];
					}
				} else {
					$this->{msg}->{headers}->{$key} = $value;
				}
			} elsif ($last eq 'Received') {
				$this->{msg}->{headers}->{$last}->[scalar(@{$this->{msg}->{headers}->{$last}})-1] .= "\n$line";
			} else {
				$this->{msg}->{headers}->{$last} .= "\n$line";
			}
			chomp($this->{msg}->{headers}->{$last});
	}
	$this->{msg}->{body} = [];
	while (my $line = <$eml>) {
		chomp($line);
		push(@{$this->{msg}->{body}}, $line);
	}
	close($eml);
	$this->{msg}->{hash} = sha1_hex(join("\n", @{$this->{msg}->{body}}));
	$this->{msg}->{lang} = detect_language($this->{msg}->{body});
        return 1;
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
	return $this->{vendor}->validate_vendor($this->{msg});
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
	return $this->{vendor}->validate_spam($this->{msg});
}

=head2 validate_ham

Request passed to Vendor method. Returns true/false for whether the message was previously detected
as ham by the vendor.

This should be used after C<validate_vendor> has been confirmed and is only necessary for corrective
training.

=cut

sub validate_ham {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	return $this->{vendor}->validate_ham($this->{msg});
}

=head2 false_positive

Add the message to the False Positive queue.

=cut

sub false_positive {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	my $new_path = $this->{vendor}->false_positive($this->{msg}, $this->{msg}->{path}, $this->{msg}->{lang});
	$this->{msg}->{path} = $new_path if (defined($new_path));
	return $new_path;
}

=head2 false_negative

Add the message to the False Negative queue.

=cut

sub false_negative {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	my $new_path = $this->{vendor}->false_negative($this->{msg}, $this->{msg}->{path}, $this->{msg}->{lang});
	$this->{msg}->{path} = $new_path if (defined($new_path));
	return $new_path;
}

=head2 true_positive

Add the message to the True Positive queue.

=cut

sub true_positive {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	my $new_path = $this->{vendor}->true_positive($this->{msg}, $this->{msg}->{path}, $this->{msg}->{lang});
	$this->{msg}->{path} = $new_path if (defined($new_path));
	return $new_path;
}

=head2 true_negative

Add the message to the True Negative queue.

=cut

sub true_negative {
	my $this = shift;
	my $raw = shift;
	$this->load_message($raw) if (defined($raw));
	my $new_path = $this->{vendor}->true_negative($this->{msg}, $this->{msg}->{path}, $this->{msg}->{lang});
	$this->{msg}->{path} = $new_path if (defined($new_path));
	return $new_path;
}

=head2 train_fp

Process a message from the false-positive queue. With a file path, it will process that message.
With a language code, it will process the newest queued message in that language directory.

=cut

sub train_fp {
	my ($this, $msg_path, $msg_lang, $msg_time) = @_;
	if (defined($msg_path)) {
		if (defined($this->{msg}->{path}) && $msg_path eq $this->{msg}->{path}) {
			$msg_time = $this->{msg}->{time};
			$msg_lang = $this->{msg}->{lang};
		} elsif (-d "$this->{vendor}->{rootdir}/queue/$msg_path") {
			$msg_lang = $msg_path;
			$msg_path = $this->_get_latest("$this->{vendor}->{rootdir}/queue/$msg_lang/fp");
			$this->load_message($msg_path);
		}
	} else {
		$msg_path = $this->{msg}->{path};
		$msg_lang = $this->{msg}->{lang};
		$msg_time = $this->{msg}->{time};
	}
	$msg_time //= (stat($msg_path))[9];
	die "Failed to locate message for $msg_path\n" unless (-e $msg_path);
	my $prev = $this->_find_in_db();
	if (defined($prev) && $prev->{time} <= $msg_time) {
		if ($prev->{disposition} eq 'fp' || $prev->{disposition} eq 'tn') {
			print "Same message already trained with Spam disposition. Updating timestamp only.\n";
			$this->_log_to_db('fp', $msg_lang, $msg_time);
		} else {
			$this->_log_to_db('fp', $msg_lang, $msg_time) if ($this->{vendor}->train_ham($msg_path));
		}
	} elsif (defined($prev)) {
		print "Same message with more recent timestamp already trained\n";
	} else {
		$this->_log_to_db('fp', $msg_lang, $msg_time) if ($this->{vendor}->train_ham($msg_path));
	}
	$this->{vendor}->sweep($msg_path);
}

=head2 train_fn

Process a message from the false-negative queue. With a file path, it will process that message.
With a language code, it will process the newest queued message in that language directory.

=cut

sub train_fn {
	my ($this, $msg_path, $msg_lang, $msg_time) = @_;
	if (defined($msg_path)) {
		if (defined($this->{msg}->{path}) && $msg_path eq $this->{msg}->{path}) {
			$msg_time = $this->{msg}->{time};
			$msg_lang = $this->{msg}->{lang};
		} elsif (-d "$this->{vendor}->{rootdir}/queue/$msg_path") {
			$msg_lang = $msg_path;
			$msg_path = $this->_get_latest("$this->{vendor}->{rootdir}/queue/$msg_lang/fn");
			$this->load_message($msg_path);
		}
	} else {
		$msg_path = $this->{msg}->{path};
		$msg_lang = $this->{msg}->{lang};
		$msg_time = $this->{msg}->{time};
	}
	$msg_time //= (stat($msg_path))[9];
	die "Failed to locate message for $msg_path\n" unless (-e $msg_path);
	my $prev = $this->_find_in_db();
	if (defined($prev) && $prev->{time} <= $msg_time) {
		if ($prev->{disposition} eq 'fn' || $prev->{disposition} eq 'tp') {
			print "Same message already trained with Ham disposition. Updating timestamp only.\n";
			$this->_log_to_db('fn', $msg_lang, $msg_time);
		} else {
			$this->_log_to_db('fn', $msg_lang, $msg_time) if ($this->{vendor}->train_spam($msg_path));
		}
	} elsif (defined($prev)) {
		print "Same message with more recent timestamp already trained\n";
	} else {
		$this->_log_to_db('fn', $msg_lang, $msg_time) if ($this->{vendor}->train_spam($msg_path));
	}
	$this->{vendor}->sweep($msg_path);
}

=head2 train_tp

Process a message from the true-positive queue. With a file path, it will process that message.
With a language code, it will process the newest queued message in that language directory.

=cut

sub train_tp {
	my ($this, $msg_path, $msg_lang, $msg_time) = @_;
	if (defined($msg_path)) {
		if (defined($this->{msg}->{path}) && $msg_path eq $this->{msg}->{path}) {
			$msg_time = $this->{msg}->{time};
			$msg_lang = $this->{msg}->{lang};
		} elsif (-d "$this->{vendor}->{rootdir}/queue/$msg_path") {
			$msg_lang = $msg_path;
			$msg_path = $this->_get_latest("$this->{vendor}->{rootdir}/queue/$msg_lang/tp");
			$this->load_message($msg_path);
		}
	} else {
		$msg_path = $this->{msg}->{path};
		$msg_lang = $this->{msg}->{lang};
		$msg_time = $this->{msg}->{time};
	}
	$msg_time //= (stat($msg_path))[9];
	die "Failed to locate message for $msg_path\n" unless (-e $msg_path);
	my $prev = $this->_find_in_db();
	if (defined($prev) && $prev->{time} <= $msg_time) {
		if ($prev->{disposition} eq 'tp' || $prev->{disposition} eq 'fn') {
			print "Same message already trained with Ham disposition. Updating timestamp only.\n";
			$this->_log_to_db('tp', $msg_lang, $msg_time);
		} else {
			$this->_log_to_db('tp', $msg_lang, $msg_time) if ($this->{vendor}->train_spam($msg_path));
		}
	} elsif (defined($prev)) {
		print "Same message with more recent timestamp already trained\n";
	} else {
		$this->_log_to_db('tp', $msg_lang, $msg_time) if ($this->{vendor}->train_spam($msg_path));
	}
	$this->{vendor}->sweep($msg_path);
}

=head2 train_tn

Process a message from the true-negative queue. With a file path, it will process that message.
With a language code, it will process the newest queued message in that language directory.

=cut

sub train_tn {
	my ($this, $msg_path, $msg_lang, $msg_time) = @_;
	if (defined($msg_path)) {
		if (defined($this->{msg}->{path}) && $msg_path eq $this->{msg}->{path}) {
			$msg_time = $this->{msg}->{time};
			$msg_lang = $this->{msg}->{lang};
		} elsif (-d "$this->{vendor}->{rootdir}/queue/$msg_path") {
			$msg_lang = $msg_path;
			$msg_path = $this->_get_latest("$this->{vendor}->{rootdir}/queue/$msg_lang/tn");
			$this->load_message($msg_path);
		}
	} else {
		$msg_path = $this->{msg}->{path};
		$msg_lang = $this->{msg}->{lang};
		$msg_time = $this->{msg}->{time};
	}
	$msg_time //= (stat($msg_path))[9];
	die "Failed to locate message for $msg_path\n" unless (-e $msg_path);
	my $prev = $this->_find_in_db();
	if (defined($prev) && $prev->{time} <= $msg_time) {
		if ($prev->{disposition} eq 'fp' || $prev->{disposition} eq 'tn') {
			print "Same message already trained with Spam disposition. Updating timestamp only.\n";
			$this->_log_to_db('tn', $msg_lang, $msg_time);
		} else {
			$this->_log_to_db('tn', $msg_lang, $msg_time) if ($this->{vendor}->train_ham($msg_path));
		}
	} elsif (defined($prev)) {
		print "Same message with more recent timestamp already trained\n";
	} else {
		$this->_log_to_db('tn', $msg_lang, $msg_time) if ($this->{vendor}->train_ham($msg_path));
	}
	$this->{vendor}->sweep($msg_path);
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

=head2 _db_create

Internal method. Initializes SQLite DB to track trained items.

=cut

sub _db_create {
	my $this = shift;
	my $path = shift;
	if ( -e "$this->{vendor}->{rootdir}/trained.sqlite") {
		die "$path already exists.\n";
	}
	$this->_db_connect();
	$this->{dbh}->do("CREATE TABLE trained(".
		"checksum TEXT PRIMARY KEY, ".
		"disposition TEXT CHECK( disposition IN ('fp', 'fn', 'tp', 'tn') ), ".
		"language TEXT, ".
		"time INTEGER".
		");") || die "Failed to create DB: $!\n";
}

=head2 _db_connect

Internal method. Connect to trained message database.

=cut

sub _db_connect {
	my $this = shift;
	$this->{dbh} = DBI->connect(
		"dbi:SQLite:dbname=$this->{vendor}->{rootdir}/trained.sqlite",
		 '', '', {AutoCommit=>1, PrintError=>0}
	) || die "Failed to connect to DB $this->{vendor}->{rootdir}/trained.sqlite: $!\n";
}

=head2 _db_disconnect

Internal method. Disconnect from trained message database.

=cut

sub _db_disconnect {
	my $this = shift;
	$this->{dbh}->disconnect() || die "Failed to disconnect from DB: $!\n";
}

=head2 _find_in_db

Internal method. Looks for the body checksum in the database. Will return the disposition and time
of the most recent occurance of the checksum if there was one or undef. Used to prevent re-training.

=cut 

sub _find_in_db { 
	my $this = shift;
	die "Message has not been loaded\n" unless (defined($this->{msg}->{hash}));
	my $query = "SELECT checksum, disposition, time FROM trained WHERE checksum = '$this->{msg}->{hash}';";
	my $trained = $this->{dbh}->selectall_hashref($query, 'checksum');
	return { 
		'time' => $trained->{$this->{msg}->{hash}}->{time},
		'disposition' => $trained->{$this->{msg}->{hash}}->{disposition}
	} if (defined($trained->{$this->{msg}->{hash}}));
	return undef;
}

=head2 _log_to_db

Internal method. Get a checksum of the body content and logs the disposition. This is used to track
historic training data and to prevent re-training the exact same content.

=cut

sub _log_to_db {
	my ($this, $disposition, $language, $time) = @_;
	die "Attempt to log without disposition, language, or time\n" unless (defined($disposition));
	die "Attempt to log without language or time\n" unless (defined($language));
	die "Attempt to log without time\n" unless (defined($time));
	print("Logging $this->{msg}->{hash} as $disposition\n");
	die "Attempt to log before loading message\n" unless (defined($this->{msg}));
	die "Attempt to log before connecting to DB\n" unless (defined($this->{dbh}));
	my $query = "INSERT OR REPLACE INTO trained(checksum, disposition, language, time) ".
		"VALUES('$this->{msg}->{hash}', '$disposition', '$language', '$time');";
	$this->{dbh}->do($query) || die "Failed to write to DB: $!\n";
}

=head2 get_counts

Enumerate the quantities of already trained items and items in the queue. Retrun hashref keys for
each language, each hashes:

=over 8

=item trained

The number of message already trained as false-positive, false-negative, true-positive, and true
-negative, according to the DB.

=item queued

The number of messages waiting to be trained in the respective false-positive, false-negative, true
-positive, and true-negative queue directories.

=item trainable

The number of message of each type which can be trained. This is the largest of queues plus or minus
any deficit or surplus that have already been trained.

=back

=cut

sub get_counts {
	# This function will collect the counts for:
        #   Number of messages already trained for each type from SQLite DB
        #   Number of items queued in each directory
	#   Number of items which can be trained for each type calculated as described here
	#
	# Note: these counts are made for each detected language, not as a whole.
	#
	# The goal is to keep the same minimum number of trained items and to hove those converge on
	# any types that have excess trained items. To do this, we need to get the deficit for each
	# type (ie. the number of items trained for that type, vs. the highest number trained for
	# any type.
	#   deficit_fp = max( trained_fp, trained_fn ...) - trained_fp;
	# Then we need to compare each deficit to the respective number of items in it's queue to
	# determine how many items will remain in the queue if the deficit were satisfied:
	#   remaining_queue_fp = queue_fp - deficit_fp
	# In the case where a type has a larger deficit than it has queued items, this value will be
	# negative, meaning that there are not enough items to satisfy the deficit. However, other
	# types which also have a deficit can be incremented by the same amount.
	# In any case, we need to take the lowest value for the remaining queue and add the deficit
	# for each respective queue back to tell us how many items to process for that queue.
	#   trainable_fp = deficit_fp + min( remaining_queue_fp, remaining_queue_fn ...)
	# For queues where the deficit is larger, this will cancel out so that the trainable is just
	# the same as the queued. For all others it will be just enough to bring it up to have the
	# same number trained as the next lowest queue.
	# Example:                 Computed:                           After:
	# Type  Trained  Queued    Deficit  Remaining  Trainable       Type  Trained  Queued   
	# FP    100      10        0        10         -5 (ignored)    FP    100      10
	# FN    80       30        20       10         15              FN    95       5
	# TP    80       100       20       80         15              TP    95       65
	# TN    75       20        25       -5         20              TN    95       0

	my $this = shift;
	my $counts = {};
	
	# First, find which languages actually exist based on the queue directories
	foreach my $lang (glob($this->{vendor}->{rootdir}."/queue/*")) {
		$lang =~ s|^.*/([^/]*)$|$1|;
		
		# Keep track of the highest trained value for next step
		my $max_trained = 0;

		# For each language, collect the counts for each type
		foreach my $type (qw| fp fn tp tn |) {
			# Get number of already trained messages for that language/type from the DB
			my $query = "SELECT count(disposition) FROM trained WHERE language = '".$lang."' AND disposition = '".$type."';";
			my $ret = $this->{dbh}->selectall_hashref($query, 'count(disposition)');
			$counts->{$lang}->{$type}->{trained} = (keys %{$ret})[0] || 0;

			# Set new highest trained value if larger
			$max_trained = $counts->{$lang}->{$type}->{trained} if ($counts->{$lang}->{$type}->{trained} > $max_trained);

			# Get number of queued files from the directory
			my @files = glob($this->{vendor}->{rootdir}."/queue/".$lang."/".$type."/*");
			$counts->{$lang}->{$type}->{queued} = scalar(@files);
		}

		# Determine the deficit as the largest trained less the trained for this queue:
		my $min_untrainable;
		foreach my $type (qw| fp fn tp tn |) {
			$counts->{$lang}->{$type}->{deficit} = $max_trained - $counts->{$lang}->{$type}->{trained};
			if (
				!defined($min_untrainable) ||
				($counts->{$lang}->{$type}->{queued} - $counts->{$lang}->{$type}->{deficit}) < $min_untrainable
			) {
				$min_untrainable = $counts->{$lang}->{$type}->{queued} - $counts->{$lang}->{$type}->{deficit};
				#$min_untrainable = $counts->{$lang}->{$type}->{deficit};
			}
		}
			
		# Determine the count for items which can be trained:
		foreach my $type (qw| fp fn tp tn |) {
			$counts->{$lang}->{$type}->{trainable} = $counts->{$lang}->{$type}->{deficit} + $min_untrainable;
			$counts->{$lang}->{$type}->{trainable} = 0 if ($counts->{$lang}->{$type}->{trainable} < 0);
		}
	}
	return $counts;
}

=head2 queue_report

Generate a report with the number of items currently available in each queue and the number of
messages which can potentially be processed at this time as well as giving an indication of which
message types are needed to do additional training.

=cut

sub queue_report {
	my ($this, $email) = @_;
	$email = $this->{vendor}->{recipient} if (defined($email) && $email =~ m/^(1|default)$/);

	my $counts = $this->get_counts();

	my $report = "\nWe have the following number of items in the Bayesian queues:\n\n".
"Language    Type        Trained     Queued      Trainable\n";
	my $more = "We could use more:\n\n";
	foreach my $lang (keys(%{$counts})) {
		my $first = 0;
		$more .= "\t$lang:     ";
		foreach (qw| fp fn tp tn |) {
			$report .= sprintf("%-12s",($first++ ? '' : $lang));
			$report .= sprintf("%-12s",$_);
			$report .= sprintf("%-12s",$counts->{$lang}->{$_}->{trained});
			$report .= sprintf("%-12s",$counts->{$lang}->{$_}->{queued});
			$report .= sprintf("%-12s",$counts->{$lang}->{$_}->{trainable});
			$report .= "\n";
			$more .= "$_  " if ($counts->{$lang}->{$_}->{deficit} - $counts->{$lang}->{$_}->{queued} < 0);
		}
		$more .= "\n";
	}
	$report .= "\n$more";

	if (defined($email)) {
		$this->_send_report($email, 'BalancedBayes Queue Report', $report);
	} else {
		print $report;
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
		'From' => $this->{vendor}->{sender},
		'To' => $to,
		'Subject' => $subject,
		'Date' => `date -R`,
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
		last if ($smtp = Net::SMTP->new($this->{vendor}->{smtp_server}));
		$retries--;
		unless ($retries) {
			print "Failed to connect to $this->{vendor}->{smtp_server}\n";
			return 0;
			sleep 60;
		}
	}
	$smtp->mail($this->{vendor}->{sender});
	$smtp->to($to);
	my $err = $smtp->code();
	if ($err >= 400) {
		print "RCPT TO failed with error $err $smtp->message()\n";
	}
	$smtp->data();
	$smtp->datasend($msg->stringify());
	$smtp->dataend();
	$err = $smtp->code();
	if ($err < 200 || $err >= 400) {
		print "Sending failed after DATA with error $err $smtp->message()\n";
	}
	if ($smtp->message() =~ m/id=(\S+)/) {
		print "Sent successfully to $to with message ID $1\n";
		return 0;
	} else {
		print "Status unknown: ".$smtp->message()."\n";
	}
}

=head2 _get_latest

Internal method. Searches given directory for the item with the most recent creation date.

=cut

sub _get_latest {
	my $this = shift;
	my $dir = shift || die "No directory provided\n";
	my ($latest_cdate, $latest_path) = (0);
	if (opendir(my $dh, $dir)) {
		my @files = readdir($dh);
		foreach (@files) {
			next if ($_ =~ m/^\./);
			die "$_ is not a file\n" unless (-f "$dir/$_");
			my ($cdate) = (stat("$dir/$_"))[9];
			$latest_path = "$dir/$_" if ($cdate > $latest_cdate);
		}
	} else {
		die "Could not open dir $dir: $?\n";
	}
	return $latest_path;
}

=head2 DESTROY

Override built-in destructor. Explicitely disconnect from DB on exit.

=cut

sub DESTROY {
	my $this = shift;
	$this->{dbh}->disconnect() if ($this->{dbh});
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
