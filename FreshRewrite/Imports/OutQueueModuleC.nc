/**************************************************************
* Implement a resend buffer. The logic who uses the network modules
* must be implemented in the event ResenModule.sendMessage in the module
* who used the ResendModule interface.
* 
* This module is just a simple queue. If it has elements in it there's
* a timer who fires evert RESEND_DELTA_TIME milliseconds. If the buffer is
* full the command ResendModule.pushMessage returns FAIL, otherwise SUCCES.
* It is always a good idea to check the return value of this command.
*
*
*
**************************************************************/


#define SEND_DELTA_TIME 20 


module OutQueueModuleC
{
    uses
    {
        interface Timer<TMilli> as SendTimer;
    }

    provides interface OutQueueModule;
}
implementation
{
    struct Node
	{
		uint16_t destination_address;
		message_t packet;
		struct Node *next;
	};

    struct Node *queueHead = NULL;


    command void OutQueueModule.pushMessage(uint16_t destination_address, message_t packet)
    {
        struct Node* new_node = (struct Node*)malloc(sizeof(struct Node));
		
		struct Node* temp = queueHead;

		new_node->destination_address = destination_address;
		new_node->packet = packet;
		new_node->next = NULL;

		if (queueHead == NULL)
		{
			queueHead = new_node;
			return;
		}

		while (temp->next != NULL)
        {
            temp = temp->next;
        }

		temp->next = new_node;

        if( !(call SendTimer.isRunning()) )
        {
            call SendTimer.startOneShot(SEND_DELTA_TIME);
        }
    }


    event void SendTimer.fired()
    {
        uint16_t destination_address;
        message_t packet;

        destination_address = queueHead->destination_address;
        packet = queueHead->packet;

	    signal OutQueueModule.sendMessage(destination_address, packet);

        // Remove node from queue:
        struct Node *temp = queueHead;
		
		queueHead = queueHead->next;
		
		free(temp);
		
        // If queue is not empty then restart timer
        if (queueHead != NULL)
        {
            call SendTimer.startOneShot(SEND_DELTA_TIME);
        }
    }
}