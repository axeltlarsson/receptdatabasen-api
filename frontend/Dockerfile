# Only for building the frontend
FROM node:14

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY ./ ./
RUN npm run build
