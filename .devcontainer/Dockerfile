FROM docker.io/library/ubuntu:24.04

RUN apt-get update && apt-get install -y \
    bats \
    git \
    openssh-client \
    wget && \
    # The version of yq available in apt is very outdated so it must be manually installed
    # To find newer versions visit: https://github.com/mikefarah/yq/releases/
    wget https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
