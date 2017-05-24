#
# ----- Go Builder Image ------
#
FROM alexeiled/go-builder:1.8-onbuild as builder

MAINTAINER Alexei Ledenev <alexei.led@gmail.com>

# download and install bats
ENV BATS_VERSION 0.4.0
ENV BATS_SHA_256 480d8d64f1681eee78d1002527f3f06e1ac01e173b761bc73d0cf33f4dc1d8d7

RUN curl -o "/tmp/v${BATS_VERSION}.tar.gz" -LS "https://github.com/sstephenson/bats/archive/v${BATS_VERSION}.tar.gz" && \
    echo "${BATS_SHA_256}  v${BATS_VERSION}.tar.gz" > /tmp/v${BATS_VERSION}.tar.gz.sha256 && \
    cd /tmp && sha256sum -c v${BATS_VERSION}.tar.gz.sha256 && \
    tar -xvzf "/tmp/v${BATS_VERSION}.tar.gz" -C /tmp/ && \
    bash "/tmp/bats-${BATS_VERSION}/install.sh" /usr/local && \
    rm -rf /tmp/*

# download and install Docker client
ARG DOCKER_VERSION
ENV DOCKER_VERSION ${DOCKER_VERSION:-1.13.0}
ARG DOCKER_SHA_256
ENV DOCKER_SHA_256 ${DOCKER_SHA_256:-fc194bb95640b1396283e5b23b5ff9d1b69a5e418b5b3d774f303a7642162ad6}

RUN curl -o "/tmp/docker-${DOCKER_VERSION}.tgz" -LS "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" && \
    echo "${DOCKER_SHA_256}  docker-${DOCKER_VERSION}.tgz" > /tmp/docker-${DOCKER_VERSION}.tgz.sha256 && \
    cd /tmp && sha256sum -c docker-${DOCKER_VERSION}.tgz.sha256 && \
    tar -xvzf "/tmp/docker-${DOCKER_VERSION}.tgz" -C /tmp/ && \
    cp /tmp/docker/docker /usr/local/bin/ && \
    rm -rf /tmp/*

# build pumba binary
RUN bash -c 'VERSION=$(cat VERSION) script/go_build.sh'

# runt test and generate coverage report
RUN script/coverage.sh

# run integration tests
ARG DOCKER_API_VERSION
ENV DOCKER_API_VERSION ${DOCKER_API_VERSION:-1.21}
RUN bash -c 'PATH=dist/bin:$PATH bats -t tests | tee .cover/tests.output'

#
# ------ Pumba runtime image ------
#
FROM alpine:3.5

MAINTAINER Alexei Ledenev <alexei.led@gmail.com>

LABEL com.gaiaadm.pumba=true

RUN addgroup pumba && adduser -s /bin/bash -D -G pumba pumba

ENV GOSU_VERSION 1.10
ENV GOSU_SHA_256 5b3b03713a888cee84ecbf4582b21ac9fd46c3d935ff2d7ea25dd5055d302d3c

RUN apk add --no-cache --virtual .gosu-deps curl && \
    curl -o /tmp/gosu-amd64 -LS  "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" && \
    echo "${GOSU_SHA_256}  gosu-amd64" > /tmp/gosu-amd64.sha256 && \
    cd /tmp && sha256sum -c gosu-amd64.sha256 && \
    mv /tmp/gosu-amd64 /usr/local/bin/gosu && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true && \
    rm -rf /tmp/* && \
    apk del .gosu-deps

ARG GH_USER
ARG GH_PROJECT
COPY --from=builder /go/src/github.com/${GH_USER}/${GH_PROJECT}/dist/bin/pumba /usr/bin/pumba
COPY --from=builder /go/src/github.com/${GH_USER}/${GH_PROJECT}/dist/docker_entrypoint.sh /
RUN chmod +x /docker_entrypoint.sh

ENTRYPOINT ["/docker_entrypoint.sh"]
CMD ["pumba", "--help"]

LABEL org.label-schema.vcs-ref=$GH_SHA \
      org.label-schema.vcs-url="https://github.com/gaia-adm/pumba"
