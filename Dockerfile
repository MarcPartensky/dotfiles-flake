FROM alpine

RUN apk update
RUN apk add mkpasswd zfs

COPY LICENSE configuration.nix flake.lock flake.nix install.sh ./
COPY hosts ./
COPY modules ./

ENTRYPOINT [ "./install.sh" ]
