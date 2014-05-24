#!/usr/bin/perl

=pod

=head1 NAME

crateify.pl - Package up files for backing up in the cloud

=head1 SYNOPSIS

crateify.pl [options]

=head1 DESCRIPTION

This script packages files within a directory tree into compressed,
encrypted tar "crates" that can be easily uploaded to free cloud
storage accounts, providing a sort of poor-man's cloud backup
solution.

The files are packaged in chronological order, i.e. oldest files
first, to minimize the frequency with which you have to rebuild
crates. Files that are updated between runs of the script are
repackaged in new crates.

=head1 CONFIGURATION SETTINGS

The following variables can and should be set in a configuration file
before you use this script:

=over

=item $backup_dir

The directory whose contents should be crated.

Note that files with newlines in their names will not be crated.

=item $data_dir

The directory in which crates and associated metadata files should be
stored.

=item $gpg_dir

The directory in which the keyring containing your GPG key (used to
encrypt the crates for safe storage online) is stored.

=item $gpg_key

The identifier of the GPG key that should be used to encrypt the
crates.

B<NOTE:> Make sure you have copies of your public and private GPG keys
backed up somewhere safe I<not> inside a crate. If your computer
crashes and you need to restore from your backup, it won't do any good
if you can't decrypt it!

=item $archive_size

The (pre-compression, pre-encryption) size of each crate, in
bytes. A crates can end up being much bigger than this if the last
file inserted into it is large.

=item $compressor

The compression method to use for compressing the crates. Supported
compression methods include gzip, bzip2, and xz.

=item $cratedigits

