#!/bin/bash

declare -A DATABASES=(
    []=""
)

#Define required variables
PG_HOST="localhost"
PG_PORT=5432
PG_USER="postgres"
PG_PASS="postgres"
BACKUP_BASE_DIR="/PostgresBackup"
LOG_BASE_DIR="/PgBackupLog"
SEND_LOGS=true
SQLCMD=/opt/mssql-tools/bin/sqlcmd
RETENTION_DAYS="4"

# Date variables
DATE=`date +%Y_%m_%d`
TIMESTAMP=`date +%Y_%m_%d_%H_%M_%S`

# Create base backup and log directories
mkdir -p "$BACKUP_BASE_DIR"
mkdir -p "$LOG_BASE_DIR"

# Adjust directory permissions
chown postgres:root "$BACKUP_BASE_DIR"
chown postgres:root "$LOG_BASE_DIR"

# Functions to insert backup details to a remote database
sendToDatabase() {
    if [[ "$SEND_LOGS" = true ]]
    then
        # Remote database configurations - to send database backup records
        MSSQL_REMOTE_HOST=""
        MSSQL_REMOTE_PORT=
        MSSQL_REMOTE_USER=""
        MSSQL_REMOTE_PASS=""
        MSSQL_REMOTE_DB=""
        MSSQL_REMOTE_TABLE=""

        # Insert into database
        $SQLCMD -S $MSSQL_REMOTE_HOST,$MSSQL_REMOTE_PORT -U $MSSQL_REMOTE_USER -P $MSSQL_REMOTE_PASS -d $MSSQL_REMOTE_DB -Q "SET QUOTED_IDENTIFIER ON; INSERT INTO $MSSQL_REMOTE_TABLE(NAME, FILE_NAME, FILE_SIZE, TYPE, STATUS, MESSAGE, S3_PATH) VALUES ('$1', '$2', '$3', '$4', '$5', '$6', '$7')" >> $LOG_BASE_DIR"/psql_backup_record.log"

        # Check exit status and add logs
        if [[ $? -ne 0 ]]
        then
            echo "## $TIMESTAMP $DB PSQLBackupError: Could not send backup records to remote database. Please check your remote database configurations." >> $LOG_BASE_DIR"/psql_backup_record.log"
        else
            echo "## $TIMESTAMP $DB PSQLBackup details sent to remote database." >> $LOG_BASE_DIR"/psql_backup_record.log"
        fi
    fi
}

for DB in ${!DATABASES[@]}
    do
        # Get clean db name (replaces _, - and space with nothing)
        CLEAN_DB_NAME=$(echo $DB | sed 's/[ _-]//g')

        # Set backup directory
        BACKUP_DIR=$BACKUP_BASE_DIR/$CLEAN_DB_NAME"/"$DATE

        # Set file name
        FILE_NAME=$CLEAN_DB_NAME"_PSQL_"$TIMESTAMP

        # Get S3 bucket name
        S3_BUCKET_NAME=${DATABASES[$DB]}

        # Create backup directory
        mkdir -p "$BACKUP_DIR"
        # Check exit status
        if [[ $? -ne 0 ]]
        then
            # Add log
            echo "## $TIMESTAMP $DB Error: Could not create a backup directory." >> $LOG_BASE_DIR"/psql_backup.log"
            # Send to database
            sendToDatabase "$DB" "$FILE_NAME" "0" "PSQL" "FAIL" "Could not create a backup directory." "$S3_BUCKET_NAME"
            continue
        fi

        backup_file="$BACKUP_DIR/$FILE_NAME.sql" 

        #Backup command
        PGPASSWORD=$PG_PASS pg_dump -U $PG_USER -d $DB > $backup_file >> $LOG_BASE_DIR"/psql_backup.log" 2>&1  
        # Check exit status
        if [[ $? -ne 0 ]]
        then
            # Add log
            echo "## $TIMESTAMP $DB Error: Could not perform a database backup. Please check your database and server configurations." >> $LOG_BASE_DIR"/psql_backup.log"
            # Send to database
            sendToDatabase "$DB" "$FILE_NAME" "0" "PSQL" "FAIL" "Could not perform a database backup. Please check your database and server configurations." "$S3_BUCKET_NAME"
            continue
        fi
        zip -j "$BACKUP_DIR/$FILE_NAME.zip" "$BACKUP_DIR/$FILE_NAME.sql" >> $LOG_BASE_DIR"/psql_backup.log"
        rm "$BACKUP_DIR/$FILE_NAME.sql"
        # Check exit status
        if [[ $? -ne 0 ]]
        then
            # Add log
            echo "## $TIMESTAMP $DB Error: Could not perform a database backup. Please check your database and server configurations." >> $LOG_BASE_DIR"/psql_backup.log"
            # Send to database
            sendToDatabase "$DB" "$FILE_NAME" "0" "PSQL" "FAIL" "Could not perform a database backup. Please check your database and server configurations." "$S3_BUCKET_NAME"
            continue
        fi

        # Sync to S3
        if [[ -n "${DATABASES[$DB]}" ]]
        then
            sudo aws s3 sync $BACKUP_DIR "s3://"${DATABASES[$DB]} >> $LOG_BASE_DIR"/psql_backup.log"
            # Check exit status
            if [[ $? -ne 0 ]]
            then
                # Add log
                echo "## $TIMESTAMP $DB Error: Could not upload backups to S3. Please check your AWS CLI and S3 bucket configurations." >> $LOG_BASE_DIR"/psql_backup.log"
                # Send to database
                sendToDatabase "$DB" "$FILE_NAME" "0" "PSQL" "FAIL" "Could not upload backups to S3. Please check your AWS CLI and S3 bucket configurations." "$S3_BUCKET_NAME"
                continue
            fi
        fi
        # Add log
        echo "## $TIMESTAMP PSQL BACKUP SUCCESSFUL FOR $DB." >> $LOG_BASE_DIR"/psql_backup.log"
        # Remove old files
        find $BACKUP_BASE_DIR/$CLEAN_DB_NAME/* -mtime +$RETENTION_DAYS -delete

        # Call function to send backup details to database
        BACKUP_SIZE=$(du -h $BACKUP_DIR/$FILE_NAME.zip | cut -f 1)
        sendToDatabase "$DB" "$FILE_NAME" "$BACKUP_SIZE" "PSQL" "SUCCESS" "Full backup successful for $DB." "$S3_BUCKET_NAME"
    done
    # Remove old log text
    tail -n 4500 $LOG_BASE_DIR"/psql_backup.log" > tempfull.log && mv tempfull.log $LOG_BASE_DIR"/psql_backup.log"
    
