#!/usr/bin/perl

use BalancedBayes;
use Test2::V0;

our $test_file = '/tmp/test_load_message.eml';

our %headers = (
        'Return-Path' => '<return-path@domain.com>',
        'Received' => [
                'from relay.server ([1.2.3.4]) by
        mailcleaner.client stage1 with esmtps
        (Exim MailCleaner)
        id eximid-00000123456-7890 
        for <recipient@client.com>
        from <sender@domain.com>;
        Mon, 01 Jan 2000 00:00:00 +0000',
                'from localhost (localhost [127.0.0.1])
        by relay.server (Postfix) with ESMTP id ABCDE12345
        for <recipient@client.com>; Mon, 01 Jan 2000 01:00:00 +0100 (CET)'
        ],
        'X-MailCleaner-SPF' => 'pass',
        'X-MailCleaner-Information' => 'Please contact root@john.me.tz for more information',
        'X-MailCleaner-ID' => 'eximid-00000123456-7890',
        'X-MailCleaner' => 'Found to be clean',
        'X-MailCleaner-SpamCheck' => 'not spam, Newsl (score=0.0, required=5.0, NONE,
        position : 0, not decisive), NiceBayes 12.3%, position : 2, not decisive),
        Spamc (score=0.0, required=5.0, NONE, position : 6, ham decisive)',
        'X-MailCleaner-ReportURL' => 'https://mc.john.me.tz/rs.php',
        'From' => 'Sender Address <sender@domain.com>',
        'To' => 'Recipient Address <recipient@client.com>',
        'Subject' => 'Subject Line',
        'Date' => 'Mon, 01 Jan 2000 00:00:00 +0000',
);
our @body = (
        'Hello,',
        '',
        'This is my multi-line email',
        '',
        'Bye',
);

sub write_test_email {
	if (open(my $eml, '>', $test_file)) {
        	print $eml 
                	"Return-Path: $headers{'Return-Path'}\n".
			"Received: $headers{'Received'}->[0]\n".
			"Received: $headers{'Received'}->[1]\n";
        	foreach (qw| X-MailCleaner-SPF X-MailCleaner-Information X-MailCleaner-ID X-MailCleaner X-MailCleaner-SpamCheck X-MailCleaner-ReportURL From To Subject Date |) {
                	print $eml "$_: $headers{$_}\n";
        	}
        	print $eml "\n".join("\n", @body);
        	close $eml;
	} else {
        	die "Failed to store temporary email file /tmp/test_load_message.eml\n";
	}
}

my $bb = BalancedBayes->new( vendor => 'MailCleaner' );
write_test_email();
$bb->load_message($test_file);

ok($bb->validate_vendor, "Correctly validated MailCleaner vendor");
ok(!$bb->validate_spam, "Correctly validate MailCleaner not spam");
$headers{'X-MailCleaner-SpamCheck'} = 'spam, Newsl (score=0.0, required=5.0, NONE,
        position : 0, not decisive), NiceBayes (99.9%, position : 2, spam decisive)';
write_test_email();
$bb->load_message($test_file);
ok($bb->validate_spam, "Correctly validate MailCleaner spam (NiceBayes)");
$headers{'X-MailCleaner-SpamCheck'} = 'not spam, Newsl (score=0.0, required=5.0, NONE,
        position : 0, not decisive), NiceBayes 12.3%, position : 2, not decisive),
        Spamc (score=3.0, required=5.0, BAYES_90 3.0, position : 6, ham decisive)';
write_test_email();
$bb->load_message($test_file);
ok($bb->validate_spam, "Correctly validate MailCleaner spam (Bogospam)");
$headers{'X-MailCleaner-SpamCheck'} = 'spam, Newsl (score=1.0, required=5.0, SOME_RULE
        1.0, position : 0, not decisive), NiceBayes (99.9%, position : 2, spam
        decisive)';
write_test_email();
$bb->load_message($test_file);
ok($bb->validate_spam, "Correctly validate MailCleaner spam (NiceBayes) with line break");
$headers{'X-MailCleaner-SpamCheck'} = 'not spam, Newsl (score=0.0, required=5.0,
        SOME_REALLY_QUITE_LONG_RULE 1.0, position : 0, not decisive), NiceBayes 12.3%,
        position : 2, not decisive), Spamc (score=4.0, required=5.0, SOME_OTHER_RULE 1.0,
        BAYES_90 3.0, position : 6, ham decisive)';
write_test_email();
$bb->load_message($test_file);
ok($bb->validate_spam, "Correctly validate MailCleaner spam (Bogospam) with line break");

done_testing();
