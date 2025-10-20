# Production-grade Dockerfile for Chessdriller
# Improvements:
# - Pin Node major version (20) for Prisma compatibility & reproducibility
# - Install required native libs for Prisma on Alpine (openssl, libc6-compat)
# - Layered caching: copy only manifests + prisma first, then install, then copy rest
# - Use npm ci when lockfile present
# - Generate Prisma client at build
# - Move `prisma db push` to runtime (idempotent, ensures schema is applied with current env vars)
# - Provide sane default DATABASE_URL (can be overridden by actual environment)

FROM node:20-alpine

WORKDIR /code

# Native dependencies needed for Prisma engines on Alpine
RUN apk add --no-cache openssl libc6-compat

# Copy dependency manifests & prisma schema early for better caching
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
COPY prisma ./prisma

# Install JS dependencies (clean, reproducible if lockfile exists)
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Generate Prisma client (does not require DB access)
RUN npx prisma generate

# Copy the rest of the source
COPY . .

# Build SvelteKit app
RUN npm run build

# Environment defaults (can be overridden at runtime)
ENV NODE_ENV=production \
    PORT=3123 \
    DATABASE_URL=file:./prisma/prod.db

EXPOSE 3123

# At container start:
# 1. Ensure the schema is in sync (creates/updates SQLite file)
# 2. Start the Node server
CMD ["sh", "-c", "npx prisma db push && node server.js"]
