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
use File::Temp;
use HTTP::Tiny;
use IO::Socket::SSL;


sub usage {
  die <<EOT;
$0 generates blocklists for unwind(8) and unbound(8) on OpenBSD.

usage: $0 [format] /path/to/save/blocklist

formats can be: plain unbound

plain: Saves one domain per line.
unbound: Same as above, but formatted as 'local-zone: \"[domain]\" always_refuse'
EOT
}


my $format = shift or usage;
my $out_file = shift or usage;

die "$format is not a valid format" if ($format !~ m/^(plain|unbound)$/);

my $tmp_file = File::Temp->new;

# https://v.firebog.net/hosts/lists.php?type=tick
my @BLOCKLIST_URLS = (
  "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt",
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts",
  "https://v.firebog.net/hosts/static/w3kbl.txt",
  "https://adaway.org/hosts.txt",
  "https://v.firebog.net/hosts/AdguardDNS.txt",
  "https://v.firebog.net/hosts/Admiral.txt",
  "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt",
  "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt",
  "https://v.firebog.net/hosts/Easylist.txt",
  "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext",
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts",
  "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts",
  "https://v.firebog.net/hosts/Easyprivacy.txt",
  "https://v.firebog.net/hosts/Prigent-Ads.txt",
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts",
  "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt",
  "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt",
  "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt",
  "https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt",
  "https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt",
  "https://v.firebog.net/hosts/Prigent-Crypto.txt",
  "https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt",
  "https://phishing.army/download/phishing_army_blocklist_extended.txt",
  "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt",
  "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt",
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts",
  "https://urlhaus.abuse.ch/downloads/hostfile/",
  "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser"
);


sub uniq {
  my %seen;
  grep !$seen{$_}++, @_;
}


sub fetch_blocklists {
  my $ua = HTTP::Tiny->new;
  my $fh;
  open($fh, '>>', $tmp_file) or die("Can't open $fh");

  for (@_) {
    print($fh $ua->get($_)->{content}) or print(STDERR "Failed to download from $_");
  }

  close($fh) or die("Can't close $fh");
}


sub format_blocklist {
  my $fh;
  open($fh, '<', $tmp_file) or die("Can't open $fh");

  # https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch08s15.html
  #
  # Somewhat malformed URLs (hyphens, underscores, uppercase, and
  # numbers in places they shouldn't be) are accepted to catch those
  # using resolvable out-of-spec domain names to evade regular
  # expressions.
  my $domain_regexp = '\b((?=[a-zA-Z0-9-_]+\.)[a-zA-Z0-9-_]+([a-zA-Z0-9-_]+)*\.)+[a-zA-Z0-9-_]+\b';
  my @domains;

  while (<$fh>) {
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
        next if ($& =~ m/^([0-9]{1,3}\.)+([0-9]{1,3})$/);

        # Convert any accepted uppercase to lowercase, since DNS is
        # case-insensitive anyway.
        $domains[++$#domains] = lc($&);
      }
    }
  }

  close($fh) or die("Can't close $fh");


  my $ofh;
  open($ofh, '>', $out_file) or die("Can't open $ofh");
  my @unique_domains = uniq(@domains);

  if ($format =~ m/^unbound$/) {
    print($ofh "local-zone: \"$_\" always_refuse\n") for (sort(values(@unique_domains)));
    print($ofh "local-zone: \"use-application-dns.net\" always_refuse\n");
  }

  elsif ($format =~ m/^plain$/) {
    print($ofh "$_\n") for (sort(values(@unique_domains)));
    print($ofh "use-application-dns.net\n");
  }


  close($ofh) or die("Can't close $ofh");
}


fetch_blocklists @BLOCKLIST_URLS;
format_blocklist;
