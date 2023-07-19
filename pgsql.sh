#!/bin/bash

databases=("testdb1" "testdb2")

hostname="localhost"
port="5432"
pg_user="postgres"
pg_pass="postgres"
backup_dir="/home/aroj/psql/backup"
zip_dir="/home/aroj/psql/zip"
logdir="/home/aroj/psql/log"

if [[ $1 == "full" ]] #for full database backup
then
    backup_file="$backup_dir/pg_fullbackup_$(date +%Y-%m-%d-%H-%M).sql"

    PGPASSWORD=$pg_pass pg_dumpall -U $pg_user > $backup_file >> $log_dir/postgresdb_full_$(date +%Y-%m-%d-%H-%M).log 2>&1 #-->>--command to backup

    
        #compressing the backup file
        zip_file="$zip_dir/pg_fullbackup_$(date +%Y-%m-%d-%H-%M).zip"
        zip $zip_file $backup_file

        #Deleting backup file and zip file
        find /home/aroj/psql/backup/ -type f -name "*.bak" -mmin -1 -delete
        find /home/aroj/psql/zip/ -type f -name "*.zip" -mtime +6 -delete

elif [[ $1 == "single" ]] #for single database backup
then
    for database in ${databases[@]}
    do
        dbname="$database"
        backup_file="$backup_dir/pg_"$dbname"_bak_$(date +%Y-%m-%d-%H-%M).sql" 

        PGPASSWORD=$pg_pass pg_dump -U $pg_user -d $dbname > $backup_file >> $log_dir/"$dbname"_$(date +%Y-%m-%d-%H-%M).log 2>&1 #-->>-- backup command 
        
        #compressing the backup file
        zip_file="$zip_dir/pg_"$dbname"_bak_$(date +%Y-%m-%d-%H-%M).zip"
        zip $zip_file $backup_file
            
        #Deleting backup file and zip file
        find /home/aroj/psql/backup/ -type f -name "*.bak" -mmin -1 -delete
        find /home/aroj/psql/zip/ -type f -name "*.zip" -mtime +6 -delete

    done
        
else
    echo "please provide the backup type... full or single"
fi