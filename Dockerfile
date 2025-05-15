# Dockerfile for Drupal with New Relic PHP Agent

# Use an official PHP image as a parent image
# Choose a PHP version compatible with the desired Drupal version (e.g., PHP 8.1 for Drupal 9/10)
FROM php:8.1-apache

# Set environment variables for New Relic
# The license key will need to be provided at build time or runtime
ARG NEW_RELIC_LICENSE_KEY="YOUR_LICENSE_KEY"
ENV NEW_RELIC_APP_NAME="Drupal Application"
ENV NEW_RELIC_LOG_LEVEL="info"
# Address for the New Relic daemon (assumed to be running separately)
ENV NEW_RELIC_DAEMON_ADDRESS="newrelic-daemon:31339"
ENV NEW_RELIC_DAEMON_START_TIMEOUT="5s"
ENV NEW_RELIC_ENABLED="true"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libxml2-dev \
    unzip \
    wget \
    git \
    # Dependencies for New Relic PHP Agent
    gnupg \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions required by Drupal
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo pdo_mysql opcache zip soap xml

# Install New Relic PHP Agent
# Download and install the agent (using the generic Linux tarball, not musl)
RUN wget -O /tmp/newrelic.tar.gz "https://download.newrelic.com/php_agent/release/newrelic-php5-latest-linux.tar.gz" \
    && cd /tmp && tar -xzf newrelic.tar.gz \
    && cd newrelic-php5-* \
    # NR_INSTALL_SILENT=1 ensures non-interactive installation.
    # The installer should place newrelic.ini in the correct PHP scan directory.
    && NR_INSTALL_SILENT=1 ./newrelic-install install \
    && rm -rf /tmp/newrelic.tar.gz /tmp/newrelic-php5-* \
    # Configure New Relic Agent. The newrelic-install script might set some of these if NR_INSTALL_KEY is used,
    # but explicit sed ensures settings. The path /usr/local/etc/php/conf.d/newrelic.ini is standard for these images.
    && PHP_INI_DIR=$(php -r "echo ini_get(\'scan_dir\');" || echo "/usr/local/etc/php/conf.d") \
    && NEW_RELIC_INI_FILE="${PHP_INI_DIR}/newrelic.ini" \
    # Check if the file exists, newrelic-install should create it.
    && if [ ! -f "${NEW_RELIC_INI_FILE}" ]; then echo "Error: newrelic.ini not found at ${NEW_RELIC_INI_FILE}"; exit 1; fi \
    && sed -i \
        -e "s/newrelic.license =.*/newrelic.license = \"${NEW_RELIC_LICENSE_KEY}\"/" \
        -e "s/newrelic.appname =.*/newrelic.appname = \"${NEW_RELIC_APP_NAME}\"/" \
        -e "s/;newrelic.daemon.address =.*/newrelic.daemon.address = \"${NEW_RELIC_DAEMON_ADDRESS}\"/" \
        -e "s/;newrelic.daemon.dont_launch =.*/newrelic.daemon.dont_launch = 3/" \
        -e "s/;newrelic.enabled =.*/newrelic.enabled = ${NEW_RELIC_ENABLED}/" \
        "${NEW_RELIC_INI_FILE}"

# Download and install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set up Drupal
# Define Drupal version
ARG DRUPAL_VERSION=9.5.11
WORKDIR /var/www/html

# Download Drupal core using Composer (recommended method)
# This creates a project, downloads Drupal and its dependencies
RUN composer create-project drupal/recommended-project:^${DRUPAL_VERSION} drupal-app --no-interaction

# Move Drupal files to the web root and clean up
RUN mv drupal-app/* . && mv drupal-app/.* . && rmdir drupal-app \
    && chown -R www-data:www-data /var/www/html

# Configure Apache for Drupal
# Enable Apache rewrite module
RUN a2enmod rewrite

# Ensure AllowOverride All is set for the Drupal directory in Apache conf
RUN sed -i '/<Directory \/var\/www\/html>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Expose port 80 for Apache
EXPOSE 80

# Start Apache
CMD ["apache2-foreground"]

# Instructions for building and running:
# 1. Build the image, providing your New Relic license key:
#    docker build --build-arg NEW_RELIC_LICENSE_KEY="YOUR_ACTUAL_KEY" -t drupal-newrelic .
# 2. Run the New Relic daemon container (example):
#    docker run -d --name newrelic-daemon newrelic/php-daemon
# 3. Run the Drupal application container, linking to the daemon or on the same network:
#    docker run -d -p 8080:80 --name my-drupal-app --network=<your_network_or_link_to_daemon> drupal-newrelic
#    (Ensure <your_network_or_link_to_daemon> allows resolving "newrelic-daemon")
# 4. Drupal installation (database setup, site configuration) needs to be done after the container starts by accessing it via your browser (e.g., http://localhost:8080).
# 5. For a truly "fail-proof" setup, manage both the Drupal app and New Relic daemon containers using Docker Compose or Kubernetes for robustness, restarts, and health checks.

