FROM debian:buster-slim

# Used only for triggering a rebuild
LABEL zelcashd="2.0.20"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        ca-certificates \
        curl \
        wget \
        apt-transport-https \
        lsb-release \
        libgomp1 \
        jq \
        gnupg \
        gosu \
    && echo 'deb https://apt.zel.cash/ all main' | tee --append /etc/apt/sources.list.d/zelcash.list \
    && gpg --keyserver keyserver.ubuntu.com --recv 4B69CA27A986265D \
    && gpg --export 4B69CA27A986265D | apt-key add - \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install zelcash zelbench \
    && gosu nobody true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Default p2p communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-port=16125")
# or via a "port=16125" line in zen.conf.
#Default is 16125
EXPOSE 16125

# Default rpc communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-rpcport=16124")
# or via a "rpcport=16124" line in zelcash.conf. This port should never be mapped to the outside world
# via the "docker run -p/-P" command.
#Default is 16124
EXPOSE 16124

# Data volumes, if you prefer mounting a host directory use "-v /path:/mnt/zen" command line
# option (folder ownership will be changed to the same UID/GID as provided by the docker run command)
VOLUME ["/mnt/zelcash"]

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["zelcashd"]