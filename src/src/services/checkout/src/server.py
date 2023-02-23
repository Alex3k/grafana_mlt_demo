# Standard packages
import json
import uuid
import re

# Third-party packages
import requests
from flask import jsonify, request
from opentelemetry import trace
from opentelemetry.trace.status import Status, StatusCode

# Service packages
from common import app, config, logger

def generate_transaction_id():
    return str(uuid.uuid4())


####  HTTP Handlers  ###########################################################

BASE_URL_API_GATEWAY = "http://{}:{}/api/v1".format(
    config.get('SERVICE_HOST_API_GATEWAY'),
    config.get('SERVICE_PORT_API_GATEWAY')
)

def get_cart_id(session_id):
    """
    Transform the value of a "session_id" cookie to its key in session-store.
    """
    matches = re.findall(r'^([^.]*)\.', session_id)
    if matches:
        return "s:{}".format(matches[0])
    raise Exception('Cannot find cart')


@app.route('/initiate', methods=['POST',])
def initiate_checkout():
    """
    This is only here to make RUM a lot easier - it literally does nothing but 
    does add a log line when called with all the details so we can get when someone 
    opens the checkout page 
    """
    return jsonify({ 'message': 'success' })

@app.route('/process', methods=['POST',])
def post_checkout():
    """
    Process an order submission.
    """
    data = request.get_json()

    session_id = data.get('session_id')
    cart_id = get_cart_id(session_id)
    amount = data.get('amount')
    transaction_id = generate_transaction_id()

    # Process the payment
    data_payment = {
        'amount': amount,
        'card': data.get('billing', {}).get('card', {}),
        'transaction_id':transaction_id
    }
    url = "{}/payment/process".format(BASE_URL_API_GATEWAY)

    try:
        response = requests.post(url, json=data_payment, headers=dict(request.headers.items()), timeout=3)

        if response.status_code != 200:
            logger.info(f"payment failed {amount}", extra={
                'tags': [
                    ( 'ip', request.environ.get('REMOTE_ADDR') ),
                    ( 'method', request.method ),
                    ( 'path', request.path ),
                    ( 'user_agent', request.headers.get('User-Agent') ),
                    ( 'device_country', request.headers.get('X-Device-Country') ),
                    ( 'device_id', request.headers.get('X-Device-ID') ),
                    ( 'forwarded_for', request.headers.get('X-Forwarded-For') ),
                    ( 'customer_tier', request.headers.get('X-Customer-Tier') ),
                    ( 'session_id', request.headers.get('X-Session-Id') )
                ]
            })
            span = trace.get_current_span()
            span.set_attribute('event.outcome', 'failure')
            span.set_status(Status(StatusCode.ERROR))
            return jsonify({ 'message': 'failure' }), response.status_code
        else:
            logger.info(f"payment successful {amount}", extra={
                'tags': [
                    ( 'ip', request.environ.get('REMOTE_ADDR') ),
                    ( 'method', request.method ),
                    ( 'path', request.path ),
                    ( 'user_agent', request.headers.get('User-Agent') ),
                    ( 'device_country', request.headers.get('X-Device-Country') ),
                    ( 'device_id', request.headers.get('X-Device-ID') ),
                    ( 'forwarded_for', request.headers.get('X-Forwarded-For') ),
                    ( 'customer_tier', request.headers.get('X-Customer-Tier') ),
                    ( 'session_id', request.headers.get('X-Session-Id') )
                ]
            })
    except requests.exceptions.Timeout:
        logger.info(f"payment timedout {amount}", extra={
            'tags': [
                ( 'ip', request.environ.get('REMOTE_ADDR') ),
                ( 'method', request.method ),
                ( 'path', request.path ),
                ( 'user_agent', request.headers.get('User-Agent') ),
                ( 'device_country', request.headers.get('X-Device-Country') ),
                ( 'device_id', request.headers.get('X-Device-ID') ),
                ( 'forwarded_for', request.headers.get('X-Forwarded-For') ),
                ( 'customer_tier', request.headers.get('X-Customer-Tier') ),
                ( 'session_id', request.headers.get('X-Session-Id') )
            ]
        })

        span = trace.get_current_span()
        span.set_attribute('event.outcome', 'failure')
        span.set_status(Status(StatusCode.ERROR))
        return jsonify({ 'message': 'failure' }), 408

    # Clear the cart
    data_cart = {
        'session_id': session_id
    }
    url="{}/cart".format(BASE_URL_API_GATEWAY)
    response = requests.delete(url, json=data_cart, headers=dict(request.headers.items()))
    if response.status_code != 200:
        span = trace.get_current_span()
        span.set_attribute('event.outcome', 'failure')
        span.set_status(Status(StatusCode.ERROR))
        return jsonify({ 'message': 'failure' }), response.status_code
    return jsonify({ 'message': 'success' })

@app.route('/')
def home():
    """
    Handle base path.
    """
    return app.response_class(
        response=json.dumps(config, indent=2, sort_keys=True),
        mimetype='application/json',
        status=200
    )


####  Main  ####################################################################

if __name__ == '__main__':
    app.run(config.get('SERVICE_BIND_HOST'), config.get('SERVICE_BIND_PORT'))
