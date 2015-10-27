#!/usr/bin/perl

=head1 NAME

send-crates-rsync.pl - Transfer crates using rsync

=head1 SYNOPSIS

send-crates-rsync.pl [options] <dest> [rsync options]

=head1 DESCRIPTION

B<send-crates-rsync.pl> transfers crates to a remote location using
L<rsync(1)>. Transferred crates are recorded in a log file to allow
L<clean-crates.pl> to delete the original copy after being transferred
to all destinations.

=head1 OPTIONS

=over

=item --config=I<file>

Configuration file (default F<~/.crateify>)

=item --quiet

Print less output.

=item --turtle=I<speed>

Limit transfer rate (rsync --bwlimit) in when turtle mode.

=item --ping=I<time>

Only enable turtle mode if ping time exceeds threshold. If not
specified, turtle mode will always be used if requested.

=item I<rsync options>

Will be passed directly to the L<rsync(1)> subprocess.

=back

=head1 EXAMPLES

    rsync-crates.pl --turtle 5 --ping 8 $HOME/.crateify remote-host: \
        --rsh="ssh -i $HOME/.ssh/crate-rsync.key -o IdentitiesOnly=yes"

    rsync-crates.pl $HOME/.crateify /media/usb1/crates/

=head1 COPYRIGHT

Copyright (c) 2013-2014 nandhp <nandhp@gmail.com>.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

=cut

use Getopt::Long qw(:config no_auto_abbrev require_order pass_through);
use Pod::Usage;
use Fcntl qw(:flock SEEK_END SEEK_SET);
use File::Basename;
use FindBin;
use warnings;
use strict;

# Receive rsync options and destination from command-line
my %opts = ();
my $config = "$ENV{HOME}/.crateify";
GetOptions(\%opts, 'config=s' => \$config,
           'quiet', 'turtle=i', 'ping:i') or pod2usage(2);
my $dest = shift @ARGV;
my @opts = @ARGV;
my $verbose = !$opts{quiet};

pod2usage(2) if !$dest or $dest =~ m/^-/;

# Load configuration file
our ($backup_dir, $data_dir, $gpg_dir, $gpg_key, $archive_size,
     @include, @exclude, $compressor, $cratedigits);
do $config;

# Find crates and sent-crate lists
(my $tag = $dest) =~ s/[^-_.A-Za-z0-9]+/-/g;
$tag =~ s/^-|-$//g;
my $dbfile = "$data_dir/sent-crates-$tag";
my @crates = glob "$data_dir/crate-" . ("[0-9]" x $cratedigits) . '.tar*';

# File locking (from perldoc -f flock)
sub lock {
    my ($fh) = @_;
    flock($fh, LOCK_EX|LOCK_NB) or return 0;
    # and, in case someone appended while we were waiting...
    #seek($fh, 0, SEEK_END) or die "Can't seek: $!";
    return 1;
}
sub unlock {
    my ($fh) = @_;
    flock($fh, LOCK_UN) or die "Can't unlock file: $!";
}

# Parse destination
my ($host) = $dest =~ m/(?:@|^)([^:@\/]*)(?:$|:)/;

# Lock the database file
die "Database file $dbfile does not exist.\n" unless -f $dbfile;
open my $dbfh, '+>>', $dbfile or die "Can't open $dbfile: $!";
if ( !lock($dbfh) ) {
    warn "Can't lock $dbfile\n" if $verbose;
    exit 1;
}

# Load the database
my %db = ();
seek($dbfh, 0, SEEK_SET) or die "Can't seek: $!";
while (<$dbfh>) {
    m/(\S+)/ and $db{basename($1)} = 1;
}
# Omit crates that are already sent
for ( my $i = 0; $i < @crates; $i++ ) {
    my $basefn = basename($crates[$i]);
    if ( $basefn =~ m/tmp$/ or $db{$basefn} ) {
        print "Database shows $basefn already sent\n"
            if $verbose and $db{$basefn};
        splice @crates, $i, 1;
        redo if $i < @crates;
    }
}

# If there are no crates to send, do nothing.
if ( !@crates ) {
    print "(Nothing to do)\n" if $verbose;
    exit 0;
}

# Check on the turtle thing
if ( !$host ) { }       # Local destination; no turtle or ping support
elsif ( defined($opts{ping}) ) {
    open my $ping, '-|', 'sh', '-c', 'ping -c5 "$1" 2>/dev/null', '-', $host
        or die "Can't run ping: $!";
    my $time = undef;
    while (<$ping>) {
        $time=int($1) if m/rtt min.*?([-.0-9]+)/;
    }
    close $ping;
    if ( !defined($time) ) {
        print "No ping reply from $host\n" if $verbose;
        exit 1;
    }
    elsif ( $opts{turtle} and $time >= ($opts{ping}||0) ) {
        unshift @opts, "--bwlimit=$opts{turtle}";
    }
}
elsif ( $opts{turtle} ) { unshift @opts, "--bwlimit=$opts{turtle}" }

# Additional options
unshift @opts, $verbose ? '--progress' : '-i';

system 'ls', '-gGh', @crates;   # -gG is -l without user and group (<80cols)

# Send the crates
my $start = time;
my $rc = system 'rsync', '--partial', '--partial-dir=.rsync-partial',
    '-a', @opts, '--', @crates, $dest;
my $dur = time-$start;
printf "%s in %dm%02ds\n", $rc == 0 ? 'Completed' : 'Failed', $dur/60, $dur%60;
die "rsync failed; system returned $rc" unless $rc == 0;

# Transfer was successful: add the transferred crates to the database file
print $dbfh File::Spec->rel2abs($_, $data_dir), "\n" foreach @crates;
unlock($dbfh);
close($dbfh) or die "Can't close $dbfile: $!";

# Files were transferred; run clean-crates
@opts = ('--config', $config);
unshift @opts, '--quiet' unless $verbose;
system "$FindBin::Bin/clean-crates.pl", @opts;
