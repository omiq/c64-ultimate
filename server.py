from datetime import datetime
import os
import socket
import requests
import select
from dotenv import load_dotenv

load_dotenv()
API_KEY = os.getenv("API_KEY")

CRLF = "\r\n"

def getweather():
    location = "york"
    weather_url = (
        "http://api.openweathermap.org/data/2.5/weather"
        f"?q={location}&APPID={API_KEY}&units=metric"
    )
    r = requests.get(weather_url, timeout=10)
    j = r.json()
    weather = j["weather"][0]["main"]
    temp_c = int(j["main"]["temp"])
    return f"The weather in {location} is {weather} {temp_c}c"

def safe_send(conn, text):
    try:
        conn.sendall(text.encode("ascii", "replace"))
        return True
    except (BrokenPipeError, ConnectionResetError, OSError):
        return False

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("", 6464))
server.listen(256)
server.setblocking(False)

print("Listening on port 6464")

conns = []
bufs = {}

while True:
    rlist = [server] + conns
    readable, _, _ = select.select(rlist, [], [], 0.1)

    for sock in readable:
        if sock is server:
            conn, addr = server.accept()
            conn.setblocking(False)
            conns.append(conn)
            bufs[conn] = bytearray()
            print("Incoming connection from", addr)
            safe_send(conn, "CONNECTED" + CRLF)
            safe_send(conn, "WELCOME TO THE WEATHER SERVER" + CRLF)
            continue

        conn = sock
        try:
            data = conn.recv(4096)
        except BlockingIOError:
            continue
        except (ConnectionResetError, OSError):
            data = b""

        if data == b"":
            conns.remove(conn)
            bufs.pop(conn, None)
            try:
                conn.close()
            except OSError:
                pass
            print("Client disconnected")
            continue

        bufs[conn].extend(data)

        while True:
            b = bufs[conn]
            i = min(
                [x for x in (b.find(b"\r"), b.find(b"\n")) if x != -1],
                default=-1
            )
            if i == -1:
                break

            line = bytes(b[:i])
            del b[:i + 1]

            if b[:1] in (b"\r", b"\n"):
                del b[:1]

            msg = line.decode("ascii", "ignore").strip()
            print(">", msg)

            w = getweather().upper()
            d = datetime.now().strftime("%Y-%m-%d")

            out = CRLF + w + CRLF + d + CRLF
            if not safe_send(conn, out):
                conns.remove(conn)
                bufs.pop(conn, None)
                try:
                    conn.close()
                except OSError:
                    pass
                print("Client dropped during send")
                break

