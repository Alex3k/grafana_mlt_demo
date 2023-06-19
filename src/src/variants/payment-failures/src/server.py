# Standard packages
import json
import random
import re
import time

# Third-party packages
from flask import jsonify, request
from opentelemetry import trace
from opentelemetry.trace.status import Status, StatusCode

# Service packages
from common import app, config, logger

RE_NON_DIGITS = re.compile(r'[^0-9]')

def process_payment(card_number, amount):
    """
    Process a payment. Wait for a random time to simulate processing.
    """
    time.sleep(random.uniform(0.5, 1.0))
    if random.choice([1,2,3,4]) % 4 == 0:
        return False
    return True

def validate_card_number(card_number):
    """
    Validate the Luhn checksum of a given card number.
    """
    def digits_of(n):
        return [ int(d) for d in str(n) ]
    digits = digits_of(re.sub(RE_NON_DIGITS, '', card_number))
    odd_digits = digits[-1::-2]
    even_digits = digits[-2::-2]
    checksum = 0
    checksum += sum(odd_digits)
    for d in even_digits:
        checksum += sum(digits_of(d * 2))
    return checksum % 10 == 0


####  HTTP Handlers  ###########################################################

@app.route('/process', methods=['POST',])
def post_payment():
    """
    Process a payment.
    """
    data = request.get_json()
    if not validate_card_number(data.get('card', {}).get('number')):
        span = trace.get_current_span()
        span.set_attribute('event.outcome', 'failure')
        span.set_status(Status(StatusCode.ERROR))
        logger.error(f"Invalid card number", extra={
            'tags': [
                ( 'ip', request.environ.get('REMOTE_ADDR') ),
                ( 'method', request.method ),
                ( 'path', request.path ),
                ( 'user_agent', request.headers.get('User-Agent') ),
                ( 'device_country', request.headers.get('X-Device-Country') ),
                ( 'device_platform', request.headers.get('X-Device-Platform') ),
                ( 'device_id', request.headers.get('X-Device-ID') ),
                ( 'forwarded_for', request.headers.get('X-Forwarded-For') ),
                ( 'customer_tier', request.headers.get('X-Customer-Tier') ),
                ( 'session_id', request.headers.get('X-Session-Id') )
            ]
        })
        return jsonify({ 'message': 'failure', 'reason': 'Invalid card number' }), 400
        
    payment_result = process_payment(data.get('card', {}).get('number'), data.get('amount'))

    if payment_result is False:
        span = trace.get_current_span()
        span.set_attribute('event.outcome', 'failure')
        span.set_status(Status(StatusCode.ERROR))
        logger.error(f"Failed to connect to payment provider", extra={
            'tags': [
                ( 'ip', request.environ.get('REMOTE_ADDR') ),
                ( 'method', request.method ),
                ( 'path', request.path ),
                ( 'user_agent', request.headers.get('User-Agent') ),
                ( 'device_country', request.headers.get('X-Device-Country') ),
                ( 'device_platform', request.headers.get('X-Device-Platform') ),
                ( 'device_id', request.headers.get('X-Device-ID') ),
                ( 'forwarded_for', request.headers.get('X-Forwarded-For') ),
                ( 'customer_tier', request.headers.get('X-Customer-Tier') ),
                ( 'session_id', request.headers.get('X-Session-Id') )
            ]
        })

        return jsonify({ 'message': 'failure', 'reason': 'Failed to connect to payment provider' }), 400

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
