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


def safe_send_text(client_socket: socket.socket, text: str) -> bool:
    """
    Send text to a client. Returns False if the client is dropped.
    """
    try:
        client_socket.sendall(text.encode("ascii", "replace"))
        return True
    except (BrokenPipeError, ConnectionResetError, OSError):
        return False


def build_payload() -> str:
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

            safe_send_text(client_socket, "#OK#" + CRLF)
            safe_send_text(client_socket, "WELCOME TO THE WEATHER SERVER" + CRLF)
            safe_send_text(client_socket, build_payload() + CRLF)
            continue

        # Existing client has sent data
        client_socket = sock

        try:
            data = client_socket.recv(RECV_BYTES)
        except BlockingIOError:
            continue
        except (ConnectionResetError, OSError):
            data = b""

        # recv() returns b"" (b=bytes)when the client has disconnected 
        if data == b"":
            print("Client disconnected")
            try:
                clients.remove(client_socket)
            except ValueError:
                pass
            receive_buffers.pop(client_socket, None)
            try:
                client_socket.close()
            except OSError:
                pass
            continue

        # Accumulate data (non-blocking sockets can deliver partial lines)
        receive_buffers[client_socket].extend(data)

        # Process complete lines, split on CR or LF
        while True:
            buf = receive_buffers[client_socket]
            cr_pos = buf.find(b"\r")
            lf_pos = buf.find(b"\n")

            # Find the earliest line break (CR or LF)
            breaks = [p for p in (cr_pos, lf_pos) if p != -1]
            if not breaks:
                break

            # cut = the position in the receive buffer where a line break occurs
            cut = min(breaks)
            line_bytes = bytes(buf[:cut])
            del buf[:cut + 1]

            # Ignore any second newline char (CRLF or LFCR) so we don't get empty lines
            if buf[:1] in (b"\r", b"\n"):
                del buf[:1]

            # Message is the line we received but decoded to ASCII and stripped
            message = line_bytes.decode("ascii", "ignore").strip()
            
            # > indicates data received from client
            print(">", message)

            # Each time we receive a line, just reply with fresh weather/date
            # (for now)
            payload = build_payload()
            if not safe_send_text(client_socket, payload):
                print("Client dropped during send")
                try:
                    clients.remove(client_socket)
                except ValueError:
                    pass
                receive_buffers.pop(client_socket, None)
                try:
                    client_socket.close()
                except OSError:
                    pass
                break
