// This file defines the payload variables for the messages that will be sent between the nodes

#ifndef MESSAGE_H
#define MESSAGE_H

typedef nx_struct custom_msg
{
	nx_uint8_t Type;   // 0 = connect, 1 = connack, 2 = sub, 3 = suback, 4 = publish
	nx_uint16_t SenderId;
	nx_bool SubscribeTopics[3]; // 0 = temperature, 1 = humidity, 2 = luminosity
	nx_uint8_t Topic;  			// 0 = temperature, 1 = humidity, 2 = luminosity
	nx_uint16_t Value;

} custom_msg_t;

enum {
  AM_COUNT_MSG = 10,
};

#endif