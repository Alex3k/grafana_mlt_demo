import {
  FaroErrorBoundary,
  initializeFaro,
  getWebInstrumentations,
  ReactIntegration,
  ReactRouterVersion
} from '@grafana/faro-react';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { W3CTraceContextPropagator } from '@opentelemetry/core';
import { ZoneContextManager } from '@opentelemetry/context-zone';

import { TracingInstrumentation, FaroSessionSpanProcessor, FaroTraceExporter } from '@grafana/faro-web-tracing';
import { createBrowserHistory } from 'history';
import React from 'react';
import ReactDOM from 'react-dom';
import { Route } from 'react-router-dom';
import App from './components/app';

const VERSION = "3.4.26";
const NAME = 'ecommerce-frontend';
const COLLECTOR_URL = "http://35.224.5.38:12121/collect";

const history = createBrowserHistory();

console.log(process.env.FARO_ENDPOINT)

// Initialize Faro
const faro = initializeFaro({
  url: COLLECTOR_URL,
  apiKey: 'secret',
  instrumentations: [
    // This adds the default instrumentation and also enables the console capture
    ...getWebInstrumentations({
      captureConsole: true
    }),
    // This adds the tracing instrumentation with all the auto-instrumentations
    new TracingInstrumentation(),
    // This enables the React integration
    new ReactIntegration({
      router: {
        version: ReactRouterVersion.V5,
        dependencies: {
          history,
          Route
        }
      }
    })
  ],
  app: {
    name: NAME,
    version: VERSION,
    environment: 'prod'
  }
});

// set up otel
const resource = Resource.default().merge(
  new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: NAME,
    [SemanticResourceAttributes.SERVICE_VERSION]: VERSION,
  })
);

const provider = new WebTracerProvider({ resource });

provider.addSpanProcessor(new FaroSessionSpanProcessor(new BatchSpanProcessor(new FaroTraceExporter({ faro }))));

provider.register({
  propagator: new W3CTraceContextPropagator(),
  contextManager: new ZoneContextManager(),
});

ReactDOM.render(
  <FaroErrorBoundary>
    <App history={history} />
  </FaroErrorBoundary>,
  document.getElementById('root')
);
