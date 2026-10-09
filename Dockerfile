FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG SKYFIRE_REF=main
ARG BUILD_JOBS=4

ENV CC=gcc-14
ENV CXX=g++-14
ENV BOOST_ROOT=/opt/boost_1_91_0
ENV OPENSSL_ROOT_DIR=/opt/openssl-4.0.1
ENV LD_LIBRARY_PATH=/opt/openssl-4.0.1/lib64:/opt/openssl-4.0.1/lib

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      software-properties-common \
      ca-certificates && \
    add-apt-repository -y universe && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      gcc-14 \
      g++-14 \
      cmake \
      ninja-build \
      git \
      wget \
      perl \
      pkg-config \
      bzip2 \
      libbz2-dev \
      libreadline-dev \
      zlib1g-dev \
      default-libmysqlclient-dev \
      libace-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Boost headers
WORKDIR /tmp/deps

RUN wget -q https://archives.boost.io/release/1.91.0/source/boost_1_91_0.tar.gz && \
    tar -xzf boost_1_91_0.tar.gz && \
    cd boost_1_91_0 && \
    ./bootstrap.sh --prefix=/opt/boost_1_91_0 && \
    ./b2 install \
      --prefix=/opt/boost_1_91_0 \
      --with-headers \
      -j${BUILD_JOBS} && \
    rm -rf /tmp/deps/boost_1_91_0*

# Build OpenSSL with the legacy provider
RUN wget -q https://www.openssl.org/source/openssl-4.0.1.tar.gz && \
    tar -xzf openssl-4.0.1.tar.gz && \
    cd openssl-4.0.1 && \
    ./Configure linux-x86_64 \
      --prefix=/opt/openssl-4.0.1 \
      --openssldir=/opt/openssl-4.0.1/ssl \
      shared enable-legacy && \
    make -j${BUILD_JOBS} && \
    make install_sw install_ssldirs && \
    rm -rf /tmp/deps/openssl-4.0.1*

# Fetch SkyFire source
WORKDIR /src

RUN git clone \
      https://github.com/ProjectSkyfire/SkyFire_548.git . && \
    git checkout "${SKYFIRE_REF}"

# Configure, compile and install.
# PCH is enabled by default: do not pass -DNOPCH=1.
RUN cmake -S . -B build/docker -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/skyfire-server \
      -DCMAKE_C_COMPILER=gcc-14 \
      -DCMAKE_CXX_COMPILER=g++-14 \
      -DBOOST_ROOT=/opt/boost_1_91_0 \
      -DOPENSSL_ROOT_DIR=/opt/openssl-4.0.1 \
      -DTOOLS=ON \
      -DAUTH_SERVER=ON \
      -DSCRIPTS=ON && \
    cmake --build build/docker --parallel "${BUILD_JOBS}" && \
    cmake --install build/docker && \
    test -x /opt/skyfire-server/bin/authserver && \
    test -x /opt/skyfire-server/bin/worldserver

# Stage 2: Runtime only
FROM ubuntu:24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

# Install runtime libraries only; no compiler or build tools.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      libstdc++6 \
      libgcc-s1 \
      libmariadb3 \
      libbz2-1.0 \
      libreadline8t64 \
      zlib1g \
      netcat-openbsd \
      default-mysql-client \
      curl \
      unzip && \
    rm -rf /var/lib/apt/lists/*

# Copy the installed server, custom OpenSSL runtime and SQL migrations/base files.
COPY --from=builder /opt/skyfire-server /opt/skyfire-server
COPY --from=builder /opt/openssl-4.0.1 /opt/openssl-4.0.1
COPY --from=builder /src/sql /opt/skyfire-server/sql

# Preserve default configurations so volume mounts over /opt/skyfire-server/etc don't hide them
RUN cp -r /opt/skyfire-server/etc /opt/skyfire-server/etc.default 2>/dev/null || true

# Register OpenSSL libraries and locate the legacy provider.
RUN set -eux; \
    module_dir="$(find /opt/openssl-4.0.1 -type d -name ossl-modules -print -quit)"; \
    test -n "$module_dir"; \
    ln -s "$module_dir" /opt/openssl-4.0.1/ossl-modules; \
    printf '%s\n' \
      '/opt/openssl-4.0.1/lib' \
      '/opt/openssl-4.0.1/lib64' \
      > /etc/ld.so.conf.d/skyfire-openssl.conf; \
    ldconfig

ENV LD_LIBRARY_PATH=/opt/openssl-4.0.1/lib64:/opt/openssl-4.0.1/lib
ENV OPENSSL_MODULES=/opt/openssl-4.0.1/ossl-modules

WORKDIR /opt/skyfire-server

# Add entrypoint for automated configuration and startup
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["worldserver"]
