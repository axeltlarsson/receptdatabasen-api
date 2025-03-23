# Only for building the frontend
FROM node:alpine
LABEL org.opencontainers.image.source=https://github.com/axeltlarsson/receptdatabasen-api
LABEL org.opencontainers.image.description="Receptdatabasen frontend"

WORKDIR /app

# Install elm with @lydell/elm for multiarch support
RUN npm install -g @lydell/elm uglify-js
COPY package*.json ./
RUN npm ci

COPY ./ ./

RUN npm run build
