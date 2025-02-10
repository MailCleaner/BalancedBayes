#!/usr/bin/perl

use BalancedBayes;
use Test2::V0;

my $path = '/tmp/BalancedBayes';
my $bb = BalancedBayes->new('/tmp/BalancedBayes');
ok((-e $path), "Path created with new");

open(my $fh, '>', $path."/test");
print $fh "test";
close($fh);

like( 
    dies( sub { BalancedBayes->new($path."/test") } ),
    qr(${path}/test exists but is not a directory),
    "die if file exists with expected dir name",
);

unlink($path."/test");
unlink($path);

