package BalancedBayes::Vendor 0.001;
use strict;
use warnings;

sub new {
	my $class = shift;
	return bless {}, $class;
}

# Generic Getters/Setters
sub recipient {
	my ($this, $set) = @_;
	$this->{recipient} = $set if (defined($set));
	return $this->{recipient};
}

sub rootdir {
	my ($this, $set) = @_;
	$this->{rootdir} = $set	if (defined($set));
	return $this->{rootdir};
}

sub sender {
	my ($this, $set) = @_;
	$this->{sender} = $set if (defined($set));
	return $this->{sender};
}

sub smtp_server {
	my ($this, $set) = @_;
	$this->{smtp_server} = $set if (defined($set));
	return $this->{smtp_server};
}

1;
