=head1 NAME

BalancedBayes::Language - Wrapper to detect the text language of the email.

=cut

package BalancedBayes::Language 0.001;

=head1 DESCRIPTION

This module provides a fairly basic abstraction around the Lingua::Identify::Any module. It serves
to handle the default confidence requirement and not much else. In the future it should strip HTML
and other non-text elements in order to reduce the English bias as the native language of HTML/CSS.

=head1 EXPORT

detect_language - Expects a text string and optional confidence requirement. Will return a language
	code if the confidence is met, or undef.

=cut 

use Exporter qw<import>;
our @EXPORT = qw( detect_language );

=head1 SYNOPSIS

  # Requires only a text string, so you can use without initializing a BalancedBayes object with:
  use BalancedBayes::Language;
  print "Detected: ".detect_language("This is my text")."\n";

  # For use with BalancedBayes, typically you will initialize, load a message, then check the body.
  use BalancedBayes;
  use BalancedBayes::Language;
  my $bb = BalancedBayes->new( vendor => 'Stub' );
  $bb->load_message("/tmp/some_message.txt");
  print "Detected: ".detect_language($this->{msg}->{body})."\n";

=head1 DEPENDENCIES

  Depends on CPAN distribution:

  Lingua::Identify::Any

=cut
  
use Lingua::Identify::Any qw( detect_text_language);

=head1 METHODS

=head2 detect_language

Wrapper around Lingua::Identify::Any which will return the language code if the confidence is met
for the input text.

Requires at least one argument with a text string. Second argument with confidence from 0-1 is
optional (default: 0.6);

=cut

sub detect_language {
	my $text = shift;
	my $confidence = shift || 0.6;
	$text = _clean_text($text);
	my $res = detect_text_language(text => $text);
	return undef unless ($res->[1] eq 'OK');
	return undef if ($res->[2]->{lang_code} eq 'un');
	# The identifier CLD seems to default to thinking that everything is English, with low
	# confidence when it is gibberish. Raise the threshold for 'en'.
	if ($res->[2]->{lang_code} eq 'en') {
		$confidence += 0.1 while ($confidence < 0.7);
	}
	return undef unless ($res->[2]->{confidence} > $confidence);
	return $res->[2]->{lang_code};
}

=head2 _clean_text

Private method to remove HTML, URLs, etc. from input text.

=cut

sub _clean_text {
	my $text = shift;
	# Remove URLs
	$text =~ s#https?://\S+##g;
	# Remove HTML tags
	$text =~ s#<[^>]+>##g;
	# Remove BASE64. Require mixed upper/lower/numeral to avoid just hitting long words.
	$text =~ s#[a-zA-Z0-9]+([a-z][A-Z0-9]|[A-Z][a-z0-9]|[0-9][a-zA-Z])[a-zA-Z0-9]+##g;
	return $text;
}

=head1 HISTORY

=over 8

=item 0.01

Initial release which can check the language of input text, unmodified.

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
