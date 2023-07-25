// This file defines the wiring of the components with the interfaces used in this application

#define NEW_PRINTF_SEMANTICS
#include "printf.h"

#include "message.h"

configuration Project1AppC {}

implementation
{
	/******** COMPONENTS *******/
	
	components MainC, Project1C as App, LedsC;

	components new AMSenderC(AM_COUNT_MSG) as AMSenderC1;			// for sending messages
	components new AMReceiverC(AM_COUNT_MSG) as AMReceiverC1;		// for receiving messages

	components new AMSenderC(9) as AMSenderC2;			// for sending messages
	components new AMReceiverC(9) as AMReceiverC2;		// for receiving messages


	components ActiveMessageC;			// for managing messages and packets
	components SerialPrintfC;			// For the printf
	

	//TODO add as many timers as needed with useful names
	components new TimerMilliC() as ConnectTimer;
	components new TimerMilliC() as CheckConnectionTimer;
	components new TimerMilliC() as PublishTimer;		
	components new TimerMilliC() as CheckSubscriptionTimer;		
	components new TimerMilliC() as NodeRedTimer;
	components new TimerMilliC() as DelayTimer;				

			


  
	/****** INTERFACES *****/
  
	App.Boot -> MainC.Boot;

	App.Receive1 -> AMReceiverC1;
	App.AMSend1 -> AMSenderC1;

	App.Receive2 -> AMReceiverC2;
	App.AMSend2 -> AMSenderC2;


	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;

	//TODO timers updated
	App.ConnectTimer -> ConnectTimer;
	App.CheckConnectionTimer -> CheckConnectionTimer;
	App.PublishTimer -> PublishTimer;
	App.CheckSubscriptionTimer -> CheckSubscriptionTimer;
	App.NodeRedTimer -> NodeRedTimer;
	
	App.DelayTimer -> DelayTimer;

}