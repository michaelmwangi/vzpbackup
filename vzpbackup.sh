#!/bin/bash
#
# vzpbackup.sh
#
# A script to backup the containers running on an OpenVZ host.
# The container needs to utilize ploop as disk storage.
# Traditional storage is not supported by this script.
# The backup can be taken while the container is running.
#
# The script is based on the information on the ploop wiki page
# (http://openvz.org/Ploop/Backup) and has been developed based
# on that information.
#
# After reading the command line arguments the script will create a
# snapshot of the ploop device and backup it (via tar) to a
# configurable directory. It will always include the config file
# of the container backed up.
#
# Author: Andreas Faerber, af@maeh.org

##
## DEFAULTS
##

SUSPEND=no
BACKUP_DIR=/store/vzpbackup
WORK_DIR=/store/vzpbackup
COMPRESS=no
COMPACT=0
FILENAME

##
## VARIABLES
##

TIMESTAMP=`date '+%Y%m%d-%H%M%S'`
VZLIST_CMD=/usr/sbin/vzlist
VZCTL_CMD=/usr/sbin/vzctl
EXCLUDE=""
PREFIX="vzpbackup_"

## Add NODE hostname
PREFIX="$PREFIX`hostname -s`_"

## VARIABLES END

## FUNCTIONS

contains() {
    string="$1"
    substring="$2"

    case "$string" in
        *"$substring"*)
            return 1
        ;;
        *)
            return 0
        ;;
    esac

    return 0
}

show_usage() {
	echo -e "--------------------------------------------------------------------
Usage: $0
\t[--suspend=<yes/no>]
\t[--backup-dir=<Backup-Directory>]
\t[--work-dir=<Temp-Directory>]
\t[--filename=<final name of the backup file>]
\t[--compress=<no/pz/bz/pbz/tbz/gz/tgz/xz/txz>]
\t[--compact]
\t[--all]
\t<CTID> <CTID>
--------------------------------------------------------------------
Defaults:";
	show_param;
}

show_param() {
	echo "---";
	echo -e "SUSPEND: \t\t$SUSPEND"
	echo -e "BACKUP_DIR: \t\t$BACKUP_DIR"
	echo -e "WORK_DIR: \t\t$WORK_DIR"
    echo -e "FILENAME: \t\t$FILENAME"
	echo -e "COMPRESS: \t\t$COMPRESS"
	echo -e "COMPACT: \t\t$COMPACT"
	echo -e "CTIDs to backup: \t\t$CTIDS"
	echo -e "EXCLUDE CTIDs: \t\t$EXCLUDE"
	echo "---";
}
## FUNCTIONS END

## Get global and local config, if there exists
if [ -f "/etc/vz/vzpbackup.conf" ]; then
	source "/etc/vz/vzpbackup.conf";
fi
if [ -f "./vzpbackup.conf" ]; then
	source "./vzpbackup.conf";
fi


for i in "$@"
do
case $i in
    --help)
		show_usage;
		exit 0;
    ;;
    --suspend=*)
    	SUSPEND=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --exclude=*)
    	EXCLUDE="$EXCLUDE `echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
    ;;
    --backup-dir=*)
    	BACKUP_DIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
      	WORK_DIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --work-dir=*)
      	WORK_DIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --filename=*)
      	FILENAME=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --compress=*)
		COMPRESS=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
	;;
    --compact)
        COMPACT=1
    ;;
    --all)
    	CTIDS=`$VZLIST_CMD -a -Hoctid`
    ;;
    *)
		# Parse CTIDs here
		CTIDS=$CTIDS" "$i
    ;;
esac
done

show_param;


if [ "x$SUSPEND" != "xyes" ]; then
    CMDLINE="${CMDLINE} --skip-suspend"
fi
if [ -z "$CTIDS" ]; then
    echo ""
    echo "No CTs to backup (Either give CTIDs or --all on the commandline)"
    exit 0
fi

for i in $CTIDS
do

CTID=$i

contains "$EXCLUDE" $CTID
CONTAINS=$?

if [ $CONTAINS -eq 1 ]; then
    echo "Excluding CTID $CTID .."
    continue;
fi

