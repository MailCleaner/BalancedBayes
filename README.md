# Balanced Bayes

This is a quick-and-dirty Perl library which maintains queue of messages to be processed for bayes training. It is "Balanced" because it will ensure that an (approximately) equal number of False-Positives, False-Negatives, True-Positives, and True-Negatives get trained.

The Module `BalancedBayes::Vendor::MailCleaner` is bespoke to MailCleaner and will be used as a default, but a stub module `BalancedBayes::Vendor::Stub` exists which can be copied and modified to create specific implementations for other systems. This can be subbed out by initializing with `BalancedBayes->new( 'vendor' => 'MyVendor' );` in order to load `BalancedBayes::Vendor::MyVendor` instead.

## Usage

The BalancedBayes::Vendor::Stub module is provided to make it easy to implement for other vendors, but in order for the executabales to actually be usable they specifically use the BalancedBayes::Vendor::MailCleaner module. Modify or take inspiration from these as you see fit.

`bin/feed_bayes.pl` - Use this script to add a given message to the appropriate queue directory.

`bin/process_bayes.pl` - Use this script to check for trainable items in any of the queues.

`bin/bayes_report.pl` - Use this to generate a report of the number of items queued, the number already trained, any deficit from one type to the others and the number which are trainable. With an email address, it will mail the report.

## Installation

Clone the repository:

```bash
git clone https://github.com/MailCleaner/BalancedBayes
cd BalancedBayes
```

Generate the makefile:

```bash
perl Makefile.PL
```

Install dependencies:

```bash
cpanm --installdeps .
```

Build:

```bash
make
```

Install:

```bash
sudo make install
```
