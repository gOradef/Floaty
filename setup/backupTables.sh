#!/bin/bash

# Set the current date in DD-MM-YY format
current_date=$(date +"%d-%m-%y")

# Construct the filename with the current date
filename="backup - $current_date.pgsql"

# Perform the pg_dump command
pg_dump -U postgres floatydb -t schools -t schools_classes -t schools_classes_ownership -t schools_data -t schools_invites -t schools_invites_archived -t schools_template_classes -t schools_users -t users -t users_salts > "$filename"

echo "Backup completed. File saved as: $filename"