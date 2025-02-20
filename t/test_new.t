#!/usr/bin/perl

use BalancedBayes;
use Test2::V0;

# Generic 'Stub' vendor
my $bb = BalancedBayes->new( );
is(ref($bb->{vendor}), 'BalancedBayes::Vendor::Stub', "Loaded Stub vendor");
is($bb->{vendor}->{rootdir}, '/tmp/BalancedBayes', "Stub rootdir");
is($bb->{vendor}->{recipient}, 'root@localhost', "Stub recipient");
is($bb->{vendor}->{sender}, 'root@localhost', "Stub sender");
is($bb->{vendor}->{smtp_server}, 'localhost:25', "Stub smpt_server");
ok((-d $bb->{vendor}->{rootdir}), "Stub rootdir created");

$bb = BalancedBayes->new( 'vendor' => 'MailCleaner' );
is(ref($bb->{vendor}), 'BalancedBayes::Vendor::MailCleaner', "Loaded MailCleaner vendor");
is($bb->{vendor}->{rootdir}, '/var/MailCleaner/BalancedBayes', "MailCleaner rootdir");
is($bb->{vendor}->{sender}, 'root@gate-pp1.maillcleaner.net', "MailCleaner sender");
is($bb->{vendor}->{recipient}, 'support@mailcleaner.net', "MailCleaner recipient");
is($bb->{vendor}->{smtp_server}, 'localhost:2525', "MailCleaner smtp_server");
ok((-d $bb->{vendor}->{rootdir}), "MailCleaner rootdir created");

is($bb->rootdir(), '/var/MailCleaner/BalancedBayes', "MailCleaner Getter");
is($bb->rootdir('/tmp/BalancedBayes'), '/tmp/BalancedBayes', "MailCleaner Setter");
is($bb->rootdir(), '/tmp/BalancedBayes', "MailCleaner rootdir persits after Setter");

done_testing();
