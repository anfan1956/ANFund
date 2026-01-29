import asyncio as aio
import websockets
from websockets.asyncio.client import connect


async def main():
  async with connect('wss://echo.websocket.org') as ws:
    print('connected to server')

    while True:
      await aio.sleep(0)

      if ws.state != websockets.State.OPEN:
        print('connection closed')
        break

if __name__ == "__main__":
    aio.run(main())
