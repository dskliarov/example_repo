# Build layer
#---------------------------------------------------------
FROM elixir:1.10-alpine AS builder

ARG      SSH_PRIVATE_KEY
ARG      SSH_PUBLIC_KEY

RUN      apk update && \
         apk upgrade && \
         apk --no-cache add \
         git openssh openssl-dev && \
         apk add \
         build-base && \
         mix local.rebar --force && \
         mix local.hex --force

RUN      mkdir -p -m 0600 /root/.ssh && \
         ssh-keyscan gitlab.aeon.world >> /root/.ssh/known_hosts && \
         echo -e "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa && \ 
         echo -e "$SSH_PUBLIC_KEY" > /root/.ssh/id_rsa.pub && \
         chmod 600 /root/.ssh/id_rsa && \
         chmod 600 /root/.ssh/id_rsa.pub 

RUN      cat /root/.ssh/id_rsa

WORKDIR  /opt/app

ADD      mix.exs mix.lock ./

RUN      mix do deps.get --only prod, deps.compile

COPY     . ./

RUN      MIX_ENV=prod mix release --path ../built

# Run layer
#---------------------------------------------------------
FROM alpine:3.9

RUN          apk add \
              bash 

WORKDIR      /opt/app/bin

COPY         --from=builder /opt/built ../

ENV          PATH="$PATH:$PWD"

ENTRYPOINT   ["saga2", "start"]
