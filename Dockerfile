FROM node:20-alpine3.18 as base

RUN apk --no-cache add curl
RUN corepack enable

# All deps stage
FROM base as deps
WORKDIR /app
ADD package.json pnpm-lock.yaml ./
RUN pnpm install

# Production only deps stage
FROM base as production-deps
WORKDIR /app
ADD package.json pnpm-lock.yaml ./
RUN pnpm install --prod
RUN wget https://gobinaries.com/tj/node-prune --output-document - | /bin/sh && node-prune

# Build stage
FROM base as build
WORKDIR /app
COPY --from=deps /app/node_modules /app/node_modules
ADD . .
RUN node ace build --ignore-ts-errors --package-manager=pnpm
RUN node ace build:packages

# Production stage
FROM base
ENV NODE_ENV=production
WORKDIR /app
COPY --from=production-deps /app/node_modules /app/node_modules
COPY --from=production-deps /app/package.json /app/package.json
COPY --from=build /app/build /app
COPY --from=build /app/content/build/packages.json /app/content/build/packages.json
EXPOSE 8080
CMD ["node", "./bin/server.js"]
