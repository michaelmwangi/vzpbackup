vzpbackup
=========

OpenVZ Container Backup - for containers using ploop storage

The scripts are meant to provide a backup solution to backup
containers that use ploop storage. Traditional storage is
not supported by the scripts. The scripts are based on the
OpenVZ wiki page regarding image backup:
[http://openvz.org/Ploop/Backup](http://openvz.org/Ploop/Backup)

## BACKUP: vzpbackup.sh

```
Usage: ./vzpbackup.sh
	[--suspend=<yes/no>]
	[--backup-dir=<Backup-Directory>]
	[--work-dir=<Temp-Directory>]
	[--filename=<final name of the file>]
	[--compress=<no/pz/bz/pbz/tbz/gz/tgz/xz/txz>]
	[--compact]
	[--all]
	<CTID> <CTID>
```

Backup a container with container ID 200:

vzpbackup.sh --suspend=yes --compress=gz 200

Options:

--suspend=\<yes/no> (Default: no)

	This will result in calling vzctl snapshot without the
	parameter "--skip-suspend" resulting in a snapshot of
	the running container being included in the backup.
	If you restore that backup using vzprestore.sh, you can
	resume the container after the restore has finished.

--backup-dir=\<Directory> (Default: /store/vzpbackup)

	Parameter to change the default backup directory. Either
	use the parameter or change the script. The temporary
	files created (The backup tar file for example) will be 
        created in this directory.

--work-dir=\<Directory> (Default: /store/vzpbackup)

	Parameter to change the default working directory. Either
        use the parameter or change the script.

--filename=\<File name> (Default: vzpbackup+_hostname_+CTID+_containerhostname_+timestamp)

	Parameter to change the default backup filename

--compact

	Runs vzctl compact for each container before initiating
	the backup

--compress=\<Compression> (Default: no(ne))

	Allows you to compress the resulting archive file using either
	bzip2, pigz, pbzip2, gzip or xz to save some disk space.

	Possible options:

	--compress=no  - No compression of backup archives
	--compress=pz  - Compress with pigz (needs to be installed)
	--compress=bz  - Compress with bzip2 (needs to be installed)
	--compress=tbz - Compress through tar command with bzip2
	--compress=gz  - Compress via gzip (needs to be installed)
	--compress=tgz - Compress through tar command with gzip
	--compress=xz  - Compress via xz (needs to be installed)
	--compress=txz - Compress through tar command with xz
	--compress=pbz - Compress with pbzip2 (needs to be installed)

--all

	This will backup _all_ containers that are currently
	configured on the host (Every container returned by
	"vzlist -Hoctid"). Currently there is no option to
	exclude specific CTIDs from the backup.

--exclude=\<CTID>

    Exclude specified CTID from being backed up. Most useful
    while using --all

## RESTORE: vzprestore.sh

```
Usage: ./vzprestore.sh
	[--ip=<New IP>]
	[--hostname=<New Hostname>]
	[--description="<New Description>"]
	[--vzdir=<Directory to restore VE_PRIVATE and VE_ROOT to>]
	[--confirm=<yes/no>]
	[--delete-backup-snapshot=<yes/no>]
	<Filename> <CTID>

You need to give at least <Filename> and <CTID> as arguments
```

Restore a backup to a new container 250:

vzprestore.sh /store/vzpbackup/vzpbackup_200_test.host.tar 250

Options:

--confirm=\<yes/no>

	Confirm what is being done prior execution.

--delete-backup-snapshot=\<yes/no>

	Delete (switch to it and delete it) the snapshot created during
        backup creation. Note: Any memory dumps will be lost if you do it
        at this stage after restoring the container.

--vzdir=\<VZ Directory for VE_PRIVATE and VE_ROOT>

        Instead of using the default VE_PRIVATE and VE_ROOT from the
        default OpenVZ configuration (/etc/vz/vz.conf), create the
        VE_ROOT and VE_PRIVATE in the directory given by the vzdir
        option

Requirements:

- OpenVZ virtual machines using ploop as storage
- uuidgen to create IDs for backups

Author: Andreas Faerber, af@maeh.org
