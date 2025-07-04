# syntax=docker/dockerfile:1.7.0-labs
ARG TAG=24.04
FROM ubuntu:${TAG} AS build

### Build stage
# Install curl, git and simplexmq dependencies
RUN apt-get update && apt-get install -y curl git build-essential libgmp3-dev zlib1g-dev llvm-18 llvm-18-dev libnuma-dev libssl-dev

# Specify bootstrap Haskell versions
ENV BOOTSTRAP_HASKELL_GHC_VERSION=9.6.3
ENV BOOTSTRAP_HASKELL_CABAL_VERSION=3.12.1.0

# Do not install Stack
ENV BOOTSTRAP_HASKELL_INSTALL_NO_STACK=true
ENV BOOTSTRAP_HASKELL_INSTALL_NO_STACK_HOOK=true

# Install ghcup
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 sh

# Adjust PATH
ENV PATH="/root/.cabal/bin:/root/.ghcup/bin:$PATH"

# Set both as default
RUN ghcup set ghc "${BOOTSTRAP_HASKELL_GHC_VERSION}" && \
    ghcup set cabal "${BOOTSTRAP_HASKELL_CABAL_VERSION}"

# Clone SimpleX repository
RUN git clone https://github.com/simplex-chat/simplexmq.git /project
WORKDIR /project

# Set build arguments
ARG APP=smp-server
ARG APP_PORT=5223

# Compile app
RUN cabal update
RUN cabal build exe:$APP

# Create new path containing all files needed
RUN mkdir /final
WORKDIR /final

# Strip the binary from debug symbols to reduce size
RUN bin="$(find /project/dist-newstyle -name "$APP" -type f -executable)" && \
    mv "$bin" ./ && \
    strip ./"$APP" && \
    mv /project/scripts/docker/entrypoint-"$APP" ./entrypoint && \
    mv /project/scripts/main/simplex-servers-stopscript ./simplex-servers-stopscript

### Final stage
FROM ubuntu:${TAG}

# Install OpenSSL dependency
RUN apt-get update && apt-get install -y openssl libnuma-dev

# Copy compiled app from build stage
COPY --from=build /final /usr/local/bin/

# Open app listening port
EXPOSE 5223

# simplexmq requires using SIGINT to correctly preserve undelivered messages and restore them on restart
STOPSIGNAL SIGINT

# Finally, execute helper script
ENTRYPOINT [ "/usr/local/bin/entrypoint" ]

# Fixed

