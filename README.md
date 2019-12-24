# TWITTER-CLONE
The goal of this project is to implement a Twitter clone and a client simulator.
The client part(send/receive tweets) and the engine (distribute tweets) are simulated in different processes.

TEAM MEMBERS:

Srinadh Kakkera (0514-0863)
Neharika Khera (8950-0993)

INSTRUCTIONS FOR EXECUTION



Client Simulator inputs:
The user Registers,  signs in and tweets at the browser.

Running the project :

1. Go to the project folder
2. Run mix deps.get(To install rhe latest dependencies used in the project)
3. Start the server by using mix phx.server
4. The client can be opened in then browser at localhost:4000
5. Register user
6. Signin the user

link for the uploaded youtube video : https://www.youtube.com/watch?v=KbF2E0N3IdY

Functionalities implemented/Working :

1. Register account
2. Send Tweet: tweets can have hashtags (e.g. #COP5615isgreat) and mentions (@1)
3. Subscribe to user's tweets:
4. Re-tweet: (so that your subscribers get an interesting tweet you got by other means)
5. Querying tweets: querying tweets subscribed to, tweets with specific hashtags, tweets in which the user is mentioned (my mentions)
6. Deliver tweets live: if user is connected, deliver types of tweets live
7. Simulator simulates as many users as possible
8. It simulates periods of live connection and disconnection for users

Note:
Client and Server has been modified to use JSON objects to interact with the interface and backend.
We have created a JSON based API  for client
Client uses Socketsto communicate with the Server.
We also designed a JSON based API that represents all messages and their replies (including errors).
Channels allowed us to easily add soft-realtime features to our twitter application. Channels are based on
web sockets. The server acts as a sender and broadcasts messages about topics. Clients act as receivers
and subscribe to topics so that they can get those messages. Senders and receivers can switch roles on
the same topic at any time.
Our Phoenix server holds a single connection and multiplexes channel sockets over that one connection.
Socket handler and  authenticate and identify a socket connection and allow us to set default socket assigns for use in all
channels. The default transport mechanism is via WebSockets.
