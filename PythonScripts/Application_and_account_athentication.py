import json
import asyncio as aio
from websockets.asyncio.client import connect # pip install websockets

creds = json.load(open('myCredentials.json'))

async def main():
  async with connect('wss://demo.ctraderapi.com:5036') as ws:
    print('connected to server')

    # app auth
    client_msg = {
      'payloadType': 2100,
      'payload': {
        'clientId': creds['clientId'],
        'clientSecret': creds['clientSecret']
      }
    }
    print('requested application authentication')
    await ws.send(json.dumps(client_msg))
    server_msg = json.loads(await ws.recv())
    if server_msg['payloadType'] != 2101:
      print('application authentication failed')
      print(json.dumps(server_msg['payload'], indent=2))
      exit()
    print('application authentication completed')

    # account auth
    client_msg = {
      'payloadType': 2102,
      'payload': {
        'ctidTraderAccountId': creds['accountId'],
        'accessToken': creds['accessToken'],
      }
    }
    await ws.send(json.dumps(client_msg))
    print('requested account authentication')
    server_msg = json.loads(await ws.recv())
    if server_msg['payloadType'] != 2103:
      print('account authentication failed')
      print(json.dumps(server_msg['payload'], indent=2))
      exit()
    print('account authentication completed')


    print('fully authenticated and ready for more communication with the server')

aio.run(main())