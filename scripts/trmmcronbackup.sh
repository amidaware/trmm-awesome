#! /bin/bash
# trmmcronbackup : Back up Tactical RMM via backup.sh with backup rotation

# SPDX-FileCopyrightText: 2022 Timothy J. Massey <github:fts-tmassey>
# SPDX-License-Identifier: GPL-2.0-or-later

# This script runs the standard TRMM-provided backup.sh script and keeps
# up to a maximum number of backup files, deleting the oldest backups when
# necessary.  This is intended to run as a periodic cron job, simply by
# putting it in e.g. cron.daily.  You can find more details at:
#     https://github.com/fts-tmassey/tacticalrmm-cronbackup

# Configuration Variables
VERBOSE=FALSE                   # Use TRUE for verbose output
BACKUP_COUNT=8                  # Number of backups to keep
PATH_TO_SCRIPT=/rmm/backup.sh   # Path to backup script
PATH_TO_BACKUPS=/rmmbackups     # Path to backup destination
#SCRIPT_USER=tactical           # Run script as (unset: use script owner)

# Script begins below
vecho() {  # Echo only if user specifies Verbose output
    if [[ "${VERBOSE}" == "TRUE" ]]; then echo "${1}"; fi
}

# Check the configuration variables
vecho "Initial configuration variables:"
vecho "-- BACKUP_COUNT:  ${BACKUP_COUNT}"
case ${BACKUP_COUNT} in
    ''|*[!0-9]*) # Make sure variable is a number
        echo "Bad BACKUP_COUNT:  ${BACKUP_COUNT}.  Make sure this is a number.  Exiting..."
        exit 1
    ;;
esac
vecho "-- PATH_TO_SCRIPT:  \"${PATH_TO_SCRIPT}\""
if [[ ! -f ${PATH_TO_SCRIPT} ]]; then
    echo "PATH_TO_SCRIPT not found.  Exiting..."
    exit 1
fi
if [[ ! -x ${PATH_TO_SCRIPT} ]]; then
    echo "The file pointed to by PATH_TO_SCRIPT is not executable.  Exiting..."
    exit 1
fi
vecho "-- PATH_TO_BACKUPS:  \"${PATH_TO_BACKUPS}\""
if [[ ! -d ${PATH_TO_BACKUPS} ]]; then
    echo "PATH_TO_BACKUPS is not a valid directory.  Exiting..."
    exit 1
fi
vecho "-- SCRIPT_USER:  \"${SCRIPT_USER}\""
if [ -z "${SCRIPT_USER}" ]; then                    # If user unset
    SCRIPT_USER=$(stat -c '%U' "${PATH_TO_SCRIPT}") #  use script owner
    vecho "-- Detected user:  ${SCRIPT_USER}"
fi
if ! id -u "${SCRIPT_USER}" &>/dev/null; then
    echo "The user does not exist.  Exiting..."
    exit 1
fi
vecho "Initial configuration variables:  OK"

# Get initial count of backup files
INITIAL_COUNT=$(sudo su "${SCRIPT_USER}" -c "ls ${PATH_TO_BACKUPS}|wc -l")
vecho "Initial backup file count:  ${INITIAL_COUNT}"
case ${INITIAL_COUNT} in
    ''|*[!0-9]*) # Make sure variable is a number
        echo "Bad initial count of backups:  ${INITIAL_COUNT}.  Backup was not performed."
        exit 1
    ;;
esac

# Run the backup script
# stderr is not captured with $(), so use array/eval to run backup.sh silently
SCRIPT_CMD_ARRAY=(sudo su - "${SCRIPT_USER}" "-c \"cd ~ ; ${PATH_TO_SCRIPT}\"" )
vecho "Run Script:  ${SCRIPT_CMD_ARRAY[*]}"
if [[ "${VERBOSE}" == "TRUE" ]]; then
    eval "${SCRIPT_CMD_ARRAY[*]}"
else
    eval "${SCRIPT_CMD_ARRAY[*]} &>/dev/null"
fi
SCRIPT_RETURN=$?
vecho "The script returned:  ${SCRIPT_RETURN}"
if ! [[ "${SCRIPT_RETURN}" -eq 0 ]] ; then
    echo "Backup script failed.  Cleanup was not performed."
    exit 1
fi

# Get new count of backup files and check that a new one was created
NEW_COUNT=$(sudo su "${SCRIPT_USER}" -c "ls ${PATH_TO_BACKUPS}|wc -l")
vecho "Post-run backup file count:  ${NEW_COUNT}"
case ${NEW_COUNT} in
    ''|*[!0-9]*) # Make sure variable is a number
        echo "Bad after-script count of backups:  ${NEW_COUNT}.  Cleanup was not performed."
        exit 1
    ;;
esac
if ! [[ "${NEW_COUNT}" -gt "${INITIAL_COUNT}" ]] ; then
    echo "Backup did not seem to create new file.  Cleanup was not performed."
    exit 1
fi

# Check if we have too many backup files and delete until we don't
while [ "${NEW_COUNT}" -gt "${BACKUP_COUNT}" ] ; do
    vecho "There are more than ${BACKUP_COUNT} files:  delete oldest file."
    # Get the list of files sorted by change date and get the last one
    FILE_TO_DELETE=$(sudo su "${SCRIPT_USER}" -c "ls ${PATH_TO_BACKUPS} --sort=time --time=ctime|tail -1")
    vecho "File to delete:  ${FILE_TO_DELETE}"
    case ${FILE_TO_DELETE} in
    ''|*[!0-9a-zA-Z._-]*) # Make sure variable uses only limited characters
        echo "Filename contains unexpected characters.  Cleanup cancelled."
        exit 1
    ;;
    esac
    # Delete the file
    RM_OUT=$(sudo su "${SCRIPT_USER}" -c "rm -fv --interactive=never '${PATH_TO_BACKUPS}/${FILE_TO_DELETE}'")
    vecho "rm output:  ${RM_OUT}"
    if [[ -f ${PATH_TO_BACKUPS}/${FILE_TO_DELETE} ]] ; then
        echo "Backup file ${PATH_TO_BACKUPS}/${FILE_TO_DELETE} did not delete.  Cancelling cleanup."
        exit 1
    fi
    # Get the updated count
    INITIAL_COUNT=${NEW_COUNT}
    NEW_COUNT=$(sudo su "${SCRIPT_USER}" -c "ls ${PATH_TO_BACKUPS}|wc -l")
    vecho "Updated backup file count:  ${NEW_COUNT}"
    case ${NEW_COUNT} in
        ''|*[!0-9]*) # Make sure variable is a number
            echo "Error getting new count of backups.  Cleanup was cancelled."
            exit 1
        ;;
    esac
    if ! [[ "${NEW_COUNT}" -lt "${INITIAL_COUNT}" ]] ; then
        echo "Cleanup did not seem to remove old file.  Cleanup was cancelled."
        exit 1
    fi
done
vecho "After cleanup, ${NEW_COUNT} files remain with a maximum of ${BACKUP_COUNT}."
vecho "Backup and cleanup complete."
exit 0
