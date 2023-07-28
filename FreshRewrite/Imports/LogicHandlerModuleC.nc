
module LogicHandlerModuleC
{
    provides interface LogicHandlerModule;
}
implementation
{
    async void command LogicHandlerModule.postType0Logic(uint16_t senderId)
    {
        signal LogicHandlerModule.receivedType0Logic(senderId);
    }

    async void command LogicHandlerModule.postType1Logic()
    {
        signal LogicHandlerModule.receivedType1Logic();
    }

    async void command LogicHandlerModule.postType2Logic(uint16_t senderId, uint16_t subToTopic0, uint16_t subToTopic1, uint16_t subToTopic2)
    {
        signal LogicHandlerModule.receivedType2Logic(senderId, subToTopic0, subToTopic1, subToTopic2);
    }

    async void command LogicHandlerModule.postType3Logic()
    {
        signal LogicHandlerModule.receivedType3Logic();
    }

    async void command LogicHandlerModule.postType4Logic(uint16_t senderId, uint16_t topic, uint16_t value)
    {
        signal LogicHandlerModule.receivedType4Logic(senderId, topic, value);
    }
}