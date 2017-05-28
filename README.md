# Introduction

`Dockerfile` to create a [Docker](https://www.docker.com/) container image for [BIND](https://www.isc.org/downloads/bind/) DNS server bundled with the [Webmin](http://www.webmin.com/) interface.

BIND is open source software that implements the Domain Name System (DNS) protocols for the Internet. It is a reference implementation of those protocols, but it is also production-grade software, suitable for use in high-volume and high-reliability applications.

# Getting started

## Installation

Automated builds of the image are available on [Dockerhub](https://hub.docker.com/r/sameersbn/bind) and is the recommended method of installation.

```bash
docker pull soldin/dns-dhcp
```

## Quickstart

Start BIND using:

	docker run -d --name dns-dhcp \
	--net=host \
	-e ROOT_PASSWORD=admin \
	-e DHCP_ENABLED=true \
	-e INTERFACES=eth0 \
	-v /etc/localtime:/etc/localtime:ro \
	-v /srv/dns-dhcp:/data \
	--restart=always soldin/dns-dhcp
	
When the container is started the [Webmin](http://www.webmin.com/) service is also started and is accessible from the web browser at http://localhost:10000. Login to Webmin with the username `root` and password `password`. Specify `--env ROOT_PASSWORD=secretpassword` on the `docker run` command to set a password of your choosing.

The launch of Webmin can be disabled by adding `--env WEBMIN_ENABLED=false` to the `docker run` command. Note that the `ROOT_PASSWORD` parameter has no effect when the launch of Webmin is disabled.

## Persistence

For the BIND to preserve its state across container shutdown and startup you should mount a volume at `/data`.

# Maintenance

## Shell Access

For debugging and maintenance purposes you may want access the containers shell. If you are using Docker version `1.3.0` or higher you can access a running containers shell by starting `bash` using `docker exec`:

```bash
docker exec -it dns-dhcp bash
```
