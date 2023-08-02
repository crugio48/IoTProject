
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
		interface LogicHandlerModule;
		
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

	// Variables to use when sending packets
	message_t pktToSend;
	
	
	bool isRadioLocked = FALSE;

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
	
	
	uint32_t NODES_DIFFERENT_DELAY[10] = {0,0, 50, 100, 150, 200, 250, 300, 350, 400};

	
    //-------------------------------> Booting events:

    event void Boot.booted()
	{
		dbg("debug", "Application of node %d booted.\n", TOS_NODE_ID);
		call AMControl.start();
	}


    event void AMControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			dbg("debug", "Radio of node %d started.\n", TOS_NODE_ID);

			if (TOS_NODE_ID != PAN_COORDINATOR_ID)
			{
				call ConnectTimer.startOneShot(CONNECT_DELAY + NODES_DIFFERENT_DELAY[TOS_NODE_ID]);
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
		dbg("debug", "Radio of node %d stopped.\n", TOS_NODE_ID);
		// do nothing
	}



    //-----------------------------------> Sending functions:


    void SendPacket(uint16_t address, message_t packet)
	{
		// Get the payload of the packet to debug the send with the type of packet being sent
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (isRadioLocked)
		{
			dbg("debug", "WARNING: Node %d found radio locked when sending packet of Type %d to address %d, pushing to OutQueue...\n", TOS_NODE_ID,  packet_payload->Type, address);
			
			if (call OutQueueModule.pushMessage(address, packet) != SUCCESS)
			{
				dbg("debug", "FATAL ERROR: Node %d OutQueue buffer is full, lost packet\n", TOS_NODE_ID);
			}
			
			return;
		}
		
		pktToSend = packet;

		// Try to start sending packet, if successfull then lock radio access
		if (call AMSend.send((uint16_t) address, &pktToSend, sizeof(PB_msg_t)) == SUCCESS)
		{
			isRadioLocked = TRUE;
			
			sentPacket = &pktToSend;
			sentDestAddress = address;
			
			dbg("debug", "Node %d sending packet of Type %d to address %d\n", TOS_NODE_ID, packet_payload->Type, address);
		}
		else
		{
			dbg("debug", "WARNING: Node %d failed sending packet of Type %d to address %d, pushing to OutQueue...\n", TOS_NODE_ID,  packet_payload->Type, address);
			
			if (call OutQueueModule.pushMessage(address, pktToSend) != SUCCESS)
			{
				dbg("debug", "ERROR: Node %d OutQueue buffer is full, lost packet\n", TOS_NODE_ID);
			}
		}
	}

    event void AMSend.sendDone(message_t* buf, error_t error)
	{
		// Get the payload of the packet to debug the send with the type of packet sent
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(buf, sizeof(PB_msg_t));
		
		if (sentPacket == buf)
		{
			isRadioLocked = FALSE;
			
            if (error == SUCCESS)
            {
                dbg("debug", "Node %d sent packet of Type %d successfully\n", TOS_NODE_ID, packet_payload->Type);
            }
            else
            {
                dbg("debug", "WARNING: Node %d failed sending packet of Type %d, pushing to OutQueue...\n", TOS_NODE_ID, packet_payload->Type);

				if (call OutQueueModule.pushMessage(sentDestAddress, *buf) != SUCCESS)
				{
					dbg("debug", "ERROR: Node %d OutQueue buffer is full, lost packet\n", TOS_NODE_ID);
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
			dbg("debug", "ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 0;
		packet_payload->SenderId = TOS_NODE_ID;

		SendPacket(PAN_COORDINATOR_ID, packet);

		call CheckConnectionTimer.startOneShot(TIMEOUT + NODES_DIFFERENT_DELAY[TOS_NODE_ID]);
	}

	void sendConAckMessage(uint16_t clientId)
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			dbg("debug", "ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 1;

		SendPacket(clientId, packet);
	}

	void sendSubscribeMessage()
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			dbg("debug", "ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 2;
		packet_payload->SenderId = TOS_NODE_ID;
		
		packet_payload->SubscribeTopic0 = 0;
		packet_payload->SubscribeTopic1 = 0;
		packet_payload->SubscribeTopic2 = 0;
		
		if (call Random.rand16() % 100 < 60)
		{
			packet_payload->SubscribeTopic0 = 1;
		}
		
		if (call Random.rand16() % 100 < 60)
		{
			packet_payload->SubscribeTopic1 = 1;
		}
		
		if (call Random.rand16() % 100 < 60)
		{
			packet_payload->SubscribeTopic2 = 1;
		}

		SendPacket(PAN_COORDINATOR_ID, packet);

		call CheckSubscriptionTimer.startOneShot(TIMEOUT + NODES_DIFFERENT_DELAY[TOS_NODE_ID]);
	}

	void SendSubackMessage(uint16_t clientId)
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			dbg("debug", "ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 3;

		SendPacket(clientId, packet);
	}

	void forwardPublishMessage(uint16_t senderId, uint16_t topic, uint16_t value, uint16_t targetAddress)
    {
		message_t packet;

        PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			dbg("debug", "ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 4;
		packet_payload->SenderId = senderId;
		packet_payload->Topic = topic;
		packet_payload->Value = value;

		SendPacket(targetAddress, packet);
	}

	void sendPublishMessage()
	{
		message_t packet;
				
		PB_msg_t* packet_payload = (PB_msg_t*)call Packet.getPayload(&packet, sizeof(PB_msg_t));
		
		if (packet_payload == NULL)
		{
			dbg("debug", "ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
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
		
		dbg("debug", "Node %d sending periodic update with content: %d:%d,%d:%d,%d:%d\n", TOS_NODE_ID,  0, latestValues[0], 1, latestValues[1], 2, latestValues[2]);	
		dbg_clear("node_red", "%d:%d,%d:%d,%d:%d\n", 0, latestValues[0], 1, latestValues[1], 2, latestValues[2]);

	}


    //---------------------------> Update PAN coordinator knowledge functions:

    void updateConnectedClients(uint16_t clientId){
		int i = 0;
		
		dbg("debug", "DEBUG: Client %d wants to connect\n", clientId);

		for (i=0; i < MAX_CLIENTS; i++)
        {
			if (connectedClients[i] == clientId)
            {
				dbg("debug", "WARNING: The client %d is already connected to the PAN COORD\n", clientId);
				return;
			}

			if (connectedClients[i] == 0)
            {
				connectedClients[i] = clientId;
				dbg("debug", "The client %d was added to the connected clients of the PAN COORD\n", clientId);
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
				dbg("debug", "WARNING: The client %d sent a subscribe request for a topic he is already subscribed to\n", clientId);
				return;
			}

			if (subscriptions[i].clientId == 0)
			{
				subscriptions[i].clientId = clientId;
				subscriptions[i].topic = topic;
				dbg("debug", "The client %d subscribed to topic %d\n", clientId, topic);
				return;
			}
		}
	}


    //-------------------------------> Receive logic functions:

    event void LogicHandlerModule.receivedType0Logic(uint16_t senderId)
    {		
		//check if I am the PAN coordinator, otherwise I shouldn't have received the message 
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
        {
			dbg("debug", "ERROR: Node %d received a CON message but it is not a PAN COORD\n", TOS_NODE_ID);
			return;
		}
		//I am the PAN coordinator update of the connected clients...
		//parsing the message and adding to the connected clients the clientId of the client that sent the message

		updateConnectedClients(senderId);
		
		sendConAckMessage(senderId);
	}

	event void LogicHandlerModule.receivedType1Logic()
    {
        if (TOS_NODE_ID == PAN_COORDINATOR_ID)
		{
			dbg("debug", "ERROR: Node %d is the pan coordinator and received a ConAck\n", TOS_NODE_ID);
			return;
		}

		//conn ack received the connection is completed
		call CheckConnectionTimer.stop();
		
		sendSubscribeMessage();

		MY_PUBLISH_TOPIC = (uint16_t) call Random.rand16() % NUM_OF_TOPICS;  // Random int (0,1,2)
		
		call PublishTimer.startPeriodic(PUBLISH_INTERVAL + NODES_DIFFERENT_DELAY[TOS_NODE_ID]);
		
		dbg("debug", "Node %d started the publish timer for topic %d\n", TOS_NODE_ID, MY_PUBLISH_TOPIC);
	}


    event void LogicHandlerModule.receivedType2Logic(uint16_t senderId, uint16_t subToTopic0, uint16_t subToTopic1, uint16_t subToTopic2)
	{
		bool isClientConnected;
		int i;
	
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
		{
			dbg("debug", "ERROR: Node %d is not the pan coordinator and received a subscribe request\n", TOS_NODE_ID);
			return;
		}

		isClientConnected = FALSE;

		for (i = 0; i < MAX_CLIENTS; i++)
		{
			if (connectedClients[i] == senderId) isClientConnected = TRUE;
		}

		if (!isClientConnected)
		{
			dbg("debug", "ERROR: Node %d tried to subscribe without being connected\n", senderId);
			return;
		}

		dbg("debug", "DEBUG: Node %d subscribe request content: Topic 0: %d | Topic 1: %d | Topic 2: %d\n",
		senderId,
		subToTopic0,
		subToTopic1,
		subToTopic2);


		if (subToTopic0 == 1) SubscribeClientToTopic(senderId, 0);
		
		if (subToTopic1 == 1) SubscribeClientToTopic(senderId, 1);

		if (subToTopic2 == 1) SubscribeClientToTopic(senderId, 2);
		

		SendSubackMessage(senderId);
	}


    event void LogicHandlerModule.receivedType3Logic()
	{
		if (TOS_NODE_ID == PAN_COORDINATOR_ID)
		{
			dbg("debug", "ERROR: Node %d is the pan coordinator and received a SubAck\n", TOS_NODE_ID);
			return;
		}

		call CheckSubscriptionTimer.stop();
	}
	

	event void LogicHandlerModule.receivedType4Logic(uint16_t senderId, uint16_t topic, uint16_t value)
    {
        int i;

		if (TOS_NODE_ID == PAN_COORDINATOR_ID)
        {
			//forward the publish to all the subscribed at that topic
			for (i=0; i < MAX_SUBSCRIPTIONS; i++)
			{
				if (subscriptions[i].clientId != senderId && subscriptions[i].clientId != 0 && subscriptions[i].topic == topic)
				{					
					forwardPublishMessage(senderId, topic, value, subscriptions[i].clientId);
				}
			}

			latestValues[topic] = value;

		}
		else{
			dbg("debug", "Client %d received publish. Topic: %d, Value: %d\n", TOS_NODE_ID, topic, value);
		}

	}



    //-------------------------> Receive event:

    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len)
	{		
		PB_msg_t* packet_payload;
		
		if (len != sizeof(PB_msg_t)) 
		{
			dbg("debug", "ERROR: Node %d received wrong lenght packet\n", TOS_NODE_ID);
			return bufPtr;
		}

		packet_payload = (PB_msg_t*)payload;
		
		dbg("debug", "Node %d received packet of Type %d | SenderId = %d | Topic = %d | Value = %d | SubTopics = {%d,%d,%d}\n",
		TOS_NODE_ID,
		packet_payload->Type,
		packet_payload->SenderId,
		packet_payload->Topic,
		packet_payload->Value,
		packet_payload->SubscribeTopic0,
		packet_payload->SubscribeTopic1,
		packet_payload->SubscribeTopic2);
		
		// Read the Type of the message received and call the correct function to handle the logic
		if (packet_payload->Type == 0) //I received a connect message
		{
			call LogicHandlerModule.postType0Logic(packet_payload->SenderId);
		}
		
		else if (packet_payload->Type == 1) //I received a con ack message
		{
			call LogicHandlerModule.postType1Logic();
		}
		
		else if (packet_payload->Type == 2) // I received a subscribe message
		{
			call LogicHandlerModule.postType2Logic(packet_payload->SenderId, packet_payload->SubscribeTopic0, packet_payload->SubscribeTopic1, packet_payload->SubscribeTopic2);
		}

		else if (packet_payload->Type == 3) // I received a sub ack message
		{
			call LogicHandlerModule.postType3Logic();
		}

		else if (packet_payload->Type == 4) // I received a publish message
		{
			call LogicHandlerModule.postType4Logic(packet_payload->SenderId, packet_payload->Topic, packet_payload->Value);
		}

		return bufPtr;
    }

}