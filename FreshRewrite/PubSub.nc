
#include "printf.h"
#include "Timer.h"
#include "pub_sub_message.h"


module PubSub @safe()
{
	uses
	{
		/****** INTERFACES *****/
		interface Boot;
		interface Receive;
		interface AMSend;
		interface SplitControl as AMControl;
		interface Packet;
        interface Random;

		interface OutQueueModule;
		
		//TODO update timers
		interface Timer<TMilli> as ConnectTimer;
		interface Timer<TMilli> as CheckConnectionTimer;
		interface Timer<TMilli> as PublishTimer; 
		interface Timer<TMilli> as CheckSubscriptionTimer;
		interface Timer<TMilli> as NodeRedTimer;

	}
}


implementation
{
    message_t* sentPacket;
	uint16_t sentDestAddress;

	// Variables to use when sending packets MAYBE
	message_t pktToSend;
	message_t pktToResend;

	struct Subscriptions
	{
		uint16_t clientId;
		uint16_t topic;
	};

	// This array will be used by the pan coordinator only
	struct Subscriptions subscriptions[MAX_SUBSCRIPTIONS] = { {0,0} };

	// This array will be used by the pan coordinator only
	uint16_t connectedClients[MAX_CLIENTS] = { 0 };

	// This array will be used by the pan coordinator only
	uint16_t latestValues[NUM_OF_TOPICS] = { 0 };


    uint16_t MY_PUBLISH_TOPIC;

	uint16_t PAN_COORDINATOR_ID = 1;	// Node 1 is the pan coordinator in the simulation

	
    //-------------------------------> Booting events:

    event void Boot.booted()
	{
		printf("Application of node %d booted.\n", TOS_NODE_ID);
		call AMControl.start();
	}


    event void AMControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			printf("Radio of node %d started.\n", TOS_NODE_ID);

			if (TOS_NODE_ID != PAN_COORDINATOR_ID)
			{
				call ConnectTimer.startOneShot(CONNECT_DELAY);
			}

			if (TOS_NODE_ID == PAN_COORDINATOR_ID)
			{
				call NodeRedTimer.startPeriodic(NODE_RED_INTERVAL);
			}

		}
		else
		{
			call AMControl.start();
		}


	}


    event void AMControl.stopDone(error_t err)
	{
		printf("Radio of node %d stopped.\n", TOS_NODE_ID);
		// do nothing
	}



    //-----------------------------------> Sending functions:


    void SendPacket(uint16_t address, message_t packet)
	{
		// Get the payload of the packet to debug the send with the type of packet being sent
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));

		// Try to start sending packet, if successfull then lock radio access
		if (call AMSend.send(address, &packet, sizeof(PB_msg_t)) == SUCCESS)
		{
			sentPacket = &packet;
			sentDestAddress = address;
			
			printf("Node %d sending packet of Type %d to address %d\n", TOS_NODE_ID, packet_payload->Type, address);
		}
		else
		{
			printf("ERROR: Node %d failed sending packet of Type %d to address %d, pushing to OutQueue...\n", TOS_NODE_ID,  packet_payload->Type, address);
			
			if (call OutQueueModule.pushMessage(address,packet) != SUCCESS)
			{
				printf("FATAL ERROR: Node %d OutQueue buffer is full, lost packet\n", TOS_NODE_ID);
			}
		}
	}

    event void AMSend.sendDone(message_t* bufPtr, error_t error)
	{
		// Get the payload of the packet to debug the send with the type of packet sent
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(bufPtr, sizeof(PB_msg_t));
		
		if (sentPacket == bufPtr)
		{
            if (error == SUCCESS)
            {
                printf("Node %d sent packet of Type %d successfully\n", TOS_NODE_ID, packet_payload->Type);
            }
            else
            {
                printf("ERROR: Node %d failed sending packet of Type %d, pushing to OutQueue...\n", TOS_NODE_ID, packet_payload->Type);

				if (call OutQueueModule.pushMessage(sentDestAddress, *bufPtr) != SUCCESS)
				{
					printf("FATAL ERROR: Node %d OutQueue buffer is full, lost packet\n", TOS_NODE_ID);
				}
            }
		}
	}


	event void OutQueueModule.sendMessage(uint16_t destination_address, message_t packet)
    {
        SendPacket(destination_address, packet);
    }



    //----------------------------------> Packets creation functions:


    void sendConnectMessage()
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 0;
		packet_payload->SenderId = TOS_NODE_ID;

		SendPacket(PAN_COORDINATOR_ID, packet);

		call CheckConnectionTimer.startOneShot(TIMEOUT);
	}

	void sendConAckMessage(uint16_t clientId)
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 1;

		SendPacket(clientId, packet);
	}

	void sendSubscribeMessage()
	{
		message_t packet;
		int i;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 2;
		packet_payload->SenderId = TOS_NODE_ID;


		for (i=0; i < NUM_OF_TOPICS; i++){
			if (call Random.rand16() % 100 < 60) {
				packet_payload->SubscribeTopics[i] = 1; 
			}
			else{
				packet_payload->SubscribeTopics[i] = 0;
			}
		}

		SendPacket(PAN_COORDINATOR_ID, packet);

		call CheckSubscriptionTimer.startOneShot(TIMEOUT);
	}

	void SendSubackMessage(uint16_t clientId)
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 3;

		SendPacket(clientId, packet);
	}

	void forwardPublishMessage(PB_msg_t* payload_to_forward, uint16_t targetAddress)
    {
		message_t packet;

        PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 4;
		packet_payload->SenderId = payload_to_forward->SenderId;
		packet_payload->Topic = payload_to_forward->Topic;
		packet_payload->Value = payload_to_forward->Value;

		SendPacket(targetAddress, packet);
	}

	void sendPublishMessage()
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 4;
		packet_payload->SenderId = TOS_NODE_ID;
		packet_payload->Topic = MY_PUBLISH_TOPIC;
		packet_payload->Value = (uint16_t) call Random.rand16() % 100;   // Random number [0,100)


		SendPacket(PAN_COORDINATOR_ID, packet);
	}


    //------------------------------------------> Timers fired:


	event void ConnectTimer.fired()
	{
		sendConnectMessage();
	}

	event void CheckConnectionTimer.fired()
	{
		sendConnectMessage();	
	}

	event void CheckSubscriptionTimer.fired()
	{
		sendSubscribeMessage();
	}

	event void PublishTimer.fired()
	{
		sendPublishMessage();
	}


	event void NodeRedTimer.fired()
	{
		int i;
		
		printf("Node %d is sending the periodic update to node red\n", TOS_NODE_ID);

		for(i = 0; i < NUM_OF_TOPICS; i++)
		{
			printf("%d:%d\n", i, latestValues[i]);
		}
		printfflush();
	}


    //---------------------------> Update PAN coordinator knowledge functions:

    void updateConnectedClients(uint16_t clientId){
		int i = 0;
		
		printf("DEBUG: Client %d wants to connect\n", clientId);

		for (i=0; i < MAX_CLIENTS; i++)
        {
			if (connectedClients[i] == clientId)
            {
				printf("ERROR: The client %d is already connected to the PAN COORD\n", clientId);
				return;
			}

			if (connectedClients[i] == 0)
            {
				connectedClients[i] = clientId;
				printf("The client %d was added to the connected clients of the PAN COORD\n", clientId);
				return;
			}
		}
	}

	void SubscribeClientToTopic(uint16_t clientId, uint16_t topic)
	{
		int i;
		
		for (i = 0; i < MAX_SUBSCRIPTIONS; i++)
		{
			if (subscriptions[i].clientId == clientId && subscriptions[i].topic == topic)
			{
				printf("ERROR: The client %d sent a subscribe request for a topic he is already subscribed to\n", clientId);
				return;
			}

			if (subscriptions[i].clientId == 0)
			{
				subscriptions[i].clientId = clientId;
				subscriptions[i].topic = topic;
				printf("The client %d subscribed to topic %d\n", clientId, topic);
				return;
			}
		}
	}


    //-------------------------------> Receive logic functions:

    void receivedType0Logic(PB_msg_t *received_payload)
    {		
		//check if I am the PAN coordinator, otherwise I shouldn't have received the message 
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
        {
			printf("ERROR: Node %d received a CON message but it is not a PAN COORD\n", TOS_NODE_ID);
			return;
		}
		//I am the PAN coordinator update of the connected clients...
		//parsing the message and adding to the connected clients the clientId of the client that sent the message

		updateConnectedClients(received_payload->SenderId);
		
		sendConAckMessage(received_payload->SenderId);
	}

	void receivedType1Logic(PB_msg_t *received_payload)
    {
        if (TOS_NODE_ID == PAN_COORDINATOR_ID)
		{
			printf("ERROR: Node %d is the pan coordinator and received a ConAck\n", TOS_NODE_ID);
			return;
		}

		//conn ack received the connection is completed
		call CheckConnectionTimer.stop();
		
		sendSubscribeMessage();

		MY_PUBLISH_TOPIC = (uint16_t) call Random.rand16() % NUM_OF_TOPICS;  // Random int (0,1,2)
		
		call PublishTimer.startPeriodic(PUBLISH_INTERVAL);
		
		printf("Node %d started the publish timer for topic %d\n", TOS_NODE_ID, MY_PUBLISH_TOPIC);
	}


    void receivedType2Logic(PB_msg_t *received_payload)
	{
		bool isClientConnected;
		int i;
	
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
		{
			printf("ERROR: Node %d is not the pan coordinator and received a subscribe request\n", TOS_NODE_ID);
			return;
		}

		isClientConnected = FALSE;

		for (i = 0; i < MAX_CLIENTS; i++)
		{
			if (connectedClients[i] == received_payload->SenderId) isClientConnected = TRUE;
		}

		if (!isClientConnected)
		{
			printf("ERROR: Node %d tried to subscribe without being connected\n", received_payload->SenderId);
			return;
		}

		printf("DEBUG: Node %d subscribe request content: Topic 0: %d | Topic 1: %d | Topic 2: %d\n",
		received_payload->SenderId,
		received_payload->SubscribeTopics[0],
		received_payload->SubscribeTopics[1],
		received_payload->SubscribeTopics[2]);


		if (received_payload->SubscribeTopics[0] == 1) SubscribeClientToTopic(received_payload->SenderId, 0);
		
		if (received_payload->SubscribeTopics[1] == 1) SubscribeClientToTopic(received_payload->SenderId, 1);

		if (received_payload->SubscribeTopics[2] == 1) SubscribeClientToTopic(received_payload->SenderId, 2);
		

		SendSubackMessage(received_payload->SenderId);
	}


    void receivedType3Logic(PB_msg_t *received_payload)
	{
		if (TOS_NODE_ID == PAN_COORDINATOR_ID)
		{
			printf("ERROR: Node %d is the pan coordinator and received a SubAck\n", TOS_NODE_ID);
			return;
		}

		call CheckSubscriptionTimer.stop();
	}

	void receivedType4Logic(PB_msg_t *received_payload)
    {
        int i;

		if (TOS_NODE_ID == PAN_COORDINATOR_ID)
        {
			//forward the publish to all the subscribed at that topic
			for (i=0; i < MAX_SUBSCRIPTIONS; i++)
			{
				if (subscriptions[i].clientId != received_payload->SenderId && subscriptions[i].clientId != 0 && subscriptions[i].topic == received_payload->Topic)
				{					
					forwardPublishMessage(received_payload, subscriptions[i].clientId);
				}
			}

			latestValues[received_payload->Topic] = received_payload->Value;

		}
		else{
			printf("Client %d received publish. Topic: %d, Value: %d\n", TOS_NODE_ID, received_payload->Topic, received_payload->Value);
		}

	}



    //-------------------------> Receive event:

    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len)
	{
		PB_msg_t* packet_payload;
		
		if (len != sizeof(PB_msg_t)) 
		{
			printf("ERROR: Node %d received wrong lenght packet\n", TOS_NODE_ID);
			return bufPtr;
		}

		packet_payload = (PB_msg_t*)payload;
		
		printf("Node %d received packet of Type %d | SenderId = %d | Topic = %d | Value = %d | SubTopics = {%d,%d,%d}\n",
		TOS_NODE_ID,
		packet_payload->Type,
		packet_payload->SenderId,
		packet_payload->Topic,
		packet_payload->Value,
		packet_payload->SubscribeTopics[0],
		packet_payload->SubscribeTopics[1],
		packet_payload->SubscribeTopics[2]);
		
		// Read the Type of the message received and call the correct function to handle the logic
		if (packet_payload->Type == 0) //I received a connect message
		{
			receivedType0Logic(packet_payload);
		}
		
		else if (packet_payload->Type == 1) //I received a con ack message
		{
			receivedType1Logic(packet_payload);
		}
		
		else if (packet_payload->Type == 2) // I received a subscribe message
		{
			receivedType2Logic(packet_payload);
		}

		else if (packet_payload->Type == 3) // I received a sub ack message
		{
			receivedType3Logic(packet_payload);
		}

		else if (packet_payload->Type == 4) // I received a publish message
		{
			receivedType4Logic(packet_payload);
		}

		return bufPtr;
    }

}