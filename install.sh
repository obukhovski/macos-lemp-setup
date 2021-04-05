#!/bin/bash
# Install script for LEMP on OS X - by ronilaukkarinen, Evgeni Obukhovski.

# Helpers:
currentfile=`basename $0`
txtbold=$(tput bold)
boldyellow=${txtbold}$(tput setaf 3)
boldgreen=${txtbold}$(tput setaf 2)
boldwhite=${txtbold}$(tput setaf 7)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
green=$(tput setaf 2)
white=$(tput setaf 7)
txtreset=$(tput sgr0)
LOCAL_IP=$(ifconfig | grep -Eo "inet (addr:)?([0-9]*\.){3}[0-9]*" | grep -Eo "([0-9]*\.){3}[0-9]*" | grep -v "127.0.0.1")
YEAR=$(date +%y)

echo "${yellow}Getting dependencies.${txtreset}"
xcode-select --install
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew doctor
brew update && brew upgrade
echo "${boldgreen}Dependencies installed and up to date.${txtreset}"
echo "${yellow}Installing nginx.${txtreset}"
brew install nginx
brew services start nginx
curl -IL http://127.0.0.1:8080
echo "${boldgreen}nginx installed and running.${txtreset}"
echo "${yellow}Setting up nginx.${txtreset}"
sudo chmod -R 775 /usr/local/etc/nginx
sudo ln -sfnv /usr/local/etc/nginx /etc/nginx
sudo mkdir -p /etc/nginx/global
sudo mkdir -p /usr/local/etc/nginx
sudo mkdir -p /etc/nginx/sites-enabled
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/global
sudo chmod -R 775 /etc/nginx/global
sudo chmod -R 775 /usr/local/etc/nginx
sudo chmod -R 775 /etc/nginx/sites-enabled
sudo chmod -R 775 /etc/nginx/sites-available
sudo chmod -R 775 /etc/nginx/global
sudo echo "worker_processes 8;

events {
        multi_accept on;
        accept_mutex on;
        worker_connections 1024;
}

http {
        upstream fastcgi_backend {
            server  127.0.0.1:9000;
        }

        ##
        # Optimization
        ##

        sendfile on;
        sendfile_max_chunk 512k;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 120;
        keepalive_requests 100000;
        types_hash_max_size 2048;
        server_tokens off;
        client_body_buffer_size      128k;
        client_max_body_size         10m;
        client_header_buffer_size    1k;
        large_client_header_buffers  4 32k;
        output_buffers               1 32k;
        postpone_output              1460;

        server_names_hash_max_size 1024;
        #server_names_hash_bucket_size 64;
        # server_name_in_redirect off;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ##
        # Logging Settings
        ##
        access_log off;
        access_log /var/log/nginx/access.log combined;
        error_log /var/log/nginx/error.log;

        ##
        # Virtual Host Configs
        ##

        include /etc/nginx/sites-enabled/*;
}" > "/etc/nginx/nginx.conf"
sudo mkdir -p /var/log/nginx
sudo touch /var/log/nginx/access.log
sudo chmod 777 /var/log/nginx/access.log
sudo touch /var/log/nginx/error.log
sudo chmod 777 /var/log/nginx/error.log
sudo echo "
server {
    listen 80;
    listen [::]:80;
    server_name sample-magento.local;
    #set \$MAGE_ROOT /Users/$USER/projects/sample-magento;
    include global/magento.conf;
}" > "/etc/nginx/sites-available/sample-magento.conf"
sudo echo "root \$MAGE_ROOT/pub;

error_log /Users/$USER/projects/log/nginx-error.log;
#access_log /Users/$USER/projects/log/nginx-access.log;

index index.php;
autoindex off;
charset UTF-8;
error_page 404 403 = /errors/404.php;

# Deny access to sensitive files
location /.user.ini {
    deny all;
}

# PHP entry point for setup application
location ~* ^/setup($|/) {
    root \$MAGE_ROOT;
    location ~ ^/setup/index.php {
        fastcgi_pass   fastcgi_backend;

        fastcgi_param  PHP_FLAG  \"session.auto_start=off \n suhosin.session.cryptua=off\";
        fastcgi_param  PHP_VALUE \"memory_limit=756M \n max_execution_time=600\";
        fastcgi_read_timeout 600s;
        fastcgi_connect_timeout 600s;

        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }

    location ~ ^/setup/(?!pub/). {
        deny all;
    }

    location ~ ^/setup/pub/ {
        add_header X-Frame-Options \"SAMEORIGIN\";
    }
}

# PHP entry point for update application
location ~* ^/update($|/) {
    root \$MAGE_ROOT;

    location ~ ^/update/index.php {
        fastcgi_split_path_info ^(/update/index.php)(/.+)$;
        fastcgi_pass   fastcgi_backend;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        fastcgi_param  PATH_INFO        \$fastcgi_path_info;
        include        fastcgi_params;
    }

    # Deny everything but index.php
    location ~ ^/update/(?!pub/). {
        deny all;
    }

    location ~ ^/update/pub/ {
        add_header X-Frame-Options \"SAMEORIGIN\";
    }
}

location / {
    try_files \$uri \$uri/ /index.php\$is_args\$args;
}

location /pub/ {
    location ~ ^/pub/media/(downloadable|customer|import|custom_options|theme_customization/.*\.xml) {
        deny all;
    }
    alias \$MAGE_ROOT/pub/;
    add_header X-Frame-Options \"SAMEORIGIN\";
}

location /static/ {
    # Uncomment the following line in production mode
    # expires max;

    # Remove signature of the static files that is used to overcome the browser cache
    location ~ ^/static/version {
        rewrite ^/static/(version\d*/)?(.*)$ /static/\$2 last;
    }

    location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2|html|json)$ {
        add_header Cache-Control \"public\";
        add_header X-Frame-Options \"SAMEORIGIN\";
        expires +1y;

        if (!-f \$request_filename) {
            rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
        }
    }
    location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
        add_header Cache-Control \"no-store\";
        add_header X-Frame-Options \"SAMEORIGIN\";
        expires    off;

        if (!-f \$request_filename) {
           rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
        }
    }
    if (!-f \$request_filename) {
        rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
    }
    add_header X-Frame-Options \"SAMEORIGIN\";
}

