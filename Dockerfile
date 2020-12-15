


FROM       ubuntu:12.04
MAINTAINER raphaeljuwe <raphaeljuwe@gmail.com>

# mkdoc description.
ARG BUILD_DATE
ARG BUILD_VERSION

LABEL org.label-schema.schema-version="1.0.0" \
    org.label-schema.vcs-description="mkdocs" \
	org.label-schema.build-date=$BUILD_DATE \
	org.label-schema.version=$BUILD_VERSION  \
    org.label-schema.docker.cmd="docker exec " \
    image-size="70.7MB" \
    ram-usage="13.4MB to 69MB" \
    cpu-usage="Low"

# python install.
RUN apk add --update python3 libcap  && \
	if [ ! -e /usr/bin/python ]; then ln -sf python3 /usr/bin/python ; fi && \
    \
    echo "**** install pip ****" && \
    /usr/bin/python3 -m ensurepip && \
    pip3 install --no-cache --upgrade pip setuptools wheel && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi && \
    pip install  mkdocs click-man && \
    mkdir /opt/www && \
    addgroup -g 101 -S mkdocs  && \
    adduser -S -D -H -u 101 -h /opt/www -s /sbin/nologin -G mkdocs\
    -g mkdocs mkdocs && \
    chown -R mkdocs:mkdocs /opt/www && \ 
    setcap 'cap_net_bind_service=+ep' /usr/bin/mkdocs && \
    rm -rf /tmp/* /var/cache/apk/*
    
VOLUME /var/mkdocs

USER mkdocs

COPY run.sh /run.sh
RUN chmod +x /run.sh
CMD ["/run.sh"]
WORKDIR /var/mkdocs
EXPOSE 8000
CMD ["mkdocs"]
