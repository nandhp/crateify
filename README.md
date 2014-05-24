Crateify packages files within a directory tree into compressed,
encrypted tar "crates" that can be easily uploaded to free cloud
storage accounts.

It is a fork of [crateify by Jonathan
Kamen](http://stuff.mit.edu/~jik/software/crateify.pl.txt).

* Configuration is stored in a separate file
* Unencrypted crates are never written to the disk
* Throttle mode, for less noticible CPU impact when running from cron
* New metadata file `uptodate`, listing size (bytes) of up-to-date data
  in each crate
* Scripts (send-crates-rsync and clean-crates) to manage the sending
  of crates to multiple destinations
