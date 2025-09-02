# Multi-stage Dockerfile for Swap Optimizer Orchestrator
# Stage 1: Dependencies
FROM node:18-alpine AS dependencies

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies with npm ci for faster, reliable, reproducible builds
RUN npm ci --only=production && \
    npm cache clean --force

# Copy production dependencies aside
RUN cp -R node_modules prod_node_modules

# Install all dependencies (including dev dependencies for building)
RUN npm ci && \
    npm cache clean --force

# ============================================
# Stage 2: Builder
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files and dependencies from previous stage
COPY package*.json ./
COPY tsconfig.json ./
COPY --from=dependencies /app/node_modules ./node_modules

# Copy source code
COPY src ./src

# Build the TypeScript application
RUN npm run build

# ============================================
# Stage 3: Production
FROM node:18-alpine AS production

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init curl bash

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Copy production dependencies from dependencies stage
COPY --from=dependencies /app/prod_node_modules ./node_modules

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist

# Copy shell scripts with proper permissions
COPY --chown=nodejs:nodejs install.sh setup.sh start.sh ./
RUN chmod +x install.sh setup.sh start.sh

# Create necessary directories
RUN mkdir -p logs run && \
    chown -R nodejs:nodejs /app

# Copy .env.example as template
COPY --chown=nodejs:nodejs .env.example .env.example

# Health check configuration
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/healthz || exit 1

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production \
    LOG_DIR=/app/logs \
    RUN_DIR=/app/run

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Default command
CMD ["node", "dist/app.js"]

# ============================================
# Stage 4: Development (optional)
FROM node:18-alpine AS development

# Install development tools
RUN apk add --no-cache bash curl git

WORKDIR /app

# Copy everything
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies
RUN npm ci

# Copy source code
COPY . .

# Create directories
RUN mkdir -p logs run

# Expose port
EXPOSE 3000

# Development command with hot reload
CMD ["npm", "run", "dev"]
