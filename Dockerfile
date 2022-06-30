# IB: Build the acme-dns server binary in its own layer. Adapted from https://github.com/joohoi/acme-dns/blob/master/Do>FROM golang:alpine AS builder
FROM golang:alpine AS builder
RUN apk add --update gcc musl-dev git

ENV GOPATH /tmp/buildcache
RUN git clone https://github.com/joohoi/acme-dns /tmp/acme-dns
WORKDIR /tmp/acme-dns
RUN CGO_ENABLED=1 go build

# Begin original file
FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.14

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CERTBOT_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# environment settings
ENV DHLEVEL=2048 ONLY_SUBDOMAINS=false AWS_CONFIG_FILE=/config/dns-conf/route53.ini
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV PYTHONUNBUFFERED=1

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    cargo \
    g++ \
    gcc \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    openssl-dev \
    python3-dev && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache --upgrade \
    curl \
    fail2ban \
    gnupg \
    memcached \
    nginx \
    nginx-mod-http-brotli \
    nginx-mod-http-dav-ext \
    nginx-mod-http-echo \
    nginx-mod-http-fancyindex \
    nginx-mod-http-geoip2 \
    nginx-mod-http-headers-more \
    nginx-mod-http-image-filter \
    nginx-mod-http-nchan \
    nginx-mod-http-perl \
    nginx-mod-http-redis2 \
    nginx-mod-http-set-misc \
    nginx-mod-http-upload-progress \
    nginx-mod-http-xslt-filter \
    nginx-mod-mail \
    nginx-mod-rtmp \
    nginx-mod-stream \
    nginx-mod-stream-geoip2 \
    nginx-vim \
    php7-bcmath \
    php7-bz2 \
    php7-ctype \
    php7-curl \
    php7-dom \
    php7-exif \
    php7-ftp \
    php7-gd \
    php7-gmp \
    php7-iconv \
    php7-imap \
    php7-intl \
    php7-ldap \
    php7-mcrypt \
    php7-memcached \
    php7-mysqli \
    php7-mysqlnd \
    php7-opcache \
    php7-pdo_mysql \
    php7-pdo_odbc \
    php7-pdo_pgsql \
    php7-pdo_sqlite \
    php7-pear \
    php7-pecl-apcu \
    php7-pecl-mailparse \
    php7-pecl-redis \
    php7-pgsql \
    php7-phar \
    php7-posix \
    php7-soap \
    php7-sockets \
    php7-sodium \
    php7-sqlite3 \
    php7-tokenizer \
    php7-xml \
    php7-xmlreader \
    php7-xmlrpc \
    php7-xsl \
    php7-zip \
    py3-cryptography \
    py3-future \
    py3-pip \
    whois \
  # Install python so that the manual auth hook script can run
    python3 && \
  ln -sf python3 /usr/bin/python && \
  # Symlink pythin into the path
  echo "**** install certbot plugins ****" && \
  if [ -z ${CERTBOT_VERSION+x} ]; then \
    CERTBOT="certbot"; \
  else \
    CERTBOT="certbot==${CERTBOT_VERSION}"; \
  fi && \
  pip3 install -U \
    pip && \
  pip3 install -U --find-links https://wheel-index.linuxserver.io/alpine/ \
    ${CERTBOT} \
    certbot-dns-aliyun \
    certbot-dns-azure \
    certbot-dns-cloudflare \
    certbot-dns-cloudxns \
    certbot-dns-cpanel \
    certbot-dns-desec \
    certbot-dns-digitalocean \
    certbot-dns-directadmin \
    certbot-dns-dnsimple \
    certbot-dns-dnsmadeeasy \
    certbot-dns-dnspod \
    certbot-dns-domeneshop \
    certbot-dns-google \
    certbot-dns-he \
    certbot-dns-hetzner \
    certbot-dns-infomaniak \
    certbot-dns-inwx \
    certbot-dns-ionos \
    certbot-dns-linode \
    certbot-dns-loopia \
    certbot-dns-luadns \
    certbot-dns-netcup \
    certbot-dns-njalla \
    certbot-dns-nsone \
    certbot-dns-ovh \
    certbot-dns-rfc2136 \
    certbot-dns-route53 \
    certbot-dns-standalone \
    certbot-dns-transip \
    certbot-dns-vultr \
    certbot-dns-desec \
    certbot-plugin-gandi \
    cryptography \
    requests && \
  echo "**** correct ip6tables legacy issue ****" && \
  rm \ 
    /sbin/ip6tables && \
  ln -s \
    /sbin/ip6tables-nft /sbin/ip6tables && \
  echo "**** remove unnecessary fail2ban filters ****" && \
  rm \
    /etc/fail2ban/jail.d/alpine-ssh.conf && \
  echo "**** copy fail2ban default action and filter to /default ****" && \
  mkdir -p /defaults/fail2ban && \
  mv /etc/fail2ban/action.d /defaults/fail2ban/ && \
  mv /etc/fail2ban/filter.d /defaults/fail2ban/ && \
  echo "**** copy proxy confs to /default ****" && \
  mkdir -p /defaults/proxy-confs && \
  curl -o \
    /tmp/proxy.tar.gz -L \
    "https://github.com/linuxserver/reverse-proxy-confs/tarball/master" && \
  tar xf \
    /tmp/proxy.tar.gz -C \
    /defaults/proxy-confs --strip-components=1 --exclude=linux*/.gitattributes --exclude=linux*/.github --exclude=linux*/.gitignore --exclude=linux*/LICENSE && \
  echo "**** configure nginx ****" && \
  rm -f /etc/nginx/http.d/default.conf && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  for cleanfiles in *.pyc *.pyo; \
    do \
    find /usr/lib/python3.*  -iname "${cleanfiles}" -exec rm -f '{}' + \
    ; done && \
  rm -rf \
    /tmp/* \
    /root/.cache \
    /root/.cargo
# Copy in acme-dns binary, make necessary directories, and install necessary certs
COPY --from=builder /tmp/acme-dns /bin/
RUN mkdir -p /etc/acme-dns
RUN mkdir -p /var/lib/acme-dns
RUN rm -rf ./config.cfg
RUN apk --no-cache add ca-certificates && update-ca-certificates
# Back to linuxserver code  
# add local files
COPY root/ /

# Expose the necessary ports and volumes for acme-dns
VOLUME ["/etc/acme-dns", "/var/lib/acme-dns"]
EXPOSE 53 80 443
EXPOSE 53/udp
