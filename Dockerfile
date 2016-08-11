FROM php:7.0.7

# Install all packages
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        curl \
        redis-server \
        libz-dev \
        libpq-dev \
        graphviz \
        supervisor \
        libpng12-dev \
        apt-utils \
        wget \
        vim-tiny \
    && docker-php-ext-install -j$(nproc) iconv \
    && docker-php-ext-install -j$(nproc) mcrypt \
    && docker-php-ext-install -j$(nproc) pdo_mysql \
    && docker-php-ext-install -j$(nproc) zip \
    && docker-php-ext-configure gd --with-png-dir=/usr --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install bcmath opcache

# Install xdebug
RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/xdebug.ini

RUN apt-get clean

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

# Copy binaries for drupal console and drush
COPY docker-config/drupal /usr/bin/drupal
COPY docker-config/drush /usr/bin/drush

# init drush and drupal console and make them executable
RUN chmod +x /usr/bin/drupal
RUN drupal init -y
RUN chmod +x /usr/bin/drush
RUN drush init -y
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/bin/composer

# Create drone and result storage
RUN mkdir /drone
RUN mkdir /results

# Install all CS and Test Tools
RUN wget https://phar.phpunit.de/phploc.phar && \
    chmod +x phploc.phar && \
    mv phploc.phar /usr/bin/phploc

RUN wget http://static.pdepend.org/php/latest/pdepend.phar && \
	  chmod +x pdepend.phar && \
	  mv pdepend.phar /usr/bin/pdepend

RUN wget http://static.pdepend.org/php/latest/pdepend.phar && \
	  chmod +x pdepend.phar && \
	  mv pdepend.phar /usr/bin/phpmd

RUN wget http://static.phpmd.org/php/latest/phpmd.phar && \
	  chmod +x phpmd.phar && \
	  mv phpmd.phar /usr/bin/phpcs

RUN wget https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar && \
	  chmod +x phpcbf.phar && \
	  mv phpcbf.phar /usr/bin/phpcbf

RUN wget https://phar.phpunit.de/phpcpd.phar && \
	  chmod +x phpcpd.phar && \
	  mv phpcpd.phar /usr/bin/phpcpd

RUN wget https://phar.phpunit.de/phpdcd.phar && \
	  chmod +x phpdcd.phar && \
	  mv phpdcd.phar /usr/bin/phpdcd

RUN wget https://github.com/Halleck45/PhpMetrics/raw/master/build/phpmetrics.phar && \
	  chmod +x phpmetrics.phar && \
	  mv phpmetrics.phar /usr/bin/phpmetrics

RUN wget http://get.sensiolabs.org/php-cs-fixer.phar && \
	  chmod +x php-cs-fixer.phar && \
	  mv php-cs-fixer.phar /usr/bin/php-cs-fixer

RUN wget http://codeception.com/codecept.phar && \
	  chmod +x codecept.phar && \
	  mv codecept.phar /usr/bin/codecept

# Download Drupal CS Standards
RUN composer global require drupal/coder:dev-8.x-2.x

# Add Drupal CS Standard to Code Sniffer
RUN phpcs --config-set installed_paths ~/.composer/vendor/drupal/coder/coder_sniffer

# Add helper script for running all cs tests
ADD docker-config/checkstyle.sh /usr/bin/checkstyle.sh
RUN chmod +x /usr/bin/checkstyle.sh

# Expose volumes
VOLUME /drone
VOLUME /results

# Expose Drone Dir
ENV DRONE_DIR /drone
