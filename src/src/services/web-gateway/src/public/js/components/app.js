// Third party components
import React from 'react'
import { FaroRoutes } from '@grafana/faro-react';
import { BrowserRouter, Route, Switch } from 'react-router-dom'

// App components
import { Provider } from './app_context'
import CartPage from './page_cart'
import CheckoutPage from './page_checkout'
import ConfirmationPage from './page_confirmation'
import HomePage from './page_home'
import NotFoundPage from './page_not_found'
import TestPage from './page_test'

// Styles
import 'semantic-ui-css/semantic.min.css'
import '../../css/index.sass'

function App() {
  return (
    <Provider>
      <BrowserRouter>
        <Switch>
          <FaroRoutes><Route path="/" exact component={HomePage} /> </FaroRoutes>
          <FaroRoutes><Route path="/cart" exact component={CartPage} /></FaroRoutes>
          <FaroRoutes><Route path="/checkout" exact component={CheckoutPage} /></FaroRoutes>
          <FaroRoutes><Route path="/confirmation" exact component={ConfirmationPage} /></FaroRoutes>
          <FaroRoutes><Route path="/test" exact component={TestPage} /></FaroRoutes>
          <FaroRoutes><Route path="*" component={NotFoundPage} /></FaroRoutes>
        </Switch>
      </BrowserRouter>
    </Provider>
  )
}

export default App
