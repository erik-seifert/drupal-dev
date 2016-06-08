FROM php:7.0.7-apache

ENV MYSQL_HOST mysql
ENV MYSQL_LOGIN drupal
ENV MYSQL_PASS drupal
ENV MYSQL_DB drupal
ENV NVM_VERSION v0.31.0
ENV NODE_VERSION v6.2.0
ENV PHPREDIS_VERSION 3.0.0-rc1
ENV DEBIAN_FRONTEND noninteractive
ENV NVM_DIR /usr/local/nvm

ENV NODE_PATH ~/$NODE_VERSION/lib/node_modules
ENV PATH      ~/$NODE_VERSION/bin:$PATH

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install all packages
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        curl \
        redis-server \
        libz-dev \
        libpq-dev \
        mysql-client \
        mysql-server \
        supervisor \
        libpng12-dev \
        apt-utils \
        openssh-server \
        vim-tiny \
        sudo \
    && docker-php-ext-install -j$(nproc) iconv \
    && docker-php-ext-install -j$(nproc) mcrypt \
    && docker-php-ext-install -j$(nproc) pdo_mysql \
    && docker-php-ext-install -j$(nproc) zip \
    && docker-php-ext-configure gd --with-png-dir=/usr --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install bcmath opcache

# Install php-redis extension
RUN curl -L -o /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/$PHPREDIS_VERSION.tar.gz \
    && tar xfz /tmp/redis.tar.gz \
    && rm -r /tmp/redis.tar.gz \
    && mv phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis \
    && docker-php-ext-install redis

RUN apt-get clean

RUN a2enmod rewrite

# get from https://github.com/docker-library/drupal/blob/master/8.1/apache/Dockerfile
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Copy default php.ini
COPY docker-config/php.ini /usr/local/etc/php/
COPY docker-config/my.drupal.cnf /etc/my.cnf.d

# Copy binaries for drupal console and drush
COPY docker-config/drupal /usr/bin/drupal
COPY docker-config/drush /usr/bin/drush

# init drush and drupal console and make them executable
RUN chmod +x /usr/bin/drupal
RUN drupal init -y
RUN chmod +x /usr/bin/drush
RUN drush init -y
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

RUN echo -e '<?php phpinfo(); ?>' >> /var/www/html/info.php

# Install NVM
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/${NVM_VERSION}/install.sh | bash

# Install NODE
RUN curl https://raw.githubusercontent.com/creationix/nvm/$NVM_VERSION/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

RUN echo %sudo	ALL=NOPASSWD: ALL >> /etc/sudoers

VOLUME /var/www/html
VOLUME /var/lib/mysql

RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd && chmod 0755 /var/run/sshd
RUN mkdir -p /root/.ssh/ && touch /root/.ssh/authorized_keys
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

RUN echo -e '[program:apache2]\ncommand=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -DFOREGROUND"\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:mysql]\ncommand=/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/sbin/mysqld\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:sshd]\ncommand=/usr/sbin/sshd -D\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:sshd]\ncommand=/usr/sbin/sshd -D\n\n' >> /etc/supervisor/supervisord.conf
# RUN echo -e '[program:redis]\ncommand=/usr/sbin/redis-server\n\n' >> /etc/supervisor/supervisord.conf

EXPOSE 80 3306 22
CMD exec supervisord -n
