# Use nix to build vips as it's already neatly packaged in nixpkgs
FROM --platform=linux/amd64 nixos/nix:latest as builder

RUN nix-env \
  --option filter-syscalls false \
  -iA nixpkgs.vips

RUN mkdir /tmp/nix-store-closure
# first get the closure of the vips package and copy to /tmp/nix-store-closure
RUN nix-store -qR $(nix-env --out-path --query vips | grep -oP 'bin=\K[^;]+') | xargs -I{} cp -R {} /tmp/nix-store-closure
# then get the location of the vips binary and copy to /usr/bin/vips
RUN cp -R $(nix-env --out-path --query vips | grep -oP 'bin=\K[^;]+') /usr/bin/vips

# The final openresty image
FROM --platform=linux/amd64 openresty/openresty:1.27.1.1-0-noble

COPY --from=builder /tmp/nix-store-closure /nix/store
# get the vips binary - probably actually not necessary as all we care about is the lib, still nice to have I suppose
COPY --from=builder /usr/bin/vips/bin/* /usr/bin/

# Install runtime dependencies
RUN DEBIAN_FRONTEND=noninteractive \
      apt-get update && \
      apt-get install --no-install-recommends -y \
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

# link libvips.so to /usr/local/lib so that the dynamic linker can find it, and update the dynamic linker cache
RUN ln -s $(find /nix/store -name libvips.so) /usr/local/lib && ldconfig

RUN mkdir -p /uploads/cache && chown -R nobody /uploads
VOLUME /uploads

# COPY --from=receptdatabasen_frontend_builder /app/dist /usr/local/openresty/nginx/html
COPY --from=ghcr.io/axeltlarsson/receptdatabasen-frontend /app/dist /usr/local/openresty/nginx/html
COPY nginx /usr/local/openresty/nginx/conf
COPY nginx_prod /usr/local/openresty/nginx/conf/prod
COPY lua /usr/local/openresty/lua

EXPOSE 80
