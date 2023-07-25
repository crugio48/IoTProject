
#include "printf.h"
#include "Timer.h"
#include "message.h"

#define MAX_SUBSCRIPTIONS 30

#define NUM_OF_TOPICS 3

#define MAX_CLIENTS 10


module Project1C @safe()
{
	uses
	{
		/****** INTERFACES *****/
		interface Boot;
		
		interface Receive1;
		interface AMSend1;

		interface Receive2;
		interface AMSend2;



		interface SplitControl as AMControl;
		interface Packet;
		
		//TODO update timers
		interface Timer<TMilli> as ConnectTimer;
		interface Timer<TMilli> as CheckConnectionTimer;
		interface Timer<TMilli> as PublishTimer; 
		interface Timer<TMilli> as CheckSubscriptionTimer;
		interface Timer<TMilli> as NodeRedTimer;

		interface Timer<TMilli> as DelayTimer;

	}
}


implementation
{

	message_t queued_packet;
	uint16_t queue_addr;
	uint16_t time_delays[9]={61,173,267,371,479,583,689,772,891};

	bool generate_send (uint16_t address, message_t* packet);

	bool generate_send (uint16_t address, message_t* packet){
		if (call DelayTimer.isRunning())
		{
			return FALSE;
		}
		else 
		{
			call DelayTimer.startOneShot(time_delays[TOS_NODE_ID-1]);
			queued_packet = *packet;
			queue_addr = address;
		}
		return TRUE;
	}



	message_t* sentPacket;
	bool isRadioLocked = FALSE;

	uint16_t MY_PUBLISH_TOPIC = 0; 		//TODO: just for testing will be random btw 0 and 2

	uint16_t PAN_COORDINATOR_ID = 1;	// Node 1 is the pan coordinator in the simulation
	
	uint16_t PUBLISH_INTERVAL = 5000;

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


	// Timeout time if no ack is received
	int TIMEOUT = 3000;


	//Clients only status variables
	bool connectionCompleted = FALSE;
	bool subscriptionCompleted = FALSE;

	

	
	event void Boot.booted()
	{
		printf("Application of node %d booted.\n", TOS_NODE_ID);
		printfflush();

		call AMControl.start();
	}
	
	
	event void AMControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			printf("Radio of node %d started.\n", TOS_NODE_ID);
			printfflush();

			if (TOS_NODE_ID != PAN_COORDINATOR_ID)
			{
				call ConnectTimer.startOneShot(4000);
			}

			if (TOS_NODE_ID == PAN_COORDINATOR_ID)
			{
				call NodeRedTimer.startPeriodic(6000);
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
		printfflush();
		// do nothing
	}


	void SendPacket(uint16_t address, message_t* packet)
	{


		// Get the payload of the packet to debug the send with the type of packet being sent
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(packet, sizeof(custom_msg_t));
		
		if (isRadioLocked == TRUE)
		{
			printf("WARNING: Node %d found radio locked so did not send a packet of Type %d\n", TOS_NODE_ID, packet_payload->Type);
			printfflush();
			return;
		}

		if (packet_payload -> Type == 0 || packet_payload -> Type == 1){

			if (call AMSend1.send(address, packet, sizeof(custom_msg_t)) == SUCCESS)
			{
				sentPacket = packet;
				isRadioLocked = TRUE;			// lock the radio

				printf("Node %d sending packet of Type %d to address %d\n", TOS_NODE_ID, packet_payload->Type, address);
				printfflush();
			}
			else
			{
				printf("ERROR: Node %d failed sending packet of Type %d to address %d in AMSend.send\n", TOS_NODE_ID,  packet_payload->Type, address);
				printfflush();
			}

		}
		elif (packet_payload -> Type == 2 || packet_payload -> Type == 3){

			if (call AMSend2.send(address, packet, sizeof(custom_msg_t)) == SUCCESS)
			{
				sentPacket = packet;
				isRadioLocked = TRUE;			// lock the radio

				printf("Node %d sending packet of Type %d to address %d\n", TOS_NODE_ID, packet_payload->Type, address);
				printfflush();
			}
			else
			{
				printf("ERROR: Node %d failed sending packet of Type %d to address %d in AMSend.send\n", TOS_NODE_ID,  packet_payload->Type, address);
				printfflush();
			}

		}
	}


	event void AMSend1.sendDone(message_t* bufPtr, error_t error)
	{
		// Get the payload of the packet to debug the send with the type of packet sent
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(bufPtr, sizeof(custom_msg_t));
		
		// Unlock the radio if send is done correctly
		if (error == SUCCESS && sentPacket == bufPtr)
		{
			printf("Node %d sent packet of Type %d successfully\n", TOS_NODE_ID, packet_payload->Type);
			printfflush();
		}
		else
		{
			printf("ERROR: Node %d failed sending packet of Type %d in AMSend.sendDone\n", TOS_NODE_ID, packet_payload->Type);
			printfflush();
			}

		isRadioLocked = FALSE;
	}

	event void AMSend2.sendDone(message_t* bufPtr, error_t error)
	{
		// Get the payload of the packet to debug the send with the type of packet sent
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(bufPtr, sizeof(custom_msg_t));
		
		// Unlock the radio if send is done correctly
		if (error == SUCCESS && sentPacket == bufPtr)
		{
			printf("Node %d sent packet of Type %d successfully\n", TOS_NODE_ID, packet_payload->Type);
			printfflush();
		}
		else
		{
			printf("ERROR: Node %d failed sending packet of Type %d in AMSend.sendDone\n", TOS_NODE_ID, packet_payload->Type);
			printfflush();
			}

		isRadioLocked = FALSE;
	}

	void sendConnectMessage()
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			printfflush();
			return;
		}
		
		packet_payload->Type = 0;
		packet_payload->SenderId = TOS_NODE_ID;


		//SendPacket(PAN_COORDINATOR_ID, &packet);
		generate_send(PAN_COORDINATOR_ID, &packet);
		call CheckConnectionTimer.startOneShot(TIMEOUT);
	}

	void sendConAckMessage(uint16_t clientId)
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			printfflush();
			return;
		}
		
		packet_payload->Type = 1;
		packet_payload->SenderId = TOS_NODE_ID;

		//SendPacket(cliendId , &packet);
		generate_send(clientId, &packet);
	}

	void sendSubscribeMessage()
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			printfflush();
			return;
		}
		
		packet_payload->Type = 2;
		packet_payload->SenderId = TOS_NODE_ID;

		packet_payload->SubscribeTopics[0] = TRUE; //TODO: put random topics to subscribe
		packet_payload->SubscribeTopics[1] = TRUE;
		packet_payload->SubscribeTopics[2] = TRUE;


		//SendPacket(PAN_COORDINATOR_ID, &packet);
		generate_send(PAN_COORDINATOR_ID, &packet);

		call CheckSubscriptionTimer.startOneShot(TIMEOUT);
	}

	void SendSubackMessage(uint16_t targetAddress)
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			printfflush();
			return;
		}
		
		packet_payload->Type = 3;

		//SendPacket(targetAddress, &packet);
		generate_send(targetAddress, &packet);
	}

	void forwardPublishMessage(custom_msg_t* payload_to_forward, uint16_t targetAddress){

		message_t packet;
		payload_to_forward = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));

		//SendPacket(targetAddress, &packet);
		generate_send(targetAddress, &packet);
		

	}

	void sendPublishMessage()
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			printf("ERROR: Node %d failed allocating a packed payload\n", TOS_NODE_ID);
			printfflush();
			return;
		}
		
		packet_payload->Type = 4;
		packet_payload->SenderId = TOS_NODE_ID;
		packet_payload->Topic = MY_PUBLISH_TOPIC; //TODO: put random topic
		packet_payload->Value = 27; //TODO: put random value

		//substitue the SendPacket with DelayTimer
		generate_send(PAN_COORDINATOR_ID, &packet);
	}

	event void DelayTimer.fired()
	{
		SendPacket(queue_addr, &queued_packet);
	}


	// This event will only be triggered once in the whole simulation since we start the ConnectTimer with the method: startOneShot(5000)
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
		printfflush();

		for(i = 0; i < NUM_OF_TOPICS; i++)
		{
			printf("%d:%d\n", i, latestValues[i]);
			printfflush();
		}
		
	}

	void updateConnectedClients(uint16_t *connectedClients, uint16_t clientId){
		int i = 0;
		for (i=0; i < MAX_CLIENTS; i++){
			if (connectedClients[i] == clientId){
				//debug: the client is already connected...
				printf("ERROR: The client %d is already connected to the PAN COORD\n", clientId);
				printfflush();
				return;
			}
			if (connectedClients[i] == 0){
				connectedClients[i] = clientId;
				printf("The client %d was added to the connected clients of the PAN COORD\n", clientId);
				printfflush();
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
				printfflush();
				return;
			}

			if (subscriptions[i].clientId == 0)
			{
				subscriptions[i].clientId = clientId;
				subscriptions[i].topic = topic;
				printf("The client %d subscribed to topic %d\n", clientId, topic);
				printfflush();
				return;
			}
		}
	}

	//*************************************************************************//

	void receivedType0Logic(custom_msg_t *received_payload) {		
		//check if I am the PAN coordinator, otherwise I shouldn't have received the message 
		if (TOS_NODE_ID != PAN_COORDINATOR_ID) {
			printf("ERROR: Node %d received a CON message but it is not a PAN COORD\n", TOS_NODE_ID);
			printfflush();
			return;
		}
		//I am the PAN coordinator update of the connected clients...
		//parsing the message and adding to the connected clients the clientId of the client that sent the message

		updateConnectedClients(connectedClients, received_payload->SenderId);
		
		sendConAckMessage(received_payload->SenderId);

	}

	void receivedType1Logic(custom_msg_t *received_payload) {

		//conn ack received the connection is completed
		call CheckConnectionTimer.stop();

		call PublishTimer.startPeriodic(PUBLISH_INTERVAL);

		sendSubscribeMessage();

	}


	void receivedType2Logic(custom_msg_t *received_payload)
	{
		uint16_t senderId;
		
		bool isClientConnected;
		
		int i;
	
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
		{
			printf("ERROR: Node %d is not the pan coordinator and received a subscribe request\n", TOS_NODE_ID);
			printfflush();
			return;
		}

		senderId = received_payload->SenderId;

		isClientConnected = FALSE;

		for (i = 0; i < 10 /*TODO change to max connections*/; i++)
		{
			if (connectedClients[i] == senderId) isClientConnected = TRUE;
		}

		if (!isClientConnected)
		{
			printf("ERROR: Node %d tried to subscribe without being connected\n", senderId);
			printfflush();
			return;
		}

		if (received_payload->SubscribeTopics[0] == TRUE) SubscribeClientToTopic(senderId, 0);
		
		if (received_payload->SubscribeTopics[1] == TRUE) SubscribeClientToTopic(senderId, 1);

		if (received_payload->SubscribeTopics[2] == TRUE) SubscribeClientToTopic(senderId, 2);
		

		SendSubackMessage(senderId);

	}

	void receivedType3Logic(custom_msg_t *received_payload)
	{
		if (TOS_NODE_ID == PAN_COORDINATOR_ID)
		{
			printf("ERROR: Node %d is the pan coordinator and received a SubAck\n", TOS_NODE_ID);
			printfflush();
			return;
		}

		call CheckSubscriptionTimer.stop();
		
	}

	void receivedType4Logic(custom_msg_t *received_payload) {
		if (TOS_NODE_ID == PAN_COORDINATOR_ID){
			//forward the publish to all the subscribed at that topic
			int i;
			for (i=0; i < MAX_SUBSCRIPTIONS; i++)
			{
				if (subscriptions[i].clientId != received_payload->SenderId && subscriptions[i].clientId != 0 && subscriptions[i].topic == received_payload->Topic){
					forwardPublishMessage(received_payload, subscriptions[i].clientId);
				}
			}

			latestValues[received_payload->Topic] = received_payload->Value;

		}
		else{
			printf("Client %d received publish. Topic: %d, Value: %d\n", TOS_NODE_ID, received_payload->Topic, received_payload->Value);
			printfflush();
		}

	}	
	
	//*************************************************************************//


	event message_t* Receive1.receive(message_t* bufPtr, void* payload, uint8_t len)
	{

		custom_msg_t* packet_payload;


		if (len != sizeof(custom_msg_t)) 
		{
			printf("ERROR: Node %d received wrong lenght packet\n", TOS_NODE_ID);
			printfflush();
			return bufPtr;
		}
				

		packet_payload = (custom_msg_t*)payload;
		
		printf("Node %d received packet of Type %d\n", TOS_NODE_ID, packet_payload->Type);
		printfflush();
		
		
		// Read the Type of the message received and call the correct function to handle the logic
		if (packet_payload->Type == 0) //I received a connect message
		{
			receivedType0Logic(packet_payload);
		}
		
		else if (packet_payload->Type == 1) //I received a con ack message
		{
			receivedType1Logic(packet_payload);
		}
		
		return bufPtr;
		
    }

	event message_t* Receive2.receive(message_t* bufPtr, void* payload, uint8_t len)
	{

		custom_msg_t* packet_payload;


		if (len != sizeof(custom_msg_t)) 
		{
			printf("ERROR: Node %d received wrong lenght packet\n", TOS_NODE_ID);
			printfflush();
			return bufPtr;
		}
				

		packet_payload = (custom_msg_t*)payload;
		
		printf("Node %d received packet of Type %d\n", TOS_NODE_ID, packet_payload->Type);
		printfflush();
		
		
		if (packet_payload->Type == 2) // I received a subscribe message
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