# Check if the VE exists
if grep -w "$CTID" <<< `$VZLIST_CMD -a -Hoctid` &> /dev/null; then
        if [ $COMPACT == 1 ]; then
            echo "Compacting CTID: $CTID"
            $VZCTL_CMD compact $CTID > /tmp/vzpbackup_compact_$CTID_$TIMESTAMP.log
            echo "Compact log file: /tmp/vzpbackup_compact_$CTID_$TIMESTAMP.log"
        fi

	echo "Backing up CTID: $CTID"

	ID=$(uuidgen)
	VE_PRIVATE=$(VEID=$CTID; source /etc/vz/vz.conf; source /etc/vz/conf/$CTID.conf; echo $VE_PRIVATE)
	echo $ID > $VE_PRIVATE/vzpbackup_snapshot

	# Take CT snapshot with parameters
	$VZCTL_CMD snapshot $CTID --id $ID $CMDLINE

	# Backup configuration additional configuration files (/etc/vz/conf/$CTID.*)

        echo "Copying config files: "
        for f in $(ls -1 /etc/vz/conf/$CTID.*)
        do
            CONF_EXT=${f##*.}
            cp $f "$VE_PRIVATE/dump/{$ID}.ve.$CONF_EXT"
            echo $f
        done

	# Copy the backup somewhere safe
	# We copy the whole directory which then also includes
	# a possible the dump (while being suspended) and container config
	cd $VE_PRIVATE
	HNAME=`$VZLIST_CMD -Hohostname $CTID`

    if [ -z "$FILENAME" ]; then 
	FILENAME="${PREFIX}${CTID}_${HNAME}_${TIMESTAMP}"
    fi
    

	COMPRESS_SUFFIX=""
        if [ "$COMPRESS" == "tgz" ]; then
		tar -zcvf $WORK_DIR/$FILENAME.tar.gz .
		COMPRESS_SUFFIX="gz"
        elif [ "$COMPRESS" == "tbz" ]; then
		tar -jcvf $WORK_DIR/$FILENAME.tar.bz2 .
		COMPRESS_SUFFIX="bz2"
        elif [ "$COMPRESS" == "txz" ]; then
		tar -Jcvf $WORK_DIR/$FILENAME.tar.xz .
		COMPRESS_SUFFIX="xz"
        elif [ "$COMPRESS" == "pz" ]; then
		tar --use-compress-program=pigz -cvf $WORK_DIR/$FILENAME.tar.gz .
		COMPRESS_SUFFIX="gz"
        elif [ "$COMPRESS" == "pbz" ]; then
		tar --use-compress-program=pbzip2 -cvf $WORK_DIR/$FILENAME.tar.bz2 .
		COMPRESS_SUFFIX="bz2"
        else
		tar -cvf $WORK_DIR/$FILENAME.tar .
		if [ "$COMPRESS" == "bz" ]; then
                        bzip2 $WORK_DIR/$FILENAME.tar
                        COMPRESS_SUFFIX="bz2"
		elif [ "$COMPRESS" == "gz" ]; then
                        gzip $WORK_DIR/$FILENAME.tar
                        COMPRESS_SUFFIX="gz"
		elif [ "$COMPRESS" == "xz" ]; then
                        xz --compress $WORK_DIR/$FILENAME.tar
                        COMPRESS_SUFFIX="xz"
		fi
        fi

        echo "Removing backup config files: "
        for f in $(ls -1 $VE_PRIVATE/dump/{$ID}.ve.*)
        do
            ls -la "$f"
            rm "$f"
        done

	if [ "$COMPRESS_SUFFIX" == "" ]; then
		BACKUP_FILE="$FILENAME.tar"
	else
		BACKUP_FILE="$FILENAME.tar.$COMPRESS_SUFFIX"
	fi

	# Move file from temp directory to backup directory
	if [ "$BACKUP_DIR" != "$WORK_DIR" ]; then
		echo "Moving backup file"
		mv $WORK_DIR/$BACKUP_FILE $BACKUP_DIR/$BACKUP_FILE
	fi

        echo "BACKUP FILE: $BACKUP_DIR/$BACKUP_FILE"
        ls -la $BACKUP_DIR/$BACKUP_FILE

	# Delete (merge) the snapshot
	$VZCTL_CMD snapshot-delete $CTID --id $ID
else
	echo "WARNING: No CT found for ID $CTID. Skipping..."
fi

done
