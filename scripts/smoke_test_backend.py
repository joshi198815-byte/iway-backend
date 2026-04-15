#!/usr/bin/env python3
import json
import re
import sys
import time
import urllib.error
import urllib.request

BASE_URL = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:3000/api'
TS = str(int(time.time()))


def request(method, path, payload=None, token=None):
    data = None
    headers = {'Accept': 'application/json'}
    if payload is not None:
        data = json.dumps(payload).encode()
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = f'Bearer {token}'

    req = urllib.request.Request(f'{BASE_URL}{path}', data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        try:
            body = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            body = {'raw': raw}
        return error.code, body


def assert_status(step, status, expected=(200, 201), body=None):
    if status not in expected:
        detail = f' body={json.dumps(body, ensure_ascii=False)}' if body is not None else ''
        raise RuntimeError(f'{step} failed with status {status}{detail}')


def find_latest_code(notifications, title_fragment):
    for notification in reversed(notifications):
        title = notification.get('title', '')
        body = notification.get('body', '')
        if title_fragment in title:
            match = re.search(r'(\d{6})', body)
            if match:
                return match.group(1)
    raise RuntimeError(f'No verification code found for {title_fragment}')


def main():
    results = {}

    status, health = request('GET', '/health')
    assert_status('health', status, (200,))
    results['health'] = health

    status, customer_auth = request('POST', '/auth/register/customer', {
        'fullName': f'Smoke Customer {TS}',
        'email': f'smoke.customer.{TS}@example.com',
        'phone': f'555{TS[-7:]}',
        'password': 'secret123',
        'countryCode': 'GT',
        'stateRegion': 'Guatemala',
        'city': 'Guatemala City',
        'address': 'Zona 10',
    })
    assert_status('register_customer', status)
    customer = customer_auth['user']
    customer_token = customer_auth['accessToken']
    results['customer'] = customer

    png_base64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnR2kQAAAAASUVORK5CYII='

    status, traveler_auth = request('POST', '/auth/register/traveler', {
        'fullName': f'Smoke Traveler {TS}',
        'email': f'smoke.traveler.{TS}@example.com',
        'phone': f'556{TS[-7:]}',
        'password': 'secret123',
        'travelerType': 'solo_tierra',
        'documentNumber': f'P{TS}',
        'documentBase64': png_base64,
        'selfieBase64': png_base64,
        'countryCode': 'US',
        'detectedCountryCode': 'US',
        'stateRegion': 'Florida',
        'city': 'Miami',
        'address': 'Downtown',
    })
    assert_status('register_traveler', status, body=traveler_auth)
    traveler = traveler_auth['user']
    traveler_token = traveler_auth['accessToken']
    results['traveler'] = traveler

    status, verification_phone = request('POST', '/auth/verification-code', {
        'channel': 'phone',
    }, token=traveler_token)
    assert_status('request_phone_verification_code', status, body=verification_phone)

    status, verification_email = request('POST', '/auth/verification-code', {
        'channel': 'email',
    }, token=traveler_token)
    assert_status('request_email_verification_code', status, body=verification_email)

    status, traveler_notifications = request(
        'GET',
        f"/notifications/user/{traveler['id']}",
        token=traveler_token,
    )
    assert_status('traveler_notifications_after_verification_request', status, (200,), traveler_notifications)

    phone_code = find_latest_code(traveler_notifications, 'teléfono')
    email_code = find_latest_code(traveler_notifications, 'correo')

    status, traveler_me = request('POST', '/auth/verify-contact', {
        'channel': 'phone',
        'code': phone_code,
    }, token=traveler_token)
    assert_status('verify_phone', status, body=traveler_me)

    status, traveler_me = request('POST', '/auth/verify-contact', {
        'channel': 'email',
        'code': email_code,
    }, token=traveler_token)
    assert_status('verify_email', status, body=traveler_me)

    status, traveler_kyc = request('POST', f"/travelers/{traveler['id']}/run-kyc-analysis", {}, token=traveler_token)
    assert_status('run_kyc_analysis', status, body=traveler_kyc)
    results['traveler_kyc'] = traveler_kyc

    status, shipment = request('POST', '/shipments', {
        'customerId': 'ignored-by-server',
        'originCountryCode': 'GT',
        'destinationCountryCode': 'US',
        'packageType': 'libra',
        'packageCategory': 'libra',
        'description': 'Smoke package',
        'declaredValue': 120,
        'weightLb': 2,
        'receiverName': 'Test Receiver',
        'receiverPhone': '12345678',
        'receiverAddress': 'Miami address',
        'pickupLat': 14.6349,
        'pickupLng': -90.5069,
        'deliveryLat': 25.7617,
        'deliveryLng': -80.1918,
        'insuranceEnabled': True,
    }, token=customer_token)
    assert_status('create_shipment', status, body=shipment)
    results['shipment'] = shipment

    status, offer = request('POST', '/offers', {
        'shipmentId': shipment['id'],
        'travelerId': 'ignored-by-server',
        'price': 45,
    }, token=traveler_token)
    assert_status('create_offer', status, body=offer)
    results['offer'] = offer

    status, accepted = request('POST', f"/offers/{offer['id']}/accept", {
        'acceptedByCustomerId': 'ignored-by-server',
    }, token=customer_token)
    assert_status('accept_offer', status)
    results['accepted'] = accepted

    status, chat = request('POST', f"/chat/shipment/{shipment['id']}", {}, token=customer_token)
    assert_status('get_or_create_chat', status)
    results['chat'] = chat

    status, message = request('POST', '/chat/messages', {
        'chatId': chat['id'],
        'senderId': 'ignored-by-server',
        'body': 'Hola, este es un mensaje de prueba dentro de iWay',
    }, token=customer_token)
    assert_status('send_message', status)
    results['message'] = message

    status, tracking = request('POST', '/tracking', {
        'shipmentId': shipment['id'],
        'travelerId': 'ignored-by-server',
        'lat': 25.7617,
        'lng': -80.1918,
        'accuracyM': 10,
        'checkpoint': 'miami',
    }, token=traveler_token)
    assert_status('send_tracking', status)
    results['tracking'] = tracking

    status, rating = request('POST', '/ratings', {
        'shipmentId': shipment['id'],
        'fromUserId': 'ignored-by-server',
        'stars': 5,
        'comment': 'Prueba smoke test OK',
    }, token=customer_token)
    assert_status('create_rating', status)
    results['rating'] = rating

    status, traveler_notifications = request(
        'GET',
        f"/notifications/user/{traveler['id']}",
        token=traveler_token,
    )
    assert_status('traveler_notifications', status, (200,))
    results['traveler_notifications'] = traveler_notifications

    status, customer_notifications = request(
        'GET',
        f"/notifications/user/{customer['id']}",
        token=customer_token,
    )
    assert_status('customer_notifications', status, (200,))
    results['customer_notifications'] = customer_notifications

    status, traveler_ratings = request(
        'GET',
        f"/ratings/user/{traveler['id']}",
        token=traveler_token,
    )
    assert_status('traveler_ratings', status, (200,))
    results['traveler_ratings'] = traveler_ratings

    status, route = request(
        'GET',
        f"/tracking/shipment/{shipment['id']}/route",
        token=customer_token,
    )
    assert_status('shipment_route', status, (200,))
    results['route'] = route

    summary = {
        'baseUrl': BASE_URL,
        'health_ok': results['health'].get('ok'),
        'shipment_status': results['shipment'].get('status'),
        'traveler_verification_score': results['traveler_kyc'].get('score'),
        'traveler_trust_score': results['traveler_kyc'].get('trustScore'),
        'offer_status': results['offer'].get('status'),
        'accepted_status': results['accepted'].get('status'),
        'chat_id': results['chat'].get('id'),
        'message_id': results['message'].get('message', {}).get('id'),
        'tracking_id': results['tracking'].get('id'),
        'rating_id': results['rating'].get('id'),
        'traveler_notifications_count': len(results['traveler_notifications']),
        'customer_notifications_count': len(results['customer_notifications']),
        'traveler_ratings_count': len(results['traveler_ratings']),
        'route_has_path': results['route'].get('hasRoute'),
        'route_points_count': len(results['route'].get('points', [])),
        'auth_customer_token': bool(customer_token),
        'auth_traveler_token': bool(traveler_token),
    }

    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
