
#include "Timer.h"
#include "message.h"


module Project1C @safe()
{
	uses
	{
		/****** INTERFACES *****/
		interface Boot;
		interface Receive;
		interface AMSend;
		interface SplitControl as AMControl;
		interface Packet;
		
		//TODO update timers
		interface Timer<TMilli> as ConnectTimer;
		interface Timer<TMilli> as CheckConnectionTimer;
		interface Timer<TMilli> as PublishTimer; 
		interface Timer<TMIlli> as CheckSubscriptionTimer;
	}
}


implementation
{
	message_t* sentPacket;
	bool isRadioLocked = FALSE;

	uint16_t MY_PUBLISH_TOPIC = 0; 		//TODO: just for testing will be random btw 0 and 2

	uint16_t PAN_COORDINATOR_ID = 1;	// Node 1 is the pan coordinator in the simulation
	uint16_t MAX_CLIENTS = 10;
	uint16_t PUBLISH_INTERVAL = 5000;

	int MAX_SUBSCRIPTIONS = 30;

	struct Subscriptions
	{
		uint16_t clientId;
		uint8_t topic;
	};

	// This array will be used by the pan coordinator only
	struct Subscriptions subscriptions[MAX_SUBSCRIPTIONS] = { {0,0} };

	// This array will be used by the pan coordinator only
	uint16_t connectedClients[MAX_CLIENTS] = { 0 };


	// Timeout time if no ack is received
	int TIMEOUT = 3000;


	//Clients only status variables
	bool connectionCompleted = FALSE;
	bool subscriptionCompleted = FALSE;

	

	
	event void Boot.booted()
	{
		dbg("stdout","Application of node %d booted.\n", TOS_NODE_ID);

		call AMControl.start();
	}
	
	
	event void AMControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			dbg("stdout","Radio of node %d started.\n", TOS_NODE_ID);
			call ConnectTimer.startOneShot(5000);
		}
		else
		{
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err)
	{
		dbg("stdout","Radio of node %d stopped.\n", TOS_NODE_ID);
		// do nothing
	}


	void SendPacket(uint16_t address, message_t* packet)
	{
		// Get the payload of the packet to debug the send with the type of packet being sent
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(packet, sizeof(custom_msg_t));
		
		if (isRadioLocked)
		{
			dbg("stdout","Node %d found the radio locked so did not send a packet of Type %d", TOS_NODE_ID, packet_payload->Type, address);
			return;
		}

		// Try to start sending packet, if successfull then lock radio access
		if (call AMSend.send(address, packet, sizeof(custom_msg_t)) == SUCCESS)
		{
			sentPacket = packet;
			isRadioLocked = TRUE;			// lock the radio

			dbg("stdout","Node %d sending packet of Type %d to address %d\n", TOS_NODE_ID, packet_payload->Type, address);
		}
		else
		{
			dbgerror("stdout","Node %d FAILED sending packet of Type %d to address %d in AMSend.send\n", TOS_NODE_ID,  packet_payload->Type, address);
		}

	}


	event void AMSend.sendDone(message_t* bufPtr, error_t error)
	{
		// Get the payload of the packet to debug the send with the type of packet sent
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(bufPtr, sizeof(custom_msg_t));
		
		// Unlock the radio if send is done correctly
		if (error == SUCCESS && sentPacket == bufPtr)
		{
			dbg("stdout","Node %d sent packet of Type %d successfully\n", TOS_NODE_ID, packet_payload->Type);
		}
		else
		{
			dbgerror("stdout","Node %d FAILED sending packet of Type %d in AMSend.sendDone\n", TOS_NODE_ID, packet_payload->Type);
		}

		isRadioLocked = FALSE;
	}

	void sendConnectMessage()
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			dbgerror("stdout","Node %d FAILED allocating a packed payload", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 0;
		packet_payload->SenderId = TOS_NODE_ID;

		SendPacket(PAN_COORDINATOR_ID, &packet);
		call CheckConnectionTimer.startOneShot(TIMEOUT);
	}

	void sendConAckMessage(uint16_t cliendId)
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			dbgerror("stdout","Node %d FAILED allocating a packed payload", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 1;
		packet_payload->SenderId = TOS_NODE_ID;

		SendPacket(cliendId , &packet);
	}

	void sendSubscribeMessage()
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			dbgerror("stdout","Node %d FAILED allocating a packed payload", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 2;
		packet_payload->SenderId = TOS_NODE_ID;

		packet_payload->SubscribeTopics[0] = TRUE; //TODO: put random topics to subscribe
		packet_payload->SubscribeTopics[1] = TRUE;
		packet_payload->SubscribeTopics[2] = TRUE;


		SendPacket(PAN_COORDINATOR_ID, &packet);
		call CheckSubscriptionTimer.startOneShot(TIMEOUT);
	}

	void SendSubackMessage(uint16 targetAddress)
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			dbgerror("stdout","Node %d FAILED allocating a packed payload", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 3;

		SendPacket(targetAddress, &packet);
	}

	void sendPublishMessage()
	{
		message_t packet;
				
		custom_msg_t* packet_payload = (custom_msg_t*)call Packet.getPayload(&packet, sizeof(custom_msg_t));
		
		if (packet_payload == NULL)
		{
			dbgerror("stdout","Node %d FAILED allocating a packed payload", TOS_NODE_ID);
			return;
		}
		
		packet_payload->Type = 4;
		packet_payload->SenderId = TOS_NODE_ID;
		packet_payload->Topic = MY_PUBLISH_TOPIC; //TODO: put random topic
		packet_payload->Value = 27; //TODO: put random value

		SendPacket(PAN_COORDINATOR_ID, &packet);
	}



	// This event will only be triggered once in the whole simulation since we start the ConnectTimer with the method: startOneShot(5000)
	event void ConnectTimer.fired()
	{
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
		{
			sendConnectMessage();
		}
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

	void updateConnectedClients(uint16_t *connectedClients, uint16_t cliendId){
		int i = 0;
		for (i=0; i < MAX_CLIENTS; i++){
			if (connectedClients[i] == cliendId){
				//debug: the client is already connected...
				dbgerror("stdout","the client %d is already connected to the PAN COORD\n", cliendId);
				return;
			}
			if (connectedClients[i] == 0){
				connectedClients[i] = cliendId;
				dbgerror("stdout","the client %d was added to the connected clients of the PAN COORD\n", cliendId);
				return;
			}
		}
	}

	void SubscribeClientToTopic(uint16 clientId, uint8 topic)
	{
		for (int i = 0; i < MAX_SUBSCRIPTIONS; i++)
		{
			if (subscriptions[i].clientId == clientId && subscriptions[i].topic == topic)
			{
				dbg("stdout","Node %d sent a subscribe request for a topic he is already subscribed to", clientId);
				return;
			}

			if (subscriptions[i].clientId == 0)
			{
				subscriptions[i].clientId = clientId;
				subscriptions[i].topic = topic;
				return;
			}
		}
	}

	//*************************************************************************//

	void receivedType0Logic(custom_msg_t *received_payload) {		
		//check if I am the PAN coordinator, otherwise I shouldn't have received the message 
		if (TOS_NODE_ID != PAN_COORDINATOR_ID) {
			dbgerror("stdout","Node %d received a CON message but it is not a PAN COORD\n", TOS_NODE_ID);
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
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
		{
			dbgerror("stdout","Node %d is not the pan coordinator and received a subscribe request", TOS_NODE_ID);
			return;
		}

		uint16 senderId = received_payload->SenderId;

		bool isClientConnected = FALSE;

		for (int i = 0; i < 10 /*TODO change to max connections*/; i++)
		{
			if (connectedClients[i] == senderId) isClientConnected = TRUE;
		}

		if (!isClientConnected)
		{
			dbgerror("stdout","Node %d tryed to subscribe without being connected", senderId);
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
			dbgerror("stdout","Node %d is the pan coordinator and received a SubAck", TOS_NODE_ID);
			return;
		}

		call CheckSubscriptionTimer.stop();
		
	}

	void receivedType4Logic(custom_msg_t *received_payload) {}	
	
	//*************************************************************************//




	//parsing received packet
	event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len)
	{

		custom_msg_t* packet_payload;
		
		if (len != sizeof(custom_msg_t)) 
		{
			dbgerror("stdout","Node %d received wrong lenght packet", TOS_NODE_ID);
			return bufPtr;
		}
				

		packet_payload = (custom_msg_t*)payload;
		
		dbg("stdout","Node %d received packet of Type %d\n", TOS_NODE_ID, packet_payload->Type);
		
		
		
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