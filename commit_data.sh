#!/bin/bash

cd /home/floaty/gits/Floaty

curr_date=$(date '+%Y-%m-%d %H:%M:%S')

git add data/*

commit_message="Auto commit of data - $curr_date"
echo "INFO: current message is: $commit_message \n"
git commit -m "$commit_message"

git push
