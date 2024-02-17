#!/bin/bash

cd /home/floaty/gits/Floaty || exit

curr_date=$(date '+%Y-%m-%d %H:%M:%S')

git add data/*

while getopts d: flag
do
    # shellcheck disable=SC2220
    case "${flag}" in
        d) description=${OPTARG};;
    esac
done

echo "$description"
commit_message="Auto commit of data (${description}) - $curr_date"
echo "INFO: current message is: $commit_message"
git commit -m "$commit_message"

git push
