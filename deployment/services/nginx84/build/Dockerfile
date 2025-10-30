FROM nginx:alpine

# Install PHP 8.4-FPM, openssl, MySQL client, and required extensions
RUN apk add --no-cache \
    openssl \
    mysql-client \
    php84 \
    php84-fpm \
    php84-mysqli \
    php84-pdo \
    php84-pdo_mysql \
    php84-json \
    php84-curl \
    php84-mbstring \
    php84-xml \
    php84-zip \
    php84-gd \
    php84-opcache \
    php84-tokenizer \
    php84-fileinfo \
    php84-intl \
    php84-bcmath \
    php84-openssl \
    php84-ctype \
    php84-dom \
    php84-phar \
    php84-session \
    php84-simplexml \
    php84-xmlreader \
    php84-xmlwriter \
    php84-zlib \
    php84-xdebug \
    php84-redis \
    php84-pgsql \
    php84-pdo_pgsql

# Configure PHP-FPM
RUN sed -i 's/listen = 127.0.0.1:9000/listen = 9000/' /etc/php84/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = www-data/listen.owner = nginx/' /etc/php84/php-fpm.d/www.conf \
    && sed -i 's/;listen.group = www-data/listen.group = nginx/' /etc/php84/php-fpm.d/www.conf \
    && sed -i 's/;listen.mode = 0660/listen.mode = 0660/' /etc/php84/php-fpm.d/www.conf \
    && sed -i 's/^;clear_env = no/clear_env = no/' /etc/php84/php-fpm.d/www.conf

# Create symlinks for php command
RUN ln -s /usr/bin/php84 /usr/bin/php \
    && ln -s /usr/sbin/php-fpm84 /usr/sbin/php-fpm

# Create startup script to run both nginx and php-fpm
RUN echo '#!/bin/sh' > /start.sh \
    && echo 'php-fpm84 -D' >> /start.sh \
    && echo 'nginx -g "daemon off;"' >> /start.sh \
    && chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
