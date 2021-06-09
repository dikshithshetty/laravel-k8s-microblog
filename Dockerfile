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
FROM nginx:1.21.0-alpine

WORKDIR /app

COPY docker/nginx.default.conf /etc/nginx/conf.d/default.conf
RUN nginx -s reload
EXPOSE 80

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

