// This file defines the payload variables for the messages that will be sent between the nodes

#ifndef PUB_SUB_MESSAGE_H
#define PUB_SUB_MESSAGE_H

typedef nx_struct PB_msg
{
	nx_uint16_t Type;   // 0 = connect, 1 = connack, 2 = sub, 3 = suback, 4 = publish
	nx_uint16_t SenderId;
	nx_uint16_t Topic;  			// 0 = temperature, 1 = humidity, 2 = luminosity
	nx_uint16_t Value;
	nx_uint16_t SubscribeTopics[3];
} PB_msg_t;

enum 
{
	AM_PB_MSG = 10,

	MAX_SUBSCRIPTIONS = 30,

	NUM_OF_TOPICS = 3,

	MAX_CLIENTS = 10,

	NODE_RED_INTERVAL = 6000,

	PUBLISH_INTERVAL = 5000,

	CONNECT_DELAY = 3000, 	// Connection delay after radio is turned on

	TIMEOUT = 3000, 	// Timeout time if no ack is received
};

#endif