FROM ubuntu:24.04
LABEL maintainer="Nicolas Bayle"

RUN apt update \
    && apt install -y jq \
    && apt install -y curl \
    && apt install -y tcpdump \
    && apt install -y net-tools \
    && apt install -y iputils-ping \
    && apt install -y nginx \
    && apt install -y unzip \
    && apt install -y vim \
    && apt install -y iproute2 \
    && apt install -y python3 \
    && apt install -y python3-pip \
    && apt install -y gnupg software-properties-common \
    && pip3 install ansible-core==2.18.6 --break-system-packages \
    && pip3 install ansible==11.7.0 --break-system-packages \
    && pip3 install avisdk --break-system-packages \
    && pip3 install gunicorn --break-system-packages \
    && apt remove -y python3-blinker \
    && pip3 install flask --break-system-packages \
    && pip3 install flask_restful --break-system-packages \
    && pip3 install flask_cors --break-system-packages \
    && pip3 install pyvmomi==8.0.3.0.1 --break-system-packages \
    && curl -L -o - "https://github.com/vmware/govmomi/releases/latest/download/govc_$(uname -s)_$(uname -m).tar.gz" | tar -C /usr/local/bin -xvzf - govc

COPY build /build

RUN cp /build/html/* /var/www/html \
    && cp /build/nginx/default /etc/nginx/sites-available/default

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "/build/run.sh"]