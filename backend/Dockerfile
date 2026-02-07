# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production=false

# Copy source
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Build
RUN npm run build

# Production stage
FROM node:20-alpine AS production

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

# Copy production dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy Prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/prisma ./prisma

# Copy built app
COPY --from=builder /app/dist ./dist

# Set ownership
RUN chown -R nestjs:nodejs /app

USER nestjs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/v1/health || exit 1

# Expose port
EXPOSE 3000

# Start
CMD ["node", "dist/main"]
