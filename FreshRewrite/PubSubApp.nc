// This file defines the wiring of the components with the interfaces used in this application

#define NEW_PRINTF_SEMANTICS
#include "printf.h"

#include "pub_sub_message.h"

configuration PubSubApp {}

implementation
{
	/******** COMPONENTS *******/
	
	components MainC, PubSub as App;
	components new AMSenderC(AM_PB_MSG);			// for sending messages
	components new AMReceiverC(AM_PB_MSG);		// for receiving messages
	components ActiveMessageC;			// for managing messages and packets
	components SerialPrintfC;			// For the printf
	components RandomC;

	// Custom components:
	components OutQueueModuleC;
	components new TimerMilliC() as SendTimer;
	

	//TODO add as many timers as needed with useful names
	components new TimerMilliC() as ConnectTimer;
	components new TimerMilliC() as CheckConnectionTimer;
	components new TimerMilliC() as PublishTimer;		
	components new TimerMilliC() as CheckSubscriptionTimer;		
	components new TimerMilliC() as NodeRedTimer;			

			


  
	/****** INTERFACES *****/
  
	App.Boot -> MainC.Boot;

	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
	App.Random -> RandomC;

	App.OutQueueModule -> OutQueueModuleC;
	OutQueueModuleC.SendTimer -> SendTimer;

	//TODO timers updated
	App.ConnectTimer -> ConnectTimer;
	App.CheckConnectionTimer -> CheckConnectionTimer;
	App.PublishTimer -> PublishTimer;
	App.CheckSubscriptionTimer -> CheckSubscriptionTimer;
	App.NodeRedTimer -> NodeRedTimer;

}