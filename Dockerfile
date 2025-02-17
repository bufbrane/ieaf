FROM debian:bookworm

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get -y install bash git python3 python3-selenium chromium-driver chromium xvfb;

COPY . /root/ieaf

WORKDIR /root/ieaf