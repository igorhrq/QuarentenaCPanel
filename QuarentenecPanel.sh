#!/bin/bash

if ( ! getopts "u:h" option); then
    echo "Usage: `basename $0` -u username";
    exit $E_OPTERROR;
fi

while getopts :u:h option
do
    case "${option}"
    in
        u) USER=${OPTARG};;
        h) echo "Usage: `basename $0` -u username";
           exit 1;;
        \?) exit 1;;
    esac
done

if [[ ! $(getent passwd "$USER") ]]; then
    echo "User $USER does not exist";
    exit 1;
fi
HOMEDIR=$(getent passwd "$USER" | cut -f6 -d:)
QUARFILENAME=$USER-quarantine.$(date +%s).tar

#Unchattr disabled files
find "$HOMEDIR" -perm 000 -exec chattr -ia {} \;

#Quarantine Disabled Directories with no enabled files
for depth in `seq 1 15`; do
    find "$HOMEDIR" -mindepth $depth -maxdepth $depth -type d -perm 000 | cut -f4- -d/ | while read LIST; do
        if [[ -d "$HOMEDIR"/"$LIST" ]]; then
            if [[ ! `find "$HOMEDIR"/"$LIST" ! -perm 000 -or ! -user root` ]]; then
                tar rf "$HOMEDIR"/"$QUARFILENAME" -C "$HOMEDIR" "$LIST";
                rm -rfv "$HOMEDIR"/"$LIST";
            fi;
        fi
    done
done

#Quarantine disabled files
find "$HOMEDIR" -user root -perm 000 -type f | cut -f4- -d/ | while read LIST; do
    if [[ -f "$HOMEDIR"/"$LIST" ]]; then
        tar rf "$HOMEDIR"/"$QUARFILENAME" -C "$HOMEDIR" "$LIST" ;
        rm -vf "$HOMEDIR"/"$LIST";
    fi
done

if [[ -f "$HOMEDIR"/"$QUARFILENAME" ]]; then
    chown $USER.$USER "$HOMEDIR"/"$QUARFILENAME";
    echo "Disabled files were quarantined to $HOMEDIR/$QUARFILENAME";
else
    echo "No files were found to be quarantined";
fi
