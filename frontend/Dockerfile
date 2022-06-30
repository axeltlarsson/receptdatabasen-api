# Only for building the frontend
# create-elm-app has elm as dep whose npm package is not arm64 compatible
# so we simply run this with x86 instead as on prod, locally I'd use nix's
# version of elm (compiled for aarch64) anyway
FROM --platform=linux/amd64 node:14

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY ./ ./
RUN npm run build
