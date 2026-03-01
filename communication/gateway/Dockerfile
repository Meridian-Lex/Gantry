FROM nginx:alpine

RUN apk add --no-cache 'curl>=8.0' \
    && touch /var/run/nginx.pid \
    && chown -R nginx:nginx \
        /var/cache/nginx \
        /var/run/nginx.pid \
        /var/log/nginx

COPY --chown=nginx:nginx nginx.conf /etc/nginx/nginx.conf

EXPOSE 8000

USER nginx

CMD ["nginx", "-g", "daemon off;"]
