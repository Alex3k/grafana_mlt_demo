
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
FROM docker.io/library/golang:1.17-alpine as xk6

RUN go install go.k6.io/xk6/cmd/xk6@latest
RUN xk6 build --with github.com/grafana/xk6-output-prometheus-remote@latest 

# Copy build
COPY --from=build /dist ./dist

# Configuration inputs
ARG DEPLOYMENT_ENVIRONMENT
ARG SERVICE_NAME
ARG SERVICE_HOST_WEB_GATEWAY
ARG SERVICE_PORT_WEB_GATEWAY
ENV DEPLOYMENT_ENVIRONMENT=${DEPLOYMENT_ENVIRONMENT}
ENV SERVICE_NAME=${SERVICE_NAME}
ENV SERVICE_HOST_WEB_GATEWAY=${SERVICE_HOST_WEB_GATEWAY}
ENV SERVICE_PORT_WEB_GATEWAY=${SERVICE_PORT_WEB_GATEWAY}


CMD ["./k6", "run", "./dist/app.bundle.js", "--no-summary", "--no-usage-report" ]
