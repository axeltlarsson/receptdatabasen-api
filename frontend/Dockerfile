# Only for building the frontend
# parcel/elm has elm as dep whose npm package is not arm64 compatible
# so we simply run this with x86 instead as on prod, locally I'd use nix's
# version of elm (compiled for aarch64) anyway
# Step 1: Base Node.js image
FROM node:bookworm
LABEL org.opencontainers.image.source=https://github.com/axeltlarsson/receptdatabasen-api
LABEL org.opencontainers.image.description="Receptdatabasen frontend"

WORKDIR /app

# Step 2: Install Elm binary manually
RUN curl -L https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz -o elm.gz \
    && gunzip elm.gz \
    && chmod +x elm \
    && mv elm /usr/local/bin/elm

# Step 3: Copy package files and install dependencies without running scripts so we ignore the failing elm install script
COPY package*.json ./
RUN npm ci --ignore-scripts

# Step 4: Copy remaining source files
COPY ./ ./

# Step 5: Build directly without using the npm script
RUN rm -rf dist && npx parcel build
