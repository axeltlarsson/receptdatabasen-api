# Only for building the frontend
# parcel/elm has elm as dep whose npm package is not arm64 compatible
# so we simply run this with x86 instead as on prod, locally I'd use nix's
# version of elm (compiled for aarch64) anyway
FROM  node:bookworm
LABEL org.opencontainers.image.source=https://github.com/axeltlarsson/receptdatabasen-api
LABEL org.opencontainers.image.description="Receptdatabasen frontend"

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY ./ ./
RUN npm run build
