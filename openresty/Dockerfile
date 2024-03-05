# Build vips in a builder container, taken from:
# https://github.com/h2non/imaginary/blob/master/Dockerfile
ARG GOLANG="1.13"
FROM --platform=linux/amd64 golang:${GOLANG}  as builder

ARG LIBVIPS_VERSION="8.12.2"

# Installs libvips + required libraries
RUN DEBIAN_FRONTEND=noninteractive \
      apt-get update && \
      apt-get install --no-install-recommends -y \
      ca-certificates \
      automake build-essential curl \
      gobject-introspection gtk-doc-tools libglib2.0-dev libjpeg62-turbo-dev libpng-dev \
      libwebp-dev libtiff5-dev libgif-dev libexif-dev libxml2-dev \
      swig libgsf-1-dev fftw3-dev liborc-0.4-dev librsvg2-dev libheif-dev && \
      cd /tmp && \
      curl -fsSLO https://github.com/libvips/libvips/releases/download/v${LIBVIPS_VERSION}/vips-${LIBVIPS_VERSION}.tar.gz && \
      tar zvxf vips-${LIBVIPS_VERSION}.tar.gz && \
      cd /tmp/vips-${LIBVIPS_VERSION} && \
        CFLAGS="-g -O3" CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -g -O3" \
        ./configure \
        --disable-debug \
        --disable-dependency-tracking \
        --disable-introspection \
        --disable-static \
        --enable-gtk-doc-html=no \
        --enable-gtk-doc=no \
        --enable-pyvips8=no \
        --without-magick \
        --without-pdfium \
        --without-poppler \
        --without-pangoft2 \
        --without-cfitsio \
        --without-OpenEXR \
        --without-nifti \
        --without-openslide && \
      make && \
      make install && \
      ldconfig

# The final openresty image
FROM --platform=linux/amd64 openresty/openresty:buster
LABEL org.opencontainers.image.source=https://github.com/axeltlarsson/receptdatabasen-api
LABEL org.opencontainers.image.description="Receptdatabasen openresty"

COPY --from=builder /usr/local/lib /usr/local/lib

# Install runtime dependencies
RUN DEBIAN_FRONTEND=noninteractive \
      apt-get update && \
      apt-get install --no-install-recommends -y \
      libglib2.0-0 libjpeg62-turbo libpng16-16 \
      libwebp6 libwebpmux3 libwebpdemux2 libtiff5 libgif7 libexif12 libxml2 \
      libgsf-1-114 fftw3 liborc-0.4-0 librsvg2-2 libheif1 && \
      apt-get autoremove -y && \
      apt-get autoclean && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install luarocks
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
      && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      luarocks

# Install lua-vips
RUN luarocks install lua-vips
RUN luarocks install lua-resty-session

RUN mkdir -p /uploads/cache && chown -R nobody /uploads
VOLUME /uploads

COPY --from=receptdatabasen_frontend_builder /app/dist /usr/local/openresty/nginx/html
COPY nginx /usr/local/openresty/nginx/conf
COPY nginx_prod /usr/local/openresty/nginx/conf/prod
COPY lua /usr/local/openresty/lua

EXPOSE 80
