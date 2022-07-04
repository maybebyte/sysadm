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

# Sync Upload Date and Access Time

use strict;
use warnings;
use v5.14; # character interpretation

# Extract file name.
use File::Basename;

# Decode JSON and manipulate it with Perl.
use JSON::MaybeXS;

# Convert a given date to seconds since the epoch.
use Time::Local;

my $program_name = fileparse $0;

sub usage {
	die <<"EOT";
Sync Upload Date and Access Time (sudat):
$program_name [file_to_update] [...]

Note that $program_name extracts the upload date from .info.json files
provided by yt-dlp(1). .info.json files MUST be identically named to
file_to_update except for the extension.
EOT
}


sub make_file_template {
	my $file_with_extensions = shift;

	# This contains all anticipated extensions. A more liberal regular
	# expression runs the risk of oversight (accidentally matching more
	# than was intended--easy to do) and introducing unnecessary
	# complexity.
	my $extension_regexp = "(webm|mkv|mp4|info\.json|description)";

	$file_with_extensions =~ s/\.$extension_regexp\z//g;
	my $file_without_extensions = $file_with_extensions;

	return $file_without_extensions;
}


sub get_upload_date {
	my $file_to_process = shift;
	my $file_template = make_file_template $file_to_process;
	my $info_json_file = "$file_template.info.json";

	open my $info_json_fh, '<', $info_json_file or die "Could not open $info_json_file: $!";
	my $info_json = <$info_json_fh>;
	close $info_json_fh;

	my $decoded_json = decode_json $info_json;
	my $upload_date = ${$decoded_json}{'upload_date'};
	return $upload_date;
}


sub upload_date_to_epoch {
	my $file_to_process = shift;
	my $upload_date = get_upload_date $file_to_process;

	$upload_date =~ /\A\d{8}\z/a or die "Upload date is not eight digits long\n";

	my $year = substr $upload_date, 0, 4;
	my $month = substr $upload_date, 4, 2;
	my $day = substr $upload_date, 6, 2;

	# The month field is the number of months since January, from 0-11.
	return timelocal 0, 0, 0, $day, $month - 1, $year;
}


@ARGV or usage;

while (@ARGV) {
	my $file_to_process = shift;
	my $file_template = make_file_template $file_to_process;
	my $since_the_epoch = upload_date_to_epoch $file_to_process;

	for ($file_to_process, "$file_template.info.json", "$file_template.description") {
		utime $since_the_epoch, $since_the_epoch, $_;
	}
}
