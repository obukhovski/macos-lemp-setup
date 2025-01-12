## Install local LEMP for macOS, Magento 2 pack

Forked form [ronilaukkarinen](https://github.com/digitoimistodude/macos-lemp-setup)

Install script contains LEMP components needed for PHP local development, Magento 2 included. If you have a Macbook, you can install local LEMP (Linux, nginx, MySQL and PHP) and elasticsearch with this single liner below. Please see [installation steps](#installation-steps).

```` bash
wget -O - https://raw.githubusercontent.com/obukhovski/macos-lemp-setup/master/install.sh | bash
````

**Please note:** Don't trust blindly to the script, use only if you know what you are doing. You can view the file [here](https://github.com/digitoimistodude/osx-lemp-setup/blob/master/install.sh) if having doubts what commands are being run. However, script is tested working many times and should be safe to run even if you have some or all of the components already installed.

## Table of contents

1. [Background](#background)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Post installations](#post-installations)
6. [Use Linux-style aliases](#use-linux-style-aliases)
7. [File sizes](#file-sizes)
8. [XDebug](#xdebug)
9. [Troubleshooting](#troubleshooting)

### Background

The full installation description and further steps such as smile elastic suite, redis and mailhog setup could be found in: **[Magento 2 local developemnt on MacOS](https://obukhovski.com/magento-2-macos)** article.

### Features
- PHP 7.4
- MySQL 5.7
- elasticsearch 7.12 (Apr 5th 2021)
- nginx 1.19.8 (Apr 5th 2021)
- Super lightweight
- Native packages
- Always on system service
- HTTPS support
- Consistent with production setup
- Works even [on Windows](https://github.com/digitoimistodude/windows-lemp-setup)

### Requirements

- [Homebrew](https://brew.sh/)
- macOS, preferably the last one (Big Sur)
- wget
- [mkcert](https://github.com/FiloSottile/mkcert) (optional, for ssl support)

### Installation

The scripts assumes there is a  ~/projects/ directory containing projects (sample-magento in the test case). Logs directory is ~/projects/log

1. Install wget, `brew install wget`
2. Run oneliner installation script `wget -O - https://raw.obukhovski.com/digitoimistodude/macos-lemp-setup/master/install.sh | bash`
3. Check the version with `php --version`, it should match the linked file. You might re-launch terminal in order to `brew link php@7.4` takes effect. 
4. Brew should have already handled other links, you can test the correct versions with `mysql --version` (if it's something like _mysql  Ver 15.1 Distrib 10.5.5-MariaDB, for osx10.15 (x86_64) using readline 5.1_ it's the correct one) and `nginx -v` (if it's something like nginx version: nginx/1.19.3 it's the correct one)
5. install ext-intl and ext-redis `pecl install intl && pecl install redis`. 
6. Run [Post install](#post-install)
7. Enjoy! If you use [dudestack](https://github.com/digitoimistodude/dudestack), please check instructions from [its own repo](https://github.com/digitoimistodude/dudestack).

### Post installations

Magento project example `cd ~/projects && composer create-project --repository-url=https://repo.magento.com magento/project-community-edition sample-magento`

You should remember to add vhosts to your /etc/hosts file, for example: `127.0.0.1 sample-magento.local`.

You may want to add your user and group correctly to `/usr/local/etc/php/7.4/php-fpm.d/www.conf` and set these to the bottom:

```` nginx
catch_workers_output = yes
php_flag[display_errors] = On
php_admin_value[error_log] = /var/log/fpm7.4-php.www.log 
slowlog = /var/log/fpm7.4-php.slow.log 
php_admin_flag[log_errors] = On
php_admin_value[memory_limit] = 1024M
request_slowlog_timeout = 10
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
````

Default my.cnf would be something like this (already added by install.sh in `/usr/local/etc/my.cnf`:

````
#
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
innodb_buffer_pool_size = 1024M
innodb_log_buffer_size = 4M
slow_query_log = 1
query_cache_limit = 512K
query_cache_size = 128M
skip-name-resolve
````

For mysql, <b>remember to run `sudo mysql_secure_installation`</b>, answer as suggested, add/change root password, remove test users etc. <b>Only exception!</b> Answer with <kbd>n</kbd> to the question <code>Disallow root login remotely? [Y/n]</code>. Your logs can be found at `/usr/local/var/mysql/yourcomputername.err` (where yourcomputername is obviously your hostname).

After that, get to know [dudestack](https://github.com/digitoimistodude/dudestack) to get everything up and running smoothly. Current version of dudestack supports macOS LEMP stack.

If you face `Host '127.0.0.1' is not allowed to connect to this MySQL server` mysql connection error, either comment `skip-name-resolve` line in my.cnf or update host column for mysql user. Example of this: `UPDATE mysql.user SET host='%' WHERE user='root';`

### Use Linux-style aliases

Add this to */usr/local/bin/service* and chmod it +x:

```` bash
#!/bin/bash
# Alias for unix type of commands
brew services "$2" "$1";
````

Now you are able to restart nginx and mysql unix style like this:

```` bash
service nginx restart
service mysql@5.7 restart
````

### File sizes

You might want to increase file sizes for development environment in case you need to test compression plugins and other stuff in WordPress. To do so, edit `/usr/local/etc/php/7.4/php-fpm.d/www.conf` and `/usr/local/etc/php/7.4/php.ini` and change all **memory_limit**, **post_max_size** and **upload_max_filesize** to something that is not so limited, for example **500M**.

Please note, you also need to change **client_max_body_size** to the same amount in `/etc/nginx/nginx.conf`. After this, restart php-fpm with `brew services restart php@7.4` and nginx with `brew services restart nginx`.

### Certificates for localhost

First things first, if you haven't done it yet, generate general dhparam:

```` bash
sudo su -
cd /etc/ssl/certs
openssl dhparam -out dhparam.pem 4096 
````

Generating certificates for dev environment is easiest with [mkcert](https://github.com/FiloSottile/mkcert). After installing mkcert, just run:

```` bash
mkdir -p /var/www/certs && cd /var/www/certs && mkcert "project.test"
````

Then edit your vhost as following (change all from *project* to your project name):

```` nginx
server {
    listen 443 ssl http2;
    root /var/www/project;
    index index.php;    
    server_name project.test;

    include php7.conf;
    include global/wordpress.conf;

    ssl_certificate /var/www/certs/project.test.pem;
    ssl_certificate_key /var/www/certs/project.test-key.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security max-age=15768000;
}

server {
    listen 80;
    server_name project.test;
    return 301 https://$host$request_uri;
}
````

Test with `nginx -t` and if everything is OK, restart nginx.

### XDebug
1. Install xdebug `pecl install xdebug`
2. Check `php --version`, it should display something like this:

``` shell
$ php --version
PHP 7.4.16 (cli) (built: Aug  7 2020 18:56:36) ( NTS )
Copyright (c) The PHP Group
Zend Engine v3.3.21, Copyright (c) Zend Technologies
    with Xdebug v3.0.3, Copyright (c), by Derick Rethans
    with Zend OPcache v7.4.16, Copyright (c), by Zend Technologies
```

3. Check where your php.ini file is with `php --ini`
4. Edit php.ini, for example `sudo nano /usr/local/etc/php/7.4/php.ini`
5. Make sure these are on the first lines:

```
zend_extension="xdebug.so"
xdebug.mode=debug
```

The following steps are usually optional:

6. Save and close with <kbd>ctrl</kbd> + <kbd>O</kbd> and <kbd>ctrl</kbd> + <kbd>X</kbd>
7. Make sure the log exists `sudo touch /var/log/xdebug.log && sudo chmod 777 /var/log/xdebug.log`
8. Restart services (requires [Linux-style aliases](#use-linux-style-aliases)) `service php@7.4 restart && service nginx restart`

``` json
{
  "version": "0.2.0",
  "configurations": [
    {
      //"debugServer": 4711, // Uncomment for debugging the adapter
      "name": "Listen for Xdebug",
      "type": "php",
      "request": "launch",
      "port": 9003,
      "log": true
    },
    {
      //"debugServer": 4711, // Uncomment for debugging the adapter
      "name": "Launch",
      "request": "launch",
      "type": "php",
      "program": "${file}",
      "cwd": "${workspaceRoot}",
      "externalConsole": false
    }
  ]
}
```
9. Xdebug should now work on your editor
10. PHPCS doesn't need xdebug but will warn about it not working... this causes error in [phpcs-vscode](https://marketplace.visualstudio.com/items?itemName=ikappas.phpcs) because it depends on outputted phpcs json that is not valid with the warning _"Xdebug: [Step Debug] Could not connect to debugging client. Tried: 127.0.0.1:9003 (through xdebug.client_host/xdebug.client_port) :-(_". This can be easily fixed by installing a bash "wrapper":
11. Rename current phpcs with `sudo mv /usr/local/bin/phpcs /usr/local/bin/phpcs.bak`
12. Install new with `sudo nano /usr/local/bin/phpcs`:

``` bash
#!/bin/bash
XDEBUG_MODE=off /Users/rolle/Projects/phpcs/bin/phpcs "$@"
```

14. Add permissions `sudo chmod +x /usr/local/bin/phpcs`
15. Make sure VSCode settings.json has this setting:

``` json
"phpcs.executablePath": "/usr/local/bin/phpcs",
```

### Troubleshooting

If you have something like this in your /var/log/nginx/error.log:

```
2019/08/12 14:09:04 [crit] 639#0: *129 open() "/usr/local/var/run/nginx/client_body_temp/0000000005" failed (13: Permission denied), client: 127.0.0.1, server: project.test, request: "POST /wp/wp-admin/async-upload.php HTTP/1.1", host: "project.test", referrer: "http://project.test/wp/wp-admin/upload.php"
```

If you cannot login to mysql from other than localhost, please answer with <kbd>n</kbd> to the question <code>Disallow root login remotely? [Y/n]</code> when running <code>mysql_secure_install</code>.

**Make sure you run nginx and php-fpm on your root user and mariadb on your regular user**. This is important. Stop nginx from running on your default user by `brew services stop nginx` and run it with sudo `sudo brew services start nginx`.

<code>sudo brew services list</code> should look like this:

``` shell
~ sudo brew services list
Name       Status  User  Plist
dnsmasq    started root  /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist
mariadb    started rolle /Users/rolle/Library/LaunchAgents/homebrew.mxcl.mariadb.plist
nginx      started root  /Library/LaunchDaemons/homebrew.mxcl.nginx.plist
php@7.3    started root  /Library/LaunchDaemons/homebrew.mxcl.php@7.3.plist
```

You may have "unknown" as status or different PHP version, but **User** should be like in the list above. Then everything should work.  
