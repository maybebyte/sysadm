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
use Getopt::Std;

our $opt_h;
our $opt_t = 'plain';


sub usage {
  die <<EOT;
$0 generates blocklists for unwind(8) and unbound(8) on OpenBSD.

usage: $0 [-h] [-t type]

-h: help.

-t: type of format, 'plain' by default.
    'plain' extracts one domain per line and does no other formatting.
    'unbound' formats the domain as 'local-zone: \"[domain]\" always_refuse'

$0 reads from STDIN and writes to STDOUT.
EOT
}


sub uniq {
  my %seen;
  grep !$seen{$_}++, @_;
}


sub format_blocklist {
  # https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch08s15.html
  #
  # Somewhat malformed domain names (hyphens, underscores, uppercase,
  # and numbers in places they shouldn't be) are accepted to catch those
  # using resolvable out-of-spec domain names to evade regular
  # expressions.
  my $domain_regexp = '\b((?=[a-zA-Z0-9-_]+\.)[a-zA-Z0-9-_]+([a-zA-Z0-9-_]+)*\.)+[a-zA-Z0-9-_]+\b';
  my @domains;

  while (<>) {
    # Don't process commented or blank lines.
    unless (m/^(#|$)/) {
      # Fixes bogus entries like "0.0.0.0adobeflashplayerb.xyz" that
      # will technically match $domain_regexp. We want to do this
      # *before* the match, as "$&" entirely depends on what's matched.
      s/(127\.0\.0\.1|0\.0\.0\.0)//g;

      if (m/$domain_regexp/) {
        # If there are only integers and dots in the match, don't count
        # it as a valid domain.
        #
        # This is needed since our domain regexp was necessarily bent to
        # catch ne'er-do-wells, and it has lost some sanity as a result.
        next if ($& =~ m/^[\d\.]+$/);

        # Convert any accepted uppercase to lowercase, since DNS is
        # case-insensitive anyway.
        $domains[++$#domains] = lc($&);
      }
    }
  }

  my @unique_domains = uniq(@domains);

  if ($opt_t =~ m/^plain$/) {
    print("use-application-dns.net\n");
    print("$_\n") for (sort(values(@unique_domains)));
  }

  elsif ($opt_t =~ m/^unbound$/) {
    print("local-zone: \"use-application-dns.net\" always_refuse\n");
    print("local-zone: \"$_\" always_refuse\n") for (sort(values(@unique_domains)));
  }
}


getopts('ht:');

usage if $opt_h;

die "$opt_t is not a valid type" if ($opt_t !~ m/^(plain|unbound)$/);

format_blocklist;