location /media/ {
    try_files \$uri \$uri/ /get.php\$is_args\$args;

    location ~ ^/media/theme_customization/.*\.xml {
        deny all;
    }

    location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)$ {
        add_header Cache-Control \"public\";
        add_header X-Frame-Options \"SAMEORIGIN\";
        expires +1y;
        try_files \$uri \$uri/ /get.php\$is_args\$args;
    }
    location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
        add_header Cache-Control \"no-store\";
        add_header X-Frame-Options \"SAMEORIGIN\";
        expires    off;
        try_files \$uri \$uri/ /get.php\$is_args\$args;
    }
    add_header X-Frame-Options \"SAMEORIGIN\";
}

location /media/customer/ {
    deny all;
}

location /media/downloadable/ {
    deny all;
}

location /media/import/ {
    deny all;
}
location /media/custom_options/ {
    deny all;
}
location /errors/ {
    location ~* \.xml$ {
        deny all;
    }
}

# PHP entry point for main application
location ~ ^/(index|get|static|errors/report|errors/404|errors/503|health_check)\.php$ {
    try_files \$uri =404;
    fastcgi_pass fastcgi_backend;
    #fastcgi_buffers 1024 4k;

    fastcgi_buffer_size 512k;
    fastcgi_buffers 4 512k;
    fastcgi_busy_buffers_size 1024k;

    fastcgi_param  PHP_FLAG  \"session.auto_start=off \n suhosin.session.cryptua=off\";
    fastcgi_param  PHP_VALUE \"memory_limit=756M \n max_execution_time=180\";
    fastcgi_read_timeout 600s;
    fastcgi_connect_timeout 600s;

    fastcgi_index  index.php;
    fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
    include        fastcgi_params;
}

gzip on;
gzip_disable \"msie6\";

gzip_comp_level 6;
gzip_min_length 1100;
gzip_buffers 16 8k;
gzip_proxied any;
gzip_types
    text/plain
    text/css
    text/js
    text/xml
    text/javascript
    application/javascript
    application/x-javascript
    application/json
    application/xml
    application/xml+rss
    image/svg+xml;
gzip_vary on;

# Banned locations (only reached if the earlier PHP entry point regexes dont match)
location ~* (\.php$|\.phtml$|\.htaccess$|\.git) {
    deny all;
}" > "/etc/nginx/global/magento.conf"
sudo ln -sfnv /etc/nginx/sites-available/sample-magento.conf /etc/nginx/sites-enabled/sample-magento.conf
echo "${yellow}Installing PHP.${txtreset}"
brew install php@7.4
mkdir -p ~/Library/LaunchAgents
cp /usr/local/opt/php@7.4/homebrew.mxcl.php@7.4.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.php@7.4.plist
lsof -Pni4 | grep LISTEN | grep php
sudo ln -s /usr/local/etc/php/7.4/php-fpm.conf /private/etc/php-fpm.conf
sudo sed -i '' 's/;error_log/error_log/' /private/etc/php-fpm.conf
sudo sed -i '' 's/log\/php-fpm.log/\/var\/log\/php-fpm.log/' /private/etc/php-fpm.conf
sudo touch /var/log/fpm7.4-php.slow.log
sudo chmod 775 /var/log/fpm7.4-php.slow.log
sudo chown "$USER":staff /var/log/fpm7.4-php.slow.log
sudo touch /var/log/fpm7.4-php.www.log
sudo chmod 775 /var/log/fpm7.4-php.www.log
sudo chown "$USER":staff /var/log/fpm7.4-php.www.log
sudo echo "export PATH=\"\$(brew --prefix php@7.4)/bin:\$PATH\"" >> ~/.bashrc
brew services stop php@7.4
brew services start php@7.4
echo "${boldgreen}PHP installed and running.${txtreset}"
echo "${yellow}Installing MySQL.${txtreset}"
brew install mysql@5.7
brew services start mysql@5.7
sudo echo "#
# This group is read both both by the client and the server
# use it for options that affect everything
#
[client-server]

#
# include all files from the config directory
#
!includedir /usr/local/etc/my.cnf.d

[mysqld]
innodb_log_file_size = 32M
innodb_buffer_pool_size = 2G
innodb_log_buffer_size = 4M
slow_query_log = 1
query_cache_limit = 2M
query_cache_size = 512M
#skip-name-resolve" > "/usr/local/etc/my.cnf"
mkdir /usr/local/etc/my.cnf.d
echo "${boldgreen}MySQL installed and running.${txtreset}"
echo "${yellow}Installing elasticsearch.${txtreset}"
brew install elasticsearch
brew services start elasticsearch
echo "${boldgreen}elasticsearch installed and running.${txtreset}"
echo "${yellow}Restarting services....${txtreset}"
brew services stop nginx
brew services start nginx
brew services stop php@7.4
brew services start php@7.4
brew services stop mysql@5.7
brew services start mysql@5.7
brew services stop elasticsearch
brew services start elasticsearch
brew link php@7.4
brew link mysql@5.7
brew services list

echo "${boldgreen}Services installed!${txtreset}"
