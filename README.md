# IoTProject
Final project of Internet of Things (IoT) @ Politecnico di Milano A.Y. 2021-2022. 

#### Contributors: 
- Matteo Crugnola
- Andrea Carotti

# Lightweight Publish-Subscribe Application Protocol in TinyOS

## Project Overview

This project aims to design and implement a lightweight publish-subscribe application protocol in TinyOS, drawing inspiration from MQTT. The system is structured around a star-shaped network topology with 8 client nodes and a PAN coordinator acting as the broker.

## Features

### 1. Connection
- Each node initiates a connection by sending a `CONNECT` message to the PAN coordinator.
- The PAN coordinator responds with a `CONNACK` message. Messages from unconnected nodes are ignored.
- Retransmissions are handled for lost `CONNECT` or `CONNACK` messages.

### 2. Subscribe
- Nodes subscribe to topics (`TEMPERATURE`, `HUMIDITY`, `LUMINOSITY`) post-connection by sending a `SUBSCRIBE` message.
- Subscriptions are acknowledged by the PAN coordinator with a `SUBACK` message.
- Retransmissions are managed for lost `SUBSCRIBE` or `SUBACK` messages.

### 3. Publish
- Nodes can publish data on their subscribed topics using `PUBLISH` messages.
- The PAN coordinator forwards these messages to all subscribed nodes.

### 4. Simulation Environment
- The protocol is tested in TOSSIM and Cooja simulation environments, with at >= 3 nodes subscribing to multiple topics.

### 5. Integration with Node-RED and ThingSpeak
- The PAN Coordinator is connected to Node-RED and forwards data to ThingSpeak.
- ThingSpeak displays charts for each topic on a public channel (below an example).

![Alt text](https://github.com/crugio48/IoTProject/blob/main/img/livedata.png)


## Implementation Details

- **TinyOS Code**: Provided in the repository.
- **Simulation Logs**: Included as `.log` files for TOSSIM and screenshots for Cooja simulations.
- **Node-RED Code**: Export of Node-RED flow is included, with details on any additional packages used.
- **ThingSpeak Channel**:  https://thingspeak.com/channels/2232186


## Testing and Results

Two channels were used to print the output on two different files (`simulation.log` and `node_red_outfile.txt`).
We ran a simulation of 10 000 events. After each event is run, we check whether a new line was written in the `node_red_outfile.txt` file. If it was, we send to Node-RED this new line through a socket using UDP.
To make the simulation run in real time we call the `Time.sleep()` after each event based on the Tossim simulation time. In this way on Thingspeak the plots would be readable. The elapsed time from the beginning of the simulation gets printed in the stdout while the `RunSimulationScript.py` is run.


## Node-RED Integration

Below an image on the setup in Node-Red

![Alt text](https://github.com/crugio48/IoTProject/blob/main/img/node-red.png)

