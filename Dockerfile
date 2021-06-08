# run laravel mix to compile assets
FROM node:14-alpine

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install

COPY webpack.mix.js ./
COPY resources ./resources
COPY public ./public

RUN npm run production

# final nginx image
FROM nginx:mainline

WORKDIR /app

COPY docker/nginx.default.conf /etc/nginx/conf.d/default.conf

# Use the composer image to install the Laravel dependencies
FROM composer AS composerStage

WORKDIR /app

COPY composer.json composer.lock ./
COPY database ./database

RUN composer install --prefer-dist --optimize-autoloader --ignore-platform-reqs --no-scripts

# PHP-FPM base image with dependencies
FROM php:7.2-fpm-alpine
RUN apk add --no-cache \
    build-base autoconf \
    openssl-dev \
    libmcrypt-dev \
    libxml2-dev

RUN pecl install mcrypt-1.0.1 redis-5.2.0 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-enable redis \
    && docker-php-ext-install pcntl \
    && docker-php-ext-install pdo pdo_mysql \
    && docker-php-ext-install bcmath

WORKDIR /app

COPY . .
RUN mkdir -p ./storage/app ./storage/framework ./storage/logs ./bootstrap/cache ./storage/app/public ./storage/app ./storage/framework/cache ./storage/framework/cache/data ./storage/framework/testing ./storage/framework/sessions ./storage/framework ./storage/framework/views ./storage/logs
RUN chown -R www-data:www-data ./storage ./bootstrap/cache




# Install PHP
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-cedar-14-master/php-$PHP_VERSION.tar.gz | tar xz -C /app/.heroku/php
# Config
RUN mkdir -p /app/.heroku/php/etc/php/conf.d
RUN curl --silent --location https://raw.githubusercontent.com/heroku/heroku-buildpack-php/5a770b914549cf2a897cbbaf379eb5adf410d464/conf/php/php.ini > /app/.heroku/php/etc/php/php.ini
# Enable all optional exts
RUN echo "\n\
user_ini.cache_ttl = 30 \n\
zend_extension = opcache.so \n\
opcache.enable_cli = 1 \n\
opcache.validate_timestamps = 1 \n\
opcache.revalidate_freq = 0 \n\
opcache.fast_shutdown = 0 \n\
extension=bcmath.so \n\
extension=calendar.so \n\
extension=exif.so \n\
extension=ftp.so \n\
extension=gd.so \n\
extension=gettext.so \n\
extension=intl.so \n\
extension=mbstring.so \n\
extension=pcntl.so \n\
extension=shmop.so \n\
extension=soap.so \n\
extension=sqlite3.so \n\
extension=pdo_sqlite.so \n\
extension=xmlrpc.so \n\
extension=xsl.so\n\
" >> /app/.heroku/php/etc/php/php.ini

# Install Composer
RUN curl --silent --location "https://lang-php.s3.amazonaws.com/dist-cedar-14-master/composer-1.0.0alpha11.tar.gz" | tar xz -C /app/.heroku/php

# copy dep files first so Docker caches the install step if they don't change
ONBUILD COPY composer.lock /app
ONBUILD COPY composer.json /app
# run install but without scripts as we don't have the app source yet
ONBUILD RUN composer install --no-scripts
# require the buildpack for execution
ONBUILD RUN composer show --installed heroku/heroku-buildpack-php || { echo 'Your composer.json must have "heroku/heroku-buildpack-php" as a "require-dev" dependency.'; exit 1; }
# rest of app
ONBUILD ADD . /app
# run install hooks
ONBUILD RUN cat composer.json | python -c 'import sys,json; sys.exit("post-install-cmd" not in json.load(sys.stdin).get("scripts", {}));' && composer run-script post-install-cmd || true

# TODO: run "composer compile", like Heroku?

# ENTRYPOINT ["/usr/bin/init.sh"
