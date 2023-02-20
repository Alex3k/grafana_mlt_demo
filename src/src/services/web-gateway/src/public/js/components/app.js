// Third party components
import React from 'react';
import { FaroRoute } from '@grafana/faro-react';
import { BrowserRouter, Router, Switch } from 'react-router-dom';

// App components
import { Provider } from './app_context';
import CartPage from './page_cart';
import CheckoutPage from './page_checkout';
import ConfirmationPage from './page_confirmation';
import HomePage from './page_home';
import NotFoundPage from './page_not_found';
import TestPage from './page_test';

// Styles
import 'semantic-ui-css/semantic.min.css';
import '../../css/index.sass';

function App({ history }) {
  return (
    <Provider>
      <Router history={history}>
        <Switch>
          <FaroRoute path="/" exact component={HomePage} />
          <FaroRoute path="/cart" exact component={CartPage} />
          <FaroRoute path="/checkout" exact component={CheckoutPage} />
          <FaroRoute path="/confirmation" exact component={ConfirmationPage} />
          <FaroRoute path="/test" exact component={TestPage} />
          <FaroRoute path="*" component={NotFoundPage} />
        </Switch>
      </Router>
    </Provider>
  );
}

export default App;
