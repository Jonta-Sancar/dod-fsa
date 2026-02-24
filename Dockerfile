FROM localstack/localstack:3

# Instala nginx e AWS CLI (v1 dos repositórios Debian/Ubuntu).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        awscli \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Configuração do nginx e página de teste.
COPY resources/local/nginx.conf /etc/nginx/nginx.conf
COPY resources/html /usr/share/nginx/html

# Script para iniciar o nginx quando o LocalStack estiver pronto.
COPY resources/local/10-start-nginx.sh /etc/localstack/init/ready.d/10-start-nginx.sh
RUN chmod +x /etc/localstack/init/ready.d/10-start-nginx.sh

EXPOSE 80 4566
