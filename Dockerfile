FROM python:3.12.12-bookworm
ADD diacamma/* /var/lucterios2/

SHELL ["/bin/bash", "-c"] 
RUN set -eux; \
	apt update; \ 
	apt install -y locales; \
	echo "fr_FR.UTF-8 UTF-8" > /etc/locale.gen; \
	locale-gen fr_FR.UTF-8

RUN set -eux; \
	/var/lucterios2/install.sh

RUN rm -f /var/lucterios2/install.sh

COPY entrypoint.d /entrypoint.d/
ENTRYPOINT ["/entrypoint.d/entrypoint.sh"]
CMD ["run"]

