#!/usr/bin/perl

=head1 NAME

clean-crates.pl - Delete crates that have been sent to all destinations

=head1 SYNOPSIS

clean-crates.pl [options]

=head1 OPTIONS

=over

=item --config=I<file>

Configuration file (default F<~/.crateify>)

=item --quiet

Print less output.

=item --dry-run, --no-act, -n

Don't actually delete any files.

=back

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

use Getopt::Long;
use Pod::Usage;
use Fcntl qw(:flock SEEK_END SEEK_SET);
use File::Basename;
use File::Spec;
use warnings;
use strict;

# Receive rsync options and destination from command-line
my %opts = ();
my $config = "$ENV{HOME}/.crateify";
pod2usage(2) if !GetOptions(\%opts,
                            'config=s' => \$config,
                            'quiet|q', 'dry-run|no-act|n',
                            'help|?' => sub { pod2usage(1) }) or @ARGV;
my $dryrun = $opts{'dry-run'};
my $verbose = !$opts{quiet} || $dryrun;

# Load configuration file
our ($backup_dir, $data_dir, $gpg_dir, $gpg_key, $archive_size,
     @include, @exclude, $compressor, $cratedigits);
do $config or die "Can't read $config: $!\n";

# File locking (from perldoc -f flock)
sub lock {
    my ($fh) = @_;
    flock($fh, LOCK_EX|LOCK_NB) or return 0;
    # and, in case someone appended while we were waiting...
    seek($fh, 0, SEEK_SET) or die "Can't seek: $!";
    return 1;
}
sub unlock {
    my ($fh) = @_;
    flock($fh, LOCK_UN) or die "Can't unlock file: $!";
}

# Load databases
opendir(my $dirfh, $data_dir) or die "Can't open crate directory: $!";
my @dblist = grep { /^sent-crates-/ && !m/~$/ } readdir($dirfh);
closedir($dirfh);
my @dbfh = ();
foreach ( @dblist ) {
    open my $fh, '+<', "$data_dir/$_" or die "Can't open $_: $!";
    if ( !flock($fh, LOCK_EX|LOCK_NB) ) {
        warn "$0: Can't lock $_\n" if $verbose;
        close $fh;
        last;
    }
    seek($fh, 0, SEEK_SET) or die "Can't seek: $!";
    push @dbfh, $fh;
}

# Release locks
sub release {
    foreach my $fh ( @dbfh ) {
        flock($fh, LOCK_UN) or die "funlock: $!";
        close($fh) or die "close: $!";
    }
}
# All files opened and locked successfully?
if ( @dbfh != @dblist ) {
    release();
    exit 1;
}

# Load the databases
my %db = ();
foreach my $fh ( @dbfh ) {
    while (<$fh>) {
        m/(\S+)/ or next;
        my $abspath = File::Spec->rel2abs($1, $data_dir);
        next unless -f $abspath;
        $db{$abspath}++;
    }
}

# Check for, and delete, finished files
foreach ( sort keys %db ) {
    my $basefn = basename $_;
    die unless $basefn =~ m/\.tar/;
    print "$basefn: " if $verbose;
    if ( $db{$_} == @dblist ) {
        printf("Removing; transferred to %d locations\n",
               $db{$_}) if $verbose;
        if ( !$dryrun ) { unlink $_ or die "unlink $_: $!" }
    }
    elsif ( $db{$_} > @dblist ) {
        printf("Error: transferred to %d locations, but only %d possible?\n",
               $db{$_}, @dblist);
    }
    else {
        printf("Holding for transfer to %d more locations\n",
               @dblist-$db{$_}) if $verbose;
    }
}
print "(Nothing happened: dry run)\n" if $dryrun;

release();
exit 0;
