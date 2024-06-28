FROM node:20-alpine
LABEL org.opencontainers.image.authors="paul.brunck@pm.me"

ENV SECRET_WORD="Don't say that!"

COPY src/000.js /opt/
RUN mkdir /opt/bin
COPY bin /opt/bin/
COPY package.json /opt/
WORKDIR /opt

RUN npm install

EXPOSE 3000
ENTRYPOINT [ "node", "000.js" ]
