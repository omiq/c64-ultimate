
from datetime import datetime
import os
import socket
import requests
import asyncio
import loadenv
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("API_KEY")

def getweather():
    # openweathermap API key
    key = API_KEY
    location = "york"
    weather_url = "http://api.openweathermap.org/data/2.5/weather?q=%s&APPID=%s&units=metric" % (location, key)
    weather_data = requests.get(weather_url).json()
    weather = weather_data['weather'][0]['main']
    print(weather)
    return("The weather in %s is %s %dc\n\r" % (location, weather, int(weather_data['main']['temp'])))


server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setblocking(False)

print(server.bind(("", 6464)) )

server.listen(256)

connections = []



while True:
    try:
        connection, address = server.accept()
        print("Incoming connection from ", address)
        connection.send(b"CONNECTED\n\r")

        connection.setblocking(False)
        connections.append(connection)
    except BlockingIOError:
        pass

    for connection in connections:
        try:
            message = connection.recv(4096)
        except BlockingIOError:
            continue

        message=message.strip().decode('ascii')
        print("\n\r>",message)
        connection.send( bytes("\n\r"+getweather().upper() + "\n\r",'ascii') )
        now = datetime.now()
        current_date = now.strftime("%Y-%m-%d")
        print("\n\rCurrent Date =", current_date)
        connection.send( bytes("\n\r"+current_date + "\n\r",'ascii') )


