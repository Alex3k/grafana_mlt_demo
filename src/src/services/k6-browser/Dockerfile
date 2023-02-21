
# Build
FROM docker.io/library/node:16-slim as build

# Requirements for service
WORKDIR /
COPY ./.nvmrc .
COPY ./package.json .
COPY ./babel.config.json .
COPY ./webpack.config.js .
COPY ./src ./src

# Build
RUN npm install
RUN npm run build

# Run
FROM grafana/k6:0.43.0
USER root

RUN apk update && apk add --no-cache chromium

# Copy build
COPY --from=build /dist ./dist


# Configuration inputs
ARG DEPLOYMENT_ENVIRONMENT
ARG SERVICE_NAME
ARG SERVICE_HOST_WEB_GATEWAY
ARG SERVICE_PORT_WEB_GATEWAY
ARG FRONTEND_URL

ENV DEPLOYMENT_ENVIRONMENT=${DEPLOYMENT_ENVIRONMENT}
ENV SERVICE_NAME=${SERVICE_NAME}
ENV SERVICE_HOST_WEB_GATEWAY=${SERVICE_HOST_WEB_GATEWAY}
ENV SERVICE_PORT_WEB_GATEWAY=${SERVICE_PORT_WEB_GATEWAY}
ENV K6_BROWSER_ENABLED=true
ENV FRONTEND_URL=${FRONTEND_URL:-http://34.29.94.7}

CMD ["run", "./dist/app.bundle.js", "--no-summary", "--no-thresholds" ]
