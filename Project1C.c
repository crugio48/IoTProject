
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
	}
}


implementation
{
	message_t* sentPacket;
	bool isRadioLocked = FALSE;

	uint16_t PAN_COORDINATOR_ID = 1;	// Node 1 is the pan coordinator in the simulation

	struct Subscriptions
	{
		uint16_t clientId;
		uint8_t topic;
	};

	// This array will be used by the pan coordinator only
	struct Subscriptions subscriptions[30] = { {0,0} };

	// This array will be used by the pan coordinator only
	uint16_t connectedClients[10] = { 0 };


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


	// This event will only be triggered once in the whole simulation since we start the ConnectTimer with the method: startOneShot(5000)
	event void ConnectTimer.fired()
	{
		if (TOS_NODE_ID != PAN_COORDINATOR_ID)
		{
			sendConnectMessage()
		}
	}

	event void CheckConnectionTimer.fired()
	{
		if (connectionCompleted == FALSE)
		{
			sendConnectMessage()	
		}
	}

	



}