#!/bin/bash
databases=("arojdb" "testdb1" "testdb2")

#Ms-sql database cerdentials
hostname="localhost"
username="sa"
password="Aroj@8835"
# database="arojdb"

#backup directory name
backup_dir="/home/aroj/database_backups"
#zip directory
compress_dir="/home/aroj/database_zip"
#log directory
log_dir="/home/aroj/ms_log"


if [[ $1 == "full" ]]
then
    for database in ${databases[@]}
    do
        dbname=$database
        #backup file name
        backup_file="$backup_dir/"$dbname"_mssql_full_$(date +%Y-%m-%d-%H-%M).bak"
        
        #full backup query
        /opt/mssql-tools/bin/sqlcmd -S $hostname -U $username -P $password -Q "backup database $dbname to disk = '$backup_file'" >> $log_dir/"$dbname"_full.log 2>&1
        
        #give permission to others to read the backup file to create a zip of it
        chown mssql:root $backup_dir
        
        #compress the backupfile
        zip_file="$compress_dir/"$dbname"_mssql_fullbak_$(date +%Y-%m-%d-%H-%M).zip"
    
        #zip command
        zip -j $zip_file $backup_file >> $log_dir/"$dbname"_full.log 2>&1

        #delete backup and zip
        find /home/aroj/database_backups/ -type f -name "*.bak" -mmin -1 -delete
        find /home/aroj/database_zip/ -type f -name "*.zip" -mtime +6 -delete
    done


elif [[ $1 == "diff" ]]
then
    for database in ${databases[@]}
    do
        dbname=$database
        #backup file name
        backup_file="$backup_dir/"$dbname"_mssql_diff_$(date +%Y-%m-%d-%H-%M).bak"

        #differential backup query
        /opt/mssql-tools/bin/sqlcmd -S $hostname -U $username -P $password -Q "backup database $dbname to disk = '$backup_file' with differential" >> $log_dir/"$dbname"_diff.log 2>&1

        #give permission to others to read the backup file to create a zip of it
        chown mssql:root $backup_dir

        #compress the backupfile
        zip_file="$compress_dir/"$dbname"_mssql_diffbak_$(date +%Y-%m-%d-%H-%M).zip"

        #zip command
        zip -j $zip_file $backup_file >> $log_dir/"$dbname"_diff.log 2>&1

        #delete backup and zip
        find /home/aroj/database_backups/ -type f -name "*.bak" -mmin -1 -delete
        find /home/aroj/database_zip/ -type f -name "*.zip" -mtime +6 -delete


    done
    
else    
    echo "Please provide the backup type... full or diff"

fi