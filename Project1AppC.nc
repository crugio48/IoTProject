// This file defines the wiring of the components with the interfaces used in this application

#define NEW_PRINTF_SEMANTICS
#include "printf.h"

#include "message.h"

configuration Project1AppC {}

implementation
{
	/******** COMPONENTS *******/
	
	components MainC, Project1C as App, LedsC;
	components new AMSenderC(AM_COUNT_MSG);			// for sending messages
	components new AMReceiverC(AM_COUNT_MSG);		// for receiving messages
	components ActiveMessageC;			// for managing messages and packets
	components SerialPrintfC;			// For the printf
	

	//TODO add as many timers as needed with useful names
	components new TimerMilliC() as ConnectTimer;
	components new TimerMilliC() as CheckConnectionTimer;
	components new TimerMilliC() as PublishTimer;		
	components new TimerMilliC() as CheckSubscriptionTimer;		
			


  
	/****** INTERFACES *****/
  
	App.Boot -> MainC.Boot;

	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;

	//TODO timers updated
	App.ConnectTimer -> ConnectTimer;
	App.CheckConnectionTimer -> CheckConnectionTimer;
	App.PublishTimer -> PublishTimer;
	App.CheckSubscriptionTimer -> CheckSubscriptionTimer;
}