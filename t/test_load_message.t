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
        	foreach (qw| From To Subject Date |) {
                	print $eml "$_: $headers{$_}\n";
        	}
        	print $eml "\n".join("\n", @body);
        	close $eml;
	} else {
        	die "Failed to store temporary email file /tmp/test_load_message.eml\n";
	}
}

my $bb = BalancedBayes->new();
write_test_email();
$bb->load_message($test_file);

is($bb->{msg}->{body}, \@body, "Correctly parsed body");
is($bb->{msg}->{headers}, \%headers, "Correctly parsed headers");

done_testing();
