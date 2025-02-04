#!/bin/bash

# Set the current date in DD-MM-YY-HH:MM format
current_date=$(date +"%d-%m-%y-%H:%M")

# Prompt the user to enter a theme for the backup
read -p "Enter the theme for the backup: " theme

# Construct the filename with the theme and current date
filename="$theme - $current_date.backup.pgsql"

mkdir backups/
# Perform the pg_dump command
pg_dump -U postgres floatydb --data-only -t schools -t schools_classes -t schools_classes_ownership -t schools_data -t schools_invites -t schools_invites_archived -t schools_template_classes -t schools_users -t users -t users_salts > "backups/$filename"

echo "Backup completed. File saved as: $filename"