"""
Weather server for a C64 Ultimate or compatible (SwiftLink) over TCP/IP.

The C64u connects using an AT dial string like:
  ATDT 192.168.0.154:6464

What it does:
- Accepts one or more connections
- Sends a welcome with current weather/date on connect
- Waits for a CR/LF
- Sends the weather/date again
- Cleans up sockets/connections on disconnect
- Uses non-blocking
"""

from datetime import datetime
import os
import socket
import select
import requests
import wotd
from dotenv import load_dotenv

load_dotenv()

OPENWEATHER_API_KEY = os.getenv("API_KEY") # set in .env for privacy
LISTEN_HOST = ""                           # "" means all addresses
LISTEN_PORT = 6464
CRLF = "\r\n"

LOCATION = "york" # change to your location
RECV_BYTES = 4096 # how many bytes to read at once 


def fetch_weather_line() -> str:
    """
    Return a short one-line weather report.
    Example: "The weather in york is Clouds 7c"
    """
    url = (
        "http://api.openweathermap.org/data/2.5/weather"
        f"?q={LOCATION}&APPID={OPENWEATHER_API_KEY}&units=metric"
    )
    response = requests.get(url, timeout=10)
    data = response.json()

    condition = data["weather"][0]["main"]
    temp_c = int(data["main"]["temp"])
    return f"The weather in {LOCATION} is {condition} {temp_c}c"


def send_text(client_socket: socket.socket, text: str):
    """Send text to a client."""
    client_socket.sendall(text.encode("ascii", "replace"))


def disconnect_client(client_socket: socket.socket):
    """Disconnect a client."""
    client_socket.close()
    clients.remove(client_socket)
    receive_buffers.pop(client_socket, None)

def weather_and_date() -> str:
    """
    Build the response we send back to the C64.
    """
    weather = fetch_weather_line().upper()
    today = datetime.now().strftime("%Y-%m-%d %H:%M:%S").upper()
    return CRLF + weather + CRLF + today + CRLF


# Create a non-blocking TCP server socket.
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server_socket.bind((LISTEN_HOST, LISTEN_PORT))
server_socket.listen(256)
server_socket.setblocking(False)

print(f"Listening on port {LISTEN_PORT}")

clients = []                 # list of connected client sockets
receive_buffers = {}         # client_socket -> bytearray of partial input

while True:
    # Wait until something is readable: either the server (new connection)
    # or a client (incoming data).
    readable, _, _ = select.select([server_socket] + clients, [], [], 0.1)

    for sock in readable:
        # New incoming TCP connection
        if sock is server_socket:
            client_socket, client_addr = server_socket.accept()
            client_socket.setblocking(False)

            clients.append(client_socket)
            receive_buffers[client_socket] = bytearray()

            print("Incoming connection from", client_addr)

            send_text(client_socket, "#OK#" + CRLF)
            wotd_result = wotd.get_word_of_the_day()
            send_text(client_socket, f"{wotd_result['title']}\n{wotd_result['description']}" + CRLF)
            #send_text(client_socket, "WELCOME TO THE WEATHER SERVER" + CRLF)
            #send_text(client_socket, weather_and_date() + CRLF)

        disconnect_client(client_socket)
        continue
