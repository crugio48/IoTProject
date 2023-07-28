

interface OutQueueModule
{
	command error_t pushMessage(uint16_t destination_address, message_t packet);
	event void sendMessage(uint16_t destination_address, message_t packet);
}