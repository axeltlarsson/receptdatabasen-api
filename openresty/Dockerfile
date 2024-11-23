FROM --platform=linux/amd64 openresty/openresty:1.27.1.1-0-noble

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
    luarocks install lua-resty-session 4.0.5-1

# the libvips provided by apt-get is versioned libvips.so.42 but lua-vips expects it to be named libvips.so
# so let's symlink it and refresh the linker cache
RUN ln -s /lib/x86_64-linux-gnu/libvips.so.42 /lib/x86_64-linux-gnu/libvips.so && ldconfig

RUN mkdir -p /uploads/cache && chown -R nobody /uploads
VOLUME /uploads

# COPY --from=receptdatabasen_frontend_builder /app/dist /usr/local/openresty/nginx/html
COPY --from=ghcr.io/axeltlarsson/receptdatabasen-frontend /app/dist /usr/local/openresty/nginx/html
COPY nginx /usr/local/openresty/nginx/conf
COPY nginx_prod /usr/local/openresty/nginx/conf/prod
COPY lua /usr/local/openresty/lua

EXPOSE 80