Number of digits to use when naming crates (crate-I<#####>)

=item @exclude

Regular expressions (relative to the root of I<$backup_dir>) of
directories and files to be excluded from crating.

Here's a trick I use to find out what's taking up space in my crates:

 cd $backup_dir
 sed -e 's/ [0-9]*$//' $data_dir/crate-##### | xargs -d '\n' ls -lSr

This lists the files in the specific crate, in size order, so you an
see what's taking up a lot of space. I do this whenever my nightly
backup report email tells me that a larger than expected crate was
built.

Note that I personally do not back up my "live" hard drive, but rather
a mirror hard drive maintained with rdiff-backup. Therefore, most of
the files I would not want/need to crate are already excluded from my
I<$backup_dir>, which is why my @exclude list is so short.

If you I<do> backup of your live hard drive, then make sure you
exclude cloud storage directories, e.g., ~/Dropbox, especially if you
store crates in them! Otherwise, you'll create a loop where each time
you create new crates in a backup, your old crates will be included in
them, which would obviously be Very Bad.

If you specify both @exclude and @include, then @include is applied
first and @exclude is applied to what's left.

=item @include

Regular expressions (relative to the root of I<$backup_dir>) of
directories and files to be included in crating.

If you specify both @exclude and @include, then @include is applied
first and @exclude is applied to what's left.

=back

=head1 OPTIONS

=over

=item --config=I<file>

Configuration file (default F<~/.crateify>)

=item --crates=I<number>

Produce (at most) te specified number of crates, rather than just one
new crate, which is the default.

This is faster when you want to produce multiple crates, since it
won't have to rescan the entire backup directory for each one.

=item --full

Create enough crates to hold everything that currently needs to be
crated.

=item --scan

Update meta-data files (see below) without building any new crates.

=item --quiet

Don't print warnings about updated or deleted files in existing
crates.

=back

=head1 COMPACTING CRATES

The early crates you build will probably be relatively static,
assuming that you have a lot of old data that isn't likely to change
anymore.

However, over time your crates will accumulate files that are obsolete
because they've been deleted or updated versions have been packed into
newer crates. Each time you run it, the script prints warnings about
such files. The total size of the non-obsolete files in each crate is
listed in the uptodate file.

You will probably want to occasionally "compact" your crates to remove
such obsolete files. To do this, simply remove the corresponding
crate-I<#####> files from I<$data_dir>, and the corresponding compressed,
encrypted tar files from wherever you put them, and the script will
repack the files that were in those crates the next time you run it.

=head1 METADATA FILES

The script creates the following meta-data files:

=over

=item crate-I<#####>

Listings of the files in each crate. The script needs these to work,
so you should leave them in I<$data_dir> even if you move the crates
themselves into the cloud.

=item deleted

A list of the crated files that have been deleted since they were
crated.

=item updated

A list of the crated files that have been updated since they were
crated, i.e., files that have obsolete versions in one or more crates,
and will also, if your crates are up-to-date, have a I<current>
version in one crate.

=item packing_list

Temporary file created and used while packing crates. It should not
exist between successful runs of the script, but you shouldn't create
a file with this name in I<$data_dir> or it'll get overwritten.

=item excludes

A list of all the files in all of the crates, intended to be used to
exclude those files from some I<other> backup system.

Suppose you want to use this script to back up your old, static files
that never change, but you'd rather use some other backup system to
back up frequently changing files. To do that, you would tell the
other backup system to exclude the files listed in
I<$data_dir>/excludes.

For example, if you use rsync to backup frequently changing files to a
remote filesystem, then you can tell it to "--exclude-from
I<$data_dir>/excludes".

=item uptodate

A list of crates, with the total size (in bytes) of contained files
that are not obsolete. A crate listed with up-to-date size 0 contains
only obsolete files.

=back

=head1 WHERE TO PUT THE CRATES

The crates you build with this script obviously don't do much good as
a backup if they sit on the same drive as the files being backed
up. Here are some examples of what you can do with them to turn them
into a real backup.

=over

=item *

Stick an extra hard drive (internal or external) into your system and
put your crates on it. This won't do you much good if your house burns
down or somebody steals your computer, but it'll at least protect you
against drive failure.

=item *

Make a deal with a friend -- he lets you use unused space on his
hard disk to scp your crates to every night when you back up, and vice
versa.

=item *

Free cloud storage! See L<http://blog.kamens.us/?p=2504> for a list of
cloud storage platform which will give you a total of 50GB of free
storage just for asking. You can store a lot of crates in 50GB!

=item *

Upload them to Amazon S3 or some other commercial cloud storage
service.

=back

Personally, I have uploaded most of my crates, the ones containing
older files that change rarely if ever, by hand to free accounts on
SkyDrive and LetScrate. Then, my nightly backup puts new crates in my
Dropbox folder, so they get synchronized to the cloud
automatically. Occasionally, I compact the Dropbox crates as described
above and move some of the compacted crates SkyDrive or LetsCrate as
needed.

=head2 What if a crate is too big?

You probably have some really huge files (home videos, anyone?) that
you want to back up. Since this script doesn't split files between
crates, any crate containing a really huge file is going to be really
huge itself.

Depending on where you store your crates, this may present a problem,
since some cloud storage services limit the size of uploaded files.

The easiest solution is to split big crates before uploading it. For
example:

  split -b 50000000 -d crate-#####.tar.bz2.gnupg crate-#####.tar.bz2.gnupg. && \
  rm crate-#####.tar.bz2.gnupg

The name of the crate is specified to the "split" command a second
time with a period at the end of it as the file-name prefix for the
split files that are produced.

If you ever need to restore from a split crate, you can cat all of the
split files directly into gpg, something like this:

  cat crate-#####.tar.bz2.gnupg.* | gpg | tar xj

=head1 DOING A RESTORE

If you can't figure out on your own how to restore from the crates
produced by this script, then you probably shouldn't use it. CrashPlan
is a pretty nice service, and it's very inexpensive. :-)

Having said that...

To restore from a set of crates, you decrypt and untar all the crates
in order (preferably as root, so that read-only, updated files can be
overwritten) and then remove the ones listed in the "deleted" file.

Alternatively, if you just need to restore a specific file, you can
look through the crate-I<#####> files in reverse order to find the
file you want, and then extract it from the corresponding crate.

=head1 WHAT THIS SCRIPT ISN'T

This script isn't really intended to preserve historical versions of
files or to allow you to recover files that were deleted long ago. It
sort of does that if you never compact your crates, but that'll eat up
a lot of extra storage space for files that change regularly.

Therefore, if you want access to a historical record of your files, as
opposed to an emergency recovery snapshot of what you've got on disk
right now, this probably isn't the right tool for you.

=head1 AUTHOR

This script was written and is maintained by Jonathan Kamens
E<lt>jik@kamens.usE<gt>.

Please let me know if you have questions, comments or suggestions!

Modified by nandhp <nandhp@gmail.com> to use a separate configuration
file and to avoid writing unencrypted crates to the disk.

=head1 OTHER FREE BACKUP SOLUTIONS

I won't lie to you... It takes work to set up and use this script for
backups. If you're the kind of do-it-yourselfer who likes stuff like
this, great, but if not, you might be asking yourself, "Are there
other options for backing up my Linux box for free?"

There are probably quite a few of them, but if you have one that's
you're favorite please free to email me email me and I'll add it here,
but here's the one I like...

=head2 CrashPlan

CrashPlan (L<http://crashplan.com/>), which I've mentioned elsewhere
in this document, will let you back up an unlimited amount of data to
their servers for $3.00 per month. This is neat, but they'll also let
use their easy-to-use software for free to back up your data to your
own server instead of theirs.

"How is that free?" you're asking? Well, if you can find a friend with
an Internet connection (who doesn't?) and some extra hard drive space
(hard drives are I<really> cheap nowadays!), you can back up your
system on his hard drive, and I<vice versa>. Both of you need to
install the CrashPlan software on your systems and open up your
firewalls to allow access to it, and that's it. You can configure
CrashPlan to limit the amount of bandwidth it uses so it won't max out
your Internet connection (in fact, it comes configured that way by
default). The one caveat is that if you ever do need to do a restore,
it'll probably take longer from your friend's computer than it would
from something in the cloud, since most home Internet connections have
a slower uplink speed than downlink.

=head1 DONATIONS

This script is and always will be free for you to use or modify as you
see fit. Having said that, it took me time to write the script, and it
takes me time to support the people using it. So if you do use it and
save yourself some money, please consider showing your appreciation by
sending me a donation at
L<http://blog.kamens.us/support-my-blog/>. Any donation, large or
small, is appreciated!

=head1 COPYRIGHT

Copyright (c) 2011 Jonathan Kamens.
Copyright (c) 2013-2014 nandhp <nandhp@gmail.com>.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

The original version of this script (Jonathan Kamen's version) is
available from L<http://stuff.mit.edu/~jik/software/crateify.pl.txt>.

=cut

use strict;
use warnings;

use File::Find;
use File::stat;
use Getopt::Long;
use Pod::Usage;

my $scan = undef;
my $crates = undef;
my $quiet = undef;
my $full = undef;
my $throttle = undef;

my $config = "$ENV{HOME}/.crateify";
pod2usage(2) if !GetOptions(
    'config=s' => \$config,
    "scan" => \$scan,
    "crates=i" => \$crates,
    "quiet" => \$quiet,
    "full" => \$full,
    "throttle=i" => \$throttle,
    "help|?" => sub { pod2usage(1) }) or @ARGV;

die "Don't specify both --crates and --full\n" if ($crates and $full);
$crates = 1 if (! ($crates or $full));

# Load configuration file
our ($backup_dir, $data_dir, $gpg_dir, $gpg_key, $archive_size,
    @include, @exclude, $compressor, $cratedigits);
do $config or die "Can't read $config: $!\n";

# Compressor configuration
my %compressors = ('gzip' => 'gz', 'bzip2' => 'bz2', 'xz' => 'xz');

# Where to save the list of files that have been deleted since they
# were crated. You can use this list during a restore to find out
# which files you should remove after unpacking all of the tar
# archives. You shoudn't need to change this.
my $deleted_list = "$data_dir/deleted";

# Temporary file used to store the contents of each crate as it is
# crated. You shouldn't need to change this.
my $packing_list = "$data_dir/packing_list";

# List of all files packaged in all crates, updated each time the
# script is run, to be used to exclude crated files from other backup
# mechanisms.
my $exclude_list = "$data_dir/excludes"; # Exclude from nightly backup

# List of all files in all crates that have been updated since they
# were crated.
my $updated_list = "$data_dir/updated";

# List of crates, with the number of bytes in each that remains up-to-date.
my $uptodate_list = "$data_dir/uptodate";

# Build hash of all candidate files

my %on_disk;
my $nfiles = 0;

sub wanted {
    my $name = $File::Find::name;
    $name =~ s/..//; # get rid of ./ at beginning
    if ($name =~ /\n/) {
	$File::Find::prune = 1;
	return;
    }
    my $do_not_include;
    if (@include) {
	$do_not_include = 1;
	foreach my $re (@include) {
	    if ($name =~ /$re/) {
		$do_not_include = undef;
		last;
	    }
	}
    }
    # For efficiency, we check the exclude list even if we already
    # know this particular file doesn't match @include, because it may
    # be that @exclude says we should exclude an entire tree, so
    # excluding it from further review will make things run faster.
    if (grep($name =~ /$_/, @exclude)) {
	$File::Find::prune = 1;
	return;
    }
    return if ($do_not_include);
    my $st = lstat($_);
    return if (! -f $st);
    $on_disk{$name} = $st;
    $nfiles++;
    sleep(1) if $throttle and $nfiles % $throttle == 0;
}

chdir($backup_dir) || die;

find(\&wanted, ".");
print "Found $nfiles files\n";

# Build hash of all crates that have already been uploaded

my %in_crate;
my $last_crate;
my %crate_valid_size;

foreach my $crate (glob "$data_dir/crate-".("[0-9]"x$cratedigits)) {
    $last_crate = $crate;
    open(CRATE, "<", $crate) or die;
    while (<CRATE>) {
	chomp;
	s/ (\d+)$//;
	$in_crate{$_} = [$crate, $1];
    }
    $crate_valid_size{$crate} = 0;
}

# Figure out which files have been deleted

open(DELETED, ">", "$deleted_list.tmp") or die;
foreach my $in (sort keys %in_crate) {
    my $crate = $in_crate{$in}->[0];
    if (! $on_disk{$in}) {
	print "DELETED: $in from $crate\n" if (! $quiet);
	print(DELETED "$in from $crate\n") or die;
    }
}
close(DELETED) or die;
rename("$deleted_list.tmp", $deleted_list) or die;

# Exclude files that have not been updated

open(EXCLUDES, ">", "$exclude_list.tmp") or die;
open(UPDATED, ">", "$updated_list.tmp") or die;
foreach my $in (sort keys %in_crate) {
    my $crate = $in_crate{$in}->[0];
    my $stamp = $in_crate{$in}->[1];
    next if (! $on_disk{$in}); # deleted
    if ($stamp != $on_disk{$in}->mtime) {
	print(UPDATED "$in from $crate\n") or die;
	print "UPDATED: $in from $crate\n" if (! $quiet);
    }
    else {
	print(EXCLUDES $in, "\n") or die;
	delete $on_disk{$in};
        $crate_valid_size{$crate} += -s $in;
    }
}
close(UPDATED) or die;
rename("$updated_list.tmp", $updated_list) or die;

open(UPTODATE, '>', "$uptodate_list.tmp") or die;
foreach my $crate ( sort { $crate_valid_size{$a} <=> $crate_valid_size{$b} }
                    keys %crate_valid_size ) {
    print UPTODATE "$crate $crate_valid_size{$crate}\n";
}
rename("$uptodate_list.tmp", $uptodate_list) or die;

sub make_crate {
    # Find next crate number to use

    my $crate_format = "$data_dir/crate-%0" . $cratedigits . 'd';
    my($crate_index, $crate_basename);
    if ($last_crate) {
	$last_crate =~ /(\d+)$/ or die;
	$crate_index = $1 + 1;
    }
    else {
	$crate_index = 1;
    }
    $crate_basename = sprintf($crate_format, $crate_index);
    $last_crate = $crate_basename;
    print "NEXT CRATE: $crate_basename\n" if (! $quiet);

    # Create a packing list

    my $total_size = 0;
    open(PACK, ">", $packing_list) or die;
    foreach my $file (sort { $on_disk{$a}->mtime <=> $on_disk{$b}->mtime }
		      keys %on_disk) {
	print(PACK $file, "\n") or die;
	$total_size += $on_disk{$file}->size;
	$in_crate{$file} = [$crate_basename, $on_disk{$file}->mtime];
	delete $on_disk{$file};
	print(EXCLUDES $file, "\n") or die;
	if ($total_size > $archive_size) {
	    print "FULL: $total_size > $archive_size\n" if (! $quiet);
	    last;
	}
    }
    close(PACK) or die;

    return 0 if (! $total_size);

    # Tar it up
    my $use_gpg = $gpg_dir && $gpg_key;
    my $tar_file = "$crate_basename.tar.$compressors{$compressor}";
    my(@cmd) = ("tar", "--create", "--$compressor",
                "--files-from", $packing_list,
                "--file", $use_gpg ? '-' : $tar_file);
    print "TARRING: @cmd\n" if (! $quiet);

    if ( $use_gpg ) {
        my $tarpid = open TAR, '-|', @cmd or die "Opening tar: $!";
        system("cpulimit --limit=20 --background --pid=$tarpid " .
               '>/dev/null 2>&1')
            if $throttle;
        binmode(TAR);
        my ($gpg_file, $tmp_file) = ("$tar_file.gpg", "$tar_file.tmp");
        -f $tmp_file and unlink $tmp_file;
        @cmd = ("gpg", "--batch", "--homedir", $gpg_dir, "--encrypt",
                "--default-key", $gpg_key, "--default-recipient", $gpg_key,
                "--no-permission-warning",
	        "--output", $tmp_file);
        print "ENCRYPTING: @cmd\n" if (! $quiet);
        #system(@cmd) and die;
        open GPG, '|-', @cmd or die "Opening gpg: $!";
        binmode(GPG);
        my ($bufsize, $buf, $rc) = (1048576,'', 0);
        print GPG $buf while $rc = read(TAR, $buf, $bufsize);
        die unless defined $rc;
        close TAR or die "Closing tar($?): $!";
        close GPG or die "Closing gpg($?): $!";
        rename $tmp_file, $gpg_file;
        -f $gpg_file or die "$gpg_file does not exist\n";
        #unlink($tar_file) or die;
    }
    else {
        warn "Not encrypting $tar_file\n";
        system(@cmd) and die;
        -f $tar_file or die "$tar_file does not exist\n";
    }

    # Save the crate file

    open(CRATE, ">", "$crate_basename.tmp") or die;
    open(PACK, "<", $packing_list) or die;
    while (<PACK>) {
	chomp;
	print(CRATE $_, " ", $in_crate{$_}->[1], "\n");
    }
    close(PACK) or die;
    close(CRATE) or die;
    rename("$crate_basename.tmp", $crate_basename) or die;
    print "CRATED: $crate_basename\n" if (! $quiet);
    unlink($packing_list);

    return 1;
}

if (! $scan) {
    while ($full or $crates-- > 0) {
	last if (! &make_crate);
    }
}

close(EXCLUDES) or die;
rename("$exclude_list.tmp", $exclude_list) or die;
