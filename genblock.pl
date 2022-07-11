#!/usr/bin/env perl
# Copyright (c) 2022 Ashlen <eurydice@riseup.net>

# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;

# Parse command line options.
use Getopt::Std;

# Extract file name.
use File::Basename;
use v5.14; # character interpretation

our $opt_h;
our $opt_t = 'plain';

my $program_name = fileparse $0;


sub usage {
	die <<"EOT";
$program_name extracts unique domains. Useful for generating blocklists.

usage: $program_name [-h] [-t type] [file (optional)] ...

-h: help.

-t: type of format, 'plain' by default.
    'plain' extracts one domain per line and does no other formatting.
    'unbound' formats the domain as 'local-zone: \"[domain]\" always_refuse'

$program_name reads from STDIN or a given file.
EOT
}


sub uniq {
	my %seen;
	return grep {! $seen{$_}++} @_;
}


sub unique_domains {
	# https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch08s15.html
	#
	# Somewhat malformed domain names (hyphens, underscores, uppercase,
	# and numbers in places they shouldn't be) are accepted to catch those
	# using resolvable out-of-spec domain names to evade regular
	# expressions.
	my $domain_regexp = '\b((?=[\w-]+\.)[\w-]+([\w-]+)*\.)+[\w-]+\b';
	my @domains;

	while (<>) {
		# Don't process commented or blank lines.
		next if /\A\s*#?\z/a;
		# Fixes bogus entries like "0.0.0.0adobeflashplayerb.xyz" that
		# will technically match $domain_regexp. We want to do this
		# *before* the match, as "${^MATCH}" entirely depends on what's matched.
		s/127\.0\.0\.1//g;
		s/0\.0\.0\.0//g;

		if (/$domain_regexp/pa) {
			# If there are only integers and dots in the match, don't count
			# it as a valid domain.
			#
			# This is needed since our domain regexp was necessarily bent to
			# catch ne'er-do-wells, and it has lost some sanity as a result.
			next if ${^MATCH} =~ /\A[\d.]+\z/a;

			# Convert any accepted uppercase to lowercase, since DNS is
			# case-insensitive anyway.
			push @domains, lc ${^MATCH};
		}
	}

	return uniq @domains;
}


getopts 'ht:';
usage if $opt_h;


if ($opt_t eq 'plain') {
	say $_ for (unique_domains);
} elsif ($opt_t eq 'unbound') {
	say "local-zone: \"$_\" always_refuse" for (unique_domains);
} else {
	die "$opt_t is not a valid type.\n";
}
