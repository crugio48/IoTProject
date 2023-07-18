// This file defines the wiring of the components with the interfaces used in this application

#include "message.h"

configuration Project1AppC {}

implementation
{
	/******** COMPONENTS *******/
	
	components MainC, Project1C as App, LedsC;
	components new AMSenderC(AM_COUNT_MSG);			// for sending messages
	components new AMReceiverC(AM_COUNT_MSG);		// for receiving messages
	components ActiveMessageC;			// for managing messages and packets
	

	//TODO add as many timers as needed with useful names
	components new TimerMilliC() as ConnectTimer;
  
	/****** INTERFACES *****/
  
	App.Boot -> MainC.Boot;

	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;

	//TODO timers updated
	App.ConnectTimer -> ConnectTimer;
}