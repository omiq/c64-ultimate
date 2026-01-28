import mysql.connector
import socket
import time
import os
from _thread import *
from funct import *
import wotd
import traceback
from datetime import datetime
# GLOBAL VARIABLES
# DEFINE LISTENING HOST AND PORT
BBS = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
host = '' # leave empty for any IP
port = 6464 # you can change the incoming port to any desired
UsersCount = 0


# Conect to mysql (to make it work: pip install mysql-connector)
# mydb = mysql.connector.connect(
#   host="localhost", #mysql server address
#   user="bbs", #bbs user you created on mysql
#   password="bbspass",
#   database="cbmbbs"
# )

# Define a database cursor to make the queries
# mycursor = mydb.cursor(dictionary=True)

try:
    BBS.bind((host, port))
    BBS.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,True)
except socket.error as e:
    print("Connection error detected ->", str(e))
    exit(1)

print('SERVER > Waiting for a Connection..\r')

BBS.listen()

def do_welcome(connection):

  wotd_header = f"Today is {datetime.now().strftime('%Y-%m-%d')} and here is your word of the day!\n"

  send_line(connection, wotd_header)

  send_line(connection, "#OK#")
  wotd_result = wotd.get_word_of_the_day()
  wotd_string = f"#{wotd_result['title'].upper()}#{wotd_result['description'].upper()}#\n"
  send_line(connection, wotd_string)

  get_char(connection)
  #CLEAR SCREEN
  send_control_code(connection, "clear") #sends a coded cursor
  send_control_code(connection, "home") #sends a coded cursor
  send_seq(connection, "seq/welcome.seq") #sends a seq file to screen

  #THIS SECTION SENDS RANDOM THINGS (FOR YOU TO LEARN HOW)
  send_control_code(connection, "red") #cbmcursor sends color red code
  send_line(connection, "\n\nWelcome") # sends message
  send_control_code(connection, "blue") #cbmcursor sends color blue code
  send_line(connection, " to ") # sends message
  send_control_code(connection, "purple") #cbmcursor sends color purple code
  send_line(connection, "CBMBBS\n\n") # sends message
  send_control_code(connection, "gray") #cbmcursor sends color gray code
  welcome2="This is a text is a text" #You can also declare a string
  send_line(connection, welcome2) #and send it after cbmencode it
  cursorxy(connection,1,1) #cursorxy positions cursor on x,y on screen
  send_line(connection, "up1")
  cursorxy(connection,1,25)
  send_line(connection, "down25")
  cursorxy(connection,10,20)
  get_char(connection)

  send_control_code(connection, "clear") #sends a coded cursor
  send_control_code(connection, "home") #sends a coded cursor
  send_seq(connection, "seq/colaburger.seq")
  cursorxy(connection,30,5)
  get_char(connection)

def do_login(connection):

       #CLEAR SCREEN
       send_control_code(connection,"clear")
       send_control_code(connection,"home")
       cursorxy(connection,1,3) #positions cursor on third line
       maxtries=3 #max tries
       attempts=0

       while True:
         #Login (not finished)
         send_line(connection,"Username (or 'new'): ")
         uname=input_line(connection) #input_line function reads a line

         if (uname=="new"):
             uname,realid = do_newuser(connection)
             print("NEW user created")
             break

         connection.send(cbmencode("Password: "))
         upass=input_pass(connection) #input_pass reads a line but shows '*'

         # Define QUERY
         query="SELECT id,username,password FROM accounts WHERE username='%s'"
         query=query % (uname)

         # Execute QUERY
         # mycursor.execute(query)
         # myresult = mycursor.fetchone()

         # if (myresult == None):
         #    send_line(connection, "\n\nIncorrect username or password.\n\n")
         #    attempts=attempts+1
         # else:
         #    realpass = myresult['password']
         #    realid = myresult['id']

         #    # Check if there is a match
         #    if(realpass==upass):
         #       break
         #    else:
         #       send_line(connection, "\n\nIncorrect username or password.\n\n")
         #       attempts=attempts+1
         # if (attempts>=maxtries):
         #       connection.send(cbmencode("\n\nSorry maximum number of attempts reached..\n\n"))
         #       connection.close()
       uname = "test"
       realid = 1
       print("JUST LOGGED IN -> uname->",uname,"realid->",realid)
       return uname,realid

def do_newuser(connection):
       #CLEAR SCREEN
       send_control_code(connection, "clear")
       send_control_code(connection, "home")
       cursorxy(connection,1,3) #positions cursor on third line
       send_line(connection, "Welcome new user!\nLet's create a new username.\n\n")

       #DEFINE Variables to control loop
       maxtries=5 #max tries
       attempts=0

       while True:
         send_line(connection, "Type your username: ")
         uname=input_line(connection) #input_line function reads a line

         # Define QUERY
         query="SELECT id,username,password FROM accounts WHERE username='%s'"
         query=query % (uname)

         # Execute QUERY
         # mycursor.execute(query)
         # myresult = mycursor.fetchone()

         # #IF user does not exists
         # if(myresult == None and uname!="" and uname !="new"):
         #    send_line(connection, "Your username is: "+uname+"\nAre you sure? (y/n): ")
         #    letter=get_char(connection)
         #    send_line(connection, "\n\n")
         #    attempts=attempts+1
         #    if(letter=="y" or letter=="Y"):
         #       break
         # else:
         #    send_line(connection, "\nError: User already exists.\n")
         #    attempts=attempts+1

         # if attempts >=maxtries:
         #    send_line(connection, "Sorry, maximum number of attempts.\nConnection closed.")
         #    connection.close()

       attempts=0

      #  #Asks for password
      #  while True:
      #    send_line(connection,"\nType your password: ")
      #    pass1=input_pass(connection) #input_line function reads a line
      #    send_line(connection, "\nRepeat your password: ")
      #    pass2=input_pass(connection) #input_line function reads a line
      #    if(pass1!="" and pass2==pass1):
      #      break
      #    attempts=attempts+1
      #    if attempts >= maxtries:
      #       send_line(connection, "Sorry, maximum number of attempts.\nConnection closed. ")
      #       connection.close()
      #    send_line(connection, "\nError: Passwords don't match.\nTry Again.\n\n")

      #  attempts=0

      #  #Asks for email
      #  while True:
      #    send_line(connection, "\nType your email: ")
      #    mail1=input_line(connection) #input_line function reads a line
      #    send_line(connection, "\nRepeat your email: ")
      #    mail2=input_line(connection) #input_line function reads a line
      #    if(mail1!="" and mail2==mail1):
      #      break
      #    attempts=attempts+1
      #    if attempts >= maxtries:
      #       send_line(connection, "Sorry, maximum number of attempts.\nConnection closed. ")
      #       connection.close()
      #    send_line(connection,"\nError: Emails don't match.\nTry Again.\n\n")

      #  print("Creating account:",uname)
      #  ## Creates user here
      #  query="INSERT INTO accounts (username, password, email, active, level) VALUES ('%s','%s','%s',1,1)"
      #  query=query % (uname,pass1,mail1)
      #  mycursor.execute(query)
      #  mydb.commit() #imperative
      #  realid=mycursor.lastrowid
      #  print("NEW User just registered with id:",realid)
       uname = "test"
       realid = 1
       return uname,realid;





# main loop for current user session (one user per thread)
def do_loop(connection,namex,idx):
  global UsersCount

  while True:
    print("USER -> ",namex,"->",idx,"Main Menu") #Outputs for sysop
    send_line(connection, "\n\nChoose an option: ")
    input=(get_char(connection)).upper()
    print(input)
    if input == "Q":
      send_control_code(connection,"clear")
      send_control_code(connection,"home")
      send_line(connection, "\n\nGoodbye!\n")
      connection.close()
      UsersCount -= 1
      print(f"User {namex} closed connection", connection)
      return



def user_session(connection):

      while True:

         do_welcome(connection)

         #userx,idx = do_login(connection)
         userx = "test"
         idx = 1

         do_loop(connection,userx,idx)


# handles multiple simultaneous user connections
def threaded_client(connection):
    global UsersCount
    try:
       connection.settimeout(30) #30 secs timeout (HANGS UP CALL if stalled)
       user_session(connection)
       connection.close()
       print('user exit closed connection',connection)
       UsersCount -= 1
    except Exception:
       connection.close()
       print("Exception in threaded_client", traceback.format_exc())
       print('timeout   closed connection',connection)
       UsersCount -= 1

# MAIN LOOP waits for incoming connections

while True:
    Client, address = BBS.accept()
    print('New connection from: ' + address[0] + ':' + str(address[1]))
    start_new_thread(threaded_client, (Client, ))
    UsersCount += 1
    print('Connected Users: ' + str(UsersCount))

print('Server shutting down...')
BBS.close()
