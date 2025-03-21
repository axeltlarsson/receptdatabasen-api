FROM openresty/openresty:1.27.1.1-0-noble

# Install runtime dependencies
RUN DEBIAN_FRONTEND=noninteractive \
      apt-get update && \
      apt-get install --no-install-recommends -y \
      libvips \
      libglib2.0-0 libjpeg-turbo8 libpng16-16 libwebp-dev \
      libwebp7 libwebpmux3 libwebpdemux2 libtiff6 libgif7 libexif12 libxml2 \
      libgsf-1-114 libfftw3-bin liborc-0.4-0 librsvg2-2 libheif1 && \
      apt-get autoremove -y && \
      apt-get autoclean && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure LuaRocks to recognize LuaJIT as providing luaffi-tkl
RUN luarocks config --lua-version=5.1 rocks_provided.luaffi-tkl 2.1-1

RUN luarocks install lua-vips 1.1-11 && \
    luarocks install lua-resty-session 4.0.5-1 && \
    luarocks install lua-resty-jwt 0.2.3-0 && \
    luarocks install lua-resty-http 0.17.2-0 && \
    luarocks install lua-resty-template 2.0

# the libvips provided by apt-get is versioned libvips.so.42 but lua-vips expects it to be named libvips.so
# so let's symlink it and refresh the linker cache
# the uname -m gives us the architecture of the system, e.g. x86_64, or aarch64 like when running on Apple Silicon
RUN ln -s /lib/$(uname -m)-linux-gnu/libvips.so.42 /lib/$(uname -m)-linux-gnu/libvips.so && ldconfig

# https://github.com/ledgetech/lua-resty-http/issues/42
RUN cp /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.pem

RUN mkdir -p /uploads/cache && chown -R nobody /uploads
VOLUME /uploads

COPY --from=ghcr.io/axeltlarsson/receptdatabasen-frontend:latest /app/dist /usr/local/openresty/nginx/html
COPY nginx /usr/local/openresty/nginx/conf
COPY nginx_prod /usr/local/openresty/nginx/conf/prod
COPY lua /usr/local/openresty/nginx/lua

EXPOSE 80
