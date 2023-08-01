
// Implementing a circlular buffer for outgoing packets that failed the send


#define SEND_DELTA_TIME 20 

#define QUEUE_SIZE 100 


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
    uint16_t dest_buffer[QUEUE_SIZE];
    message_t packet_buffer[QUEUE_SIZE];

    int head = 0;
    int tail = 0;
    bool empty = TRUE;

    command error_t OutQueueModule.pushMessage(uint16_t destination_address, message_t packet)
    {
        if(head == tail && !empty)
        {
            return FAIL;
        }
        else
        {
            dest_buffer[tail] = destination_address;
            packet_buffer[tail] = packet;

            tail = (tail + 1) % QUEUE_SIZE;
            empty = FALSE;

            if( !(call SendTimer.isRunning()) )
            {
                call SendTimer.startOneShot(SEND_DELTA_TIME);
            }

            return SUCCESS;
        }
    }


    event void SendTimer.fired()
    {
        uint16_t destination_address;
        message_t packet;

        destination_address = dest_buffer[head];
        packet = packet_buffer[head];

        signal OutQueueModule.sendMessage(destination_address, packet);

        head = (head + 1) % QUEUE_SIZE;

        if(head == tail)
        {
            empty = TRUE;
        }
        else
        {
            call SendTimer.startOneShot(SEND_DELTA_TIME);
        }
    }
}