FROM alpine:latest

RUN apk add --no-cache bash curl jq

WORKDIR /app
COPY . .

RUN chmod +x *.sh

COPY crontab /etc/crontabs/root

CMD ["crond", "-f", "-l", "2"]