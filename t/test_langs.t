#!/usr/bin/perl

use BalancedBayes::Language;
use Test2::V0;

my %langs = (
	'de' => "Dies ist ein Test auf Deutsch",
	'en' => "This is a test in English",
	'es' => "Esta es una prueba en español",
	'fr' => "C'est une teste en Française",
	'it' => "Questo è un test in italiano",
	'nl' => "Dit is een test in het Nederlands",
	'pl' => "To jest test po polsku",
);

foreach my $code (keys(%langs)) {
	my $found = BalancedBayes::Language::detect($langs{$code});
	is($found, $code, "$langs{$code} == $code (found $found)");
}

