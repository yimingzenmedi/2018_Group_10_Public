#!/bin/bash
: '
============================================
    Group 10, 2018
    158.383 Information Technology Project

    To run this script please use
        sudo bash install.sh {password}
    where {password} is the password for
    everything!

    This script has been tested on the following
    Linux distributions;
    1. Debian 9
============================================
'
# check if the user has entered a default password
if [ -z "$1" ] 
then
    echo "ERROR: You must enter a default PASSWORD as a paramter when executing this script."
    exit
fi

: '
-------------------
Variables
-------------------
'
# general settings
PASSWORD=$1
CURRENT_DIR="$(pwd)"
GLOBAL_IP="_" # we need a default value if below fails
GLOBAL_IP="$(curl ifconfig.me --max-time 8)" # fetches host's external IP
GOGS_PORT=3000

# supervisor conf
GOGS_ROOT="$CURRENT_DIR"
GOGS_USER="root"

# resources
declare -A resources
resources=( 
    ["gogs"]="https://dl.gogs.io/0.11.53/gogs_0.11.53_linux_amd64.tar.gz"
    ["gogsconf"]="https://raw.githubusercontent.com/dy1zan/2018_Group_10_Public/master/app.ini"
    ["supervisor"]="https://raw.githubusercontent.com/dy1zan/2018_Group_10_Public/master/gogs.conf"
    ["nginx"]="https://raw.githubusercontent.com/dy1zan/2018_Group_10_Public/master/nginx"
)

: '
-------------------
Console functions
-------------------
'
perror() {
    # outputs an error and exits
    tput setaf 1 && echo -n "error:" && tput setaf 7
    echo " $1"
    exit
}
psuccess() {
    # outputs a success
    tput setaf 2 && echo -n "success:" && tput setaf 7
    echo " $1"
}
pinfo() {
    # outputs an informative message
    tput setaf 6 && echo -n "info:" && tput setaf 7
    echo " $1"
}


: '
-------------------
Setup functions
- setup_git
- setup_psql
- setup_nginx
- setup_supervisor
- setup_gogs
-------------------
'
# install git version control
setup_git() {
    sudo apt-get install git -y
}

# install PostgreSQL as Gogs' database
setup_psql() {
    cd $CURRENT_DIR
    
    pinfo "installing & setting up postgresql..."
    apt-get install -y postgresql postgresql-client || perror "we were unable to install postgresql."

    pinfo "we are going to create a new postgreSQL user, and database for Gogs..."

    # Create a new psql user, gogs, and create a database for this user
    echo "create user gogs with password '$PASSWORD';
    create database gogs owner gogs;
    grant all privileges on database gogs to gogs;" | sudo -u postgres psql || perror "there was an error creating a new user or database."

    psuccess "the database has been setup."
}

# install Nginx to forward HTTP traffic to Gogs
setup_nginx() {
    cd $CURRENT_DIR
    pinfo "installing & configuring nginx..."
    apt-get install nginx -y || perror "we were unable to install nginx."

    # manually config nginx
    echo "server {
        listen 80;
        server_name _;
        location / {
            proxy_pass http://127.0.0.1:$GOGS_PORT/; 
        }
    }" > /etc/nginx/sites-available/gogs
    
    # remove the default nginx conf
    rm -f /etc/nginx/sites-enabled/default

    # enable gogs conf & restart nginx
    ln -s /etc/nginx/sites-available/gogs /etc/nginx/sites-enabled/gogs
    service nginx restart

    psuccess "nginx has successfully been installed."
}

# install supervisor to automatically start/restart Gogs
setup_supervisor() {
    cd $CURRENT_DIR
    pinfo "installing & configuring supervisor..."

    apt-get install -y supervisor || (pinfo "we were unable to install supervisor. This means your application will not automatically restart." && return 1)
    wget ${resources["supervisor"]} -O supervisor.conf
    sed "s|@USER_HOME|$GOGS_ROOT|g;s|@USER|$GOGS_USER|g" supervisor.conf > /etc/supervisor/conf.d/gogs.conf
}

# install Gogs
setup_gogs() {
    cd $CURRENT_DIR
    pinfo "downloading gogs..."
    wget ${resources["gogs"]} || perror "unable to download the software. Please check the network connection."
    tar -zxf gogs_0.11.53_linux_amd64.tar.gz
    
    pinfo "installing gogs..."
    
    cd gogs
    # configure gogs: config file, logs folder
    wget ${resources["gogsconf"]} || perror "unable to download the software. Please check the network connection."
    mkdir -p custom/conf
    mkdir logs
    sed "s/@password/$PASSWORD/g;s/@ip/$GLOBAL_IP/g;s/@port/$GOGS_PORT/g" app.ini > custom/conf/app.ini

    psuccess "Gogs has been successfully installed."
}

: '
-------------------
Init functions
-------------------
'
# perform all setup operations
setup() {
    setup_git
    setup_psql
    setup_gogs
    setup_nginx
    setup_supervisor
}
setup

# run Gogs
run() {
    supervisorctl reread
    supervisorctl update
    supervisorctl start gogs
    pinfo "Gogs is now running on $GLOBAL_IP:80."
}
run
