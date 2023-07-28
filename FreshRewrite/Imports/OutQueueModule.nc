

interface OutQueueModule
{
	command void pushMessage(uint16_t destination_address, message_t packet);
	event void sendMessage(uint16_t destination_address, message_t packet);
}