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
    logger.info(session_id)
    matches = re.findall(r'^([^.]*)\.', session_id)
    logger.info(matches)
    if matches:
        return "s:{}".format(matches[0])
    raise Exception('Cannot find cart')


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
    response = requests.post(url, json=data_payment)
    if response.status_code != 200:
        span = trace.get_current_span()
        span.set_attribute('event.outcome', 'failure')
        span.set_status(Status(StatusCode.ERROR))
        logger.info(f"session_id={session_id},cart_id={cart_id},action=process_payment,status=failed,amount={amount},transaction_id={transaction_id}")
        return jsonify({ 'message': 'failure' }), response.status_code

    # Clear the cart
    data_cart = {
        'session_id': session_id
    }
    url="{}/cart".format(BASE_URL_API_GATEWAY)
    response = requests.delete(url, json=data_cart)
    if response.status_code != 200:
        span = trace.get_current_span()
        span.set_attribute('event.outcome', 'failure')
        span.set_status(Status(StatusCode.ERROR))
        logger.info(f"session_id={session_id},cart_id={cart_id},action=process_payment,status=failed,amount={amount},transaction_id={transaction_id}")
        return jsonify({ 'message': 'failure' }), response.status_code
    logger.info(f"session_id={session_id},cart_id={cart_id},action=process_payment,status=success,amount={amount},transaction_id={transaction_id}")
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
