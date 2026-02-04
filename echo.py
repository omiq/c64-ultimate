import socket
import time
LISTEN_HOST = ""   # empty string means all network interfaces
LISTEN_PORT = 6464

server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server_socket.bind((LISTEN_HOST, LISTEN_PORT))
server_socket.listen(256)
server_socket.setblocking(True)

def send_ansi_file(connection, filename):
    with open(filename, "rb") as f:
        while True:
            data = f.read(1024)
            if not data:
                break
            connection.send(data)
            time.sleep(0.01)

# handle a single message, echo it back, then close the connection
while True:
    connection, address = server_socket.accept()

    # send the welcome ansi screen file
    send_ansi_file(connection, "welcome.ans")

    # wait for a message, echo it back, then close the connection
    input_buffer = connection.recv(1024)
    print(input_buffer.decode("utf-8", errors="replace"))
    connection.send(input_buffer)
    connection.close()

