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


sudo su postgres -c "psql --command 'drop database floatydb ' "

sudo su postgres -c "psql -U postgres floatydb < db.pgsql"