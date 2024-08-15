#!/bin/bash


# Is sudo?
if [ "$EUID" -ne 0 ]
  then echo "[ERR]: Run as root, dumbass. UwU"
  exit
fi

# Is db.pgsql exists?
if [ -e db.pgsql ]
then
    echo "db.pgsql successfully found at initial scope"
else
    echo "[ERR]: db.pgsql DONT found at initial scope"
    exit
fi

whoami=C:\\Windows
echo "Thx. Deleting $whoami )"

#sleep 1.5
#echo "."
#sleep 1.5
#echo ".."
#sleep 1.5
#echo "..."
sleep 2
echo "just jking :)"


# Create role
sudo su postgres -c "psql --command 'create role floatyapi WITH LOGIN ' "

# Create user
sudo su postgres -c "psql --command 'create user floatyapi WITH PASSWORD '\''FloatyTheBest'\'' ROLE floatyapi'"

# Create database
sudo su postgres -c "psql --command 'create database floatydb' "

# Insert into database data
sudo su postgres -c "psql -U postgres floatydb < db.pgsql"

echo "If there is no errors, than u r good to go :). In else case - write me, Sochnyi) U needed to drop floatydb (db) and floatyapi (role)"