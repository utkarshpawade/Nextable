#=====
# Most Debian-based base images
FROM node:22-slim

# Install curl
RUN apt-get update && apt-get install -y curl && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY compile_page.sh /compile_page.sh
FROM node:22-slim

# Install curl
RUN apt-get update && apt-get install -y curl && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY compile_page.sh /compile_page.sh
RUN chmod +x /compile_page.sh

WORKDIR /home/user/nextjs-app

# Use pnpm instead of npm for faster installation
# Pin to pnpm 10 — pnpm 11 fails on packages with build scripts (sharp, etc.)
RUN npm install -g pnpm@10

# Pre-approve build scripts so pnpm doesn't error on sharp/esbuild postinstall.
RUN echo "auto-install-peers=true" > /root/.npmrc && \
    echo "approve-builds=true" >> /root/.npmrc && \
    echo "strict-peer-dependencies=false" >> /root/.npmrc

# Create Next.js app with pnpm (much faster)
RUN pnpm create next-app@15.3.3 . --yes

RUN pnpm dlx shadcn@2.6.3 init --yes -b neutral --force
RUN pnpm dlx shadcn@2.6.3 add --all --yes

RUN pnpm install

RUN mv /home/user/nextjs-app/* /home/user/ && rm -rf /home/user/nextjs-app
