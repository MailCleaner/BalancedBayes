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

my %unknown = (
	'blank' => "",
	'whitespace' => "   	
   	",
	'nonsense' => "Zxylw trwixip labkmathwib t-ubyvz",
	'BASE64' => "Wnh5bHcgdHJ3aXhpcCBsYWJrbWF0aHdpYiB0LXVieXZ6",
	'html' => "<div><hr><img src='123.jpg'/></div>",
	'url' => "https://dont-detect-urls-only.org",
);

foreach my $code (keys(%langs)) {
	my $found = BalancedBayes::Language::detect_language($langs{$code});
	is($found, $code, "$langs{$code} == $code (found $found)");
}

foreach my $code (keys(%unknown)) {
	my $found = BalancedBayes::Language::detect_language($unknown{$code});
	is($found, undef, "$unknown{$code} == unknown (found undef)");
}

done_testing();
