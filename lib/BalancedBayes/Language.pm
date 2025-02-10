#!/usr/bin/perl

package BalancedBayes::Language;

use Exporter qw<import>;
my @EXPORT_OK = qw( detect );

use Lingua::Identify::Any qw( detect_text_language);

sub detect {
	my $text = shift;
	my $confidence = shift || 0.7;
	my $res = detect_text_language(text => $text);
	return undef unless ($res->[1] == 'OK');
	return $res->[2]->{lang_code};
}

1;
