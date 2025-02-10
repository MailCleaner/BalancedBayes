#!/usr/bin/perl

use strict;
use warnings;

use BalancedBayes;

my $bb = BalancedBayes->new( ( 'rootdir' => '~/bb' ) );
$bb->queue_report;
