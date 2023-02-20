import {
  FaroErrorBoundary,
  initializeFaro,
  getWebInstrumentations,
  ReactIntegration,
  ReactRouterVersion
} from '@grafana/faro-react';
import { TracingInstrumentation } from '@grafana/faro-web-tracing';
import { createBrowserHistory } from 'history';
import React from 'react';
import ReactDOM from 'react-dom';
import { Route } from 'react-router-dom';
import App from './components/app';

const VERSION = process.env.SERVICE_VERSION;
const NAME = 'frontend';
const COLLECTOR_URL = process.env.FARO_ENDPOINT;

const history = createBrowserHistory();

// Initialize Faro
initializeFaro({
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

ReactDOM.render(
  <FaroErrorBoundary>
    <App history={history} />
  </FaroErrorBoundary>,
  document.getElementById('root')
);
