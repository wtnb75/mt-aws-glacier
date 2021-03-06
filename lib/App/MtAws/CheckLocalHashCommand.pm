# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2013  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

package App::MtAws::CheckLocalHashCommand;

use strict;
use warnings;
use utf8;
use Carp;
use App::MtAws::Utils;
use App::MtAws::TreeHash;
use App::MtAws::Exceptions;
use File::stat;

sub run
{
	my ($options, $j) = @_;
	$j->read_journal(should_exist => 1);
	my $files = $j->{journal_h};
	
	my ($error_hash, $error_size, $error_missed, $error_mtime, $no_error, $error_io) = (0,0,0,0,0,0);
	for my $f (keys %$files) {
		my $file=$files->{$f};
		my $absfilename = $j->absfilename($f);
		
		if ($options->{'dry-run'}) {
			print "Will check hash file $f\n"
		} else {
			my $th = App::MtAws::TreeHash->new();
			my $binaryfilename = binaryfilename $absfilename;
			if (-f $binaryfilename ) {
				unless (-s $binaryfilename) {
					print "ZERO SIZE $f\n";
					++$error_size;
					next;
				}
				my $F;
				unless (open_file($F, $absfilename, mode => '<', binary => 1)) {
					print "CANNOT OPEN file $f: $!\n";
					++$error_io;
					next;
				}
				$th->eat_file($F); # TODO: don't calc tree hash if size differs!
				close $F or confess;
				$th->calc_tree();
				1;
				my $treehash = $th->get_final_hash();
				if (defined($file->{mtime}) && (my $actual_mtime = stat($binaryfilename)->mtime) != $file->{mtime}) {
					print "MTIME missmatch $f $file->{mtime} != $actual_mtime\n";
					++$error_mtime;
				}
				if (-s $binaryfilename == $file->{size}) {
					if ($treehash eq $files->{$f}->{treehash}) {
						print "OK $f $files->{$f}->{size} $files->{$f}->{treehash}\n";
						++$no_error;
					} else {
						print "TREEHASH MISSMATCH $f\n";
						++$error_hash;
					}
				} else {
						print "SIZE MISSMATCH $f\n";
						++$error_size;
				}
			} else {
					print "MISSED $f\n";
					++$error_missed;
			}
		}
	}
	unless ($options->{'dry-run'}) {
		print "TOTALS:\n$no_error OK\n$error_mtime MODIFICATION TIME MISSMATCHES\n$error_hash TREEHASH MISSMATCH\n$error_size SIZE MISSMATCH\n$error_missed MISSED\n$error_io ERRORS\n";
		print "($error_mtime of them have File Modification Time altered)\n";
		die exception(check_local_hash_errors => 'check-local-hash reported errors') if $error_hash || $error_size || $error_missed || $error_io;
	}
}

1;

__END__
