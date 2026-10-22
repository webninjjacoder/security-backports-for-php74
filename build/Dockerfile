# Build environment: Ubuntu 20.04 (focal), amd64, with everything php7.4 needs to build.
# Usage: see build/build.sh (run from the repository root).
FROM --platform=linux/amd64 ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8

RUN printf '%s\n' \
      'deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse' \
      'deb http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse' \
      'deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse' \
      'deb-src http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse' \
      'deb-src http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse' \
      'deb-src http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse' \
      > /etc/apt/sources.list

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      build-essential devscripts quilt fakeroot dpkg-dev equivs ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# mysql-server is a test-only build dependency. Its post-install starts and stops a
# temporary server, which can time out in containers (especially under emulation);
# the build itself never needs a working MySQL, so a failed post-install is neutralised.
RUN apt-get update -qq \
 && (apt-get build-dep -y -qq php7.4 \
     || { printf '#!/bin/sh\nexit 0\n' > /var/lib/dpkg/info/mysql-server-8.0.postinst \
          && dpkg --configure -a && apt-get build-dep -y -qq php7.4; }) \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
