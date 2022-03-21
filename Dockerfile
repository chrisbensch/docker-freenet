FROM openjdk:19-jdk-alpine3.15

LABEL maintainer="Chris Bensch <chris.bensch@gmail.com>"
# Original Credit - "Tobias Vollmer <info+docker@tvollmer.de>"

ARG darknetport=8675 opennetport=8676

# We need openssl to download via https and libc-compat for the wrapper
RUN apk add --update openssl libc6-compat \
    && ln -s /lib /lib64 \
    && mkdir -p /conf /data \
    && addgroup -S -g 1000 fred \
    && adduser -S -u 1000 -G fred -h /fred fred \
    && chown -R fred:fred /conf /data

COPY defaults/freenet.ini /defaults/freenet.ini
COPY defaults/freenet.ini /conf/freenet.ini

COPY docker-run /fred/
#RUN chown fred:fred /fred/freenet.ini && chmod 755 /fred/freenet.ini

USER fred
WORKDIR /fred
COPY defaults/seednodes.fref /fred/
COPY defaults/opennet-5060 /fred/
COPY defaults/openpeers-5060 /fred/

# Get the latest freenet build or use supplied version
RUN build=$(test -n "${freenet_build}" && echo ${freenet_build} \
            || wget -qO - https://api.github.com/repos/freenet/fred/releases/latest | grep 'tag_name'| cut -d'"' -f 4) \
    && short_build=$(echo ${build}|cut -c7-) \
    && echo -e "build: $build\nurl: https://github.com/freenet/fred/releases/download/$build/new_installer_offline_$short_build.jar" >buildinfo.json \
    && echo "Building:" \
    && cat buildinfo.json

# Download and install freenet in the given version
RUN wget -O /tmp/new_installer.jar $(grep url /fred/buildinfo.json |cut -d" " -f2) \
    && echo "INSTALL_PATH=/fred/" >/tmp/install_options.conf \
    && java -jar /tmp/new_installer.jar -options /tmp/install_options.conf \
    && sed -i 's#wrapper.app.parameter.1=freenet.ini#wrapper.app.parameter.1=/fred/freenet.ini#' /fred/wrapper.conf \
    && rm /tmp/new_installer.jar /tmp/install_options.conf \
    && echo "Build successful" \
    && echo "----------------" \
    && cat /fred/buildinfo.json

COPY defaults/freenet.ini /fred/

# Check every 5 Minutes, if Freenet is still running
HEALTHCHECK --interval=5m --timeout=3s CMD /fred/run.sh status || exit 1

# Interfaces:
EXPOSE 8888 9481 ${darknetport}/udp ${opennetport}/udp

VOLUME ["/conf", "/data"]

# Command to run on start of the container
CMD [ "/fred/docker-run" ]