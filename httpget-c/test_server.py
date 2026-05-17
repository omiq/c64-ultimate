#!/usr/bin/env python3
"""
Local TCP server for debugging C64 HTTP client.

Listens on port 8080 by default. Logs every received byte (hex + ASCII)
and sends a tiny HTTP response. Run on the Mac, point the C64 dial at
this Mac's IP:8080.

  python3 test_server.py [port]
"""

import socket
import sys
import datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

# Pick the LAN IP for display (just for convenience)
def my_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def hexdump(b):
    out = []
    for byte in b:
        ch = chr(byte) if 32 <= byte < 127 else "."
        out.append(f"{byte:02x}={ch}")
    return " ".join(out)

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", PORT))
    s.listen(1)
    print(f"listening on {my_ip()}:{PORT}")
    print(f"  C64 dial command:  ATDT{my_ip()}:{PORT}")
    print()

    while True:
        conn, addr = s.accept()
        ts = datetime.datetime.now().strftime("%H:%M:%S")
        print(f"[{ts}] connection from {addr[0]}:{addr[1]}")

        # Read whatever comes in until 2s of silence or 4096 bytes
        conn.settimeout(2.0)
        received = bytearray()
        try:
            while len(received) < 4096:
                chunk = conn.recv(256)
                if not chunk:
                    break
                received += chunk
        except socket.timeout:
            pass

        print(f"  RX {len(received)} bytes:")
        # Print as ascii lines (replace non-printable with .)
        for line in received.split(b"\r\n"):
            print(f"    | {line.decode('latin1', errors='replace')}")
        print(f"  hex: {received.hex(' ')}")
        print()

        # Send a small HTTP response
        body = b"<html><body><h1>Hello C64!</h1></body></html>\r\n"
        resp = (
            b"HTTP/1.1 200 OK\r\n"
            b"Content-Type: text/html\r\n"
            b"Content-Length: " + str(len(body)).encode() + b"\r\n"
            b"Connection: close\r\n"
            b"\r\n"
            + body
        )
        try:
            conn.sendall(resp)
            print(f"  TX {len(resp)} bytes (HTTP 200 + small body)")
        except Exception as e:
            print(f"  send error: {e}")

        conn.close()
        print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nstopped.")
