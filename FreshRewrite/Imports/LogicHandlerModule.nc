
interface LogicHandlerModule
{
    async void command postType0Logic(uint16_t senderId);
    async void command postType1Logic();
    async void command postType2Logic(uint16_t senderId, uint16_t subToTopic0, uint16_t subToTopic1, uint16_t subToTopic2);
    async void command postType3Logic();
    async void command postType4Logic(uint16_t senderId, uint16_t topic, uint16_t value);

	event void receivedType0Logic(uint16_t senderId);
    event void receivedType1Logic();
    event void receivedType2Logic(uint16_t senderId, uint16_t subToTopic0, uint16_t subToTopic1, uint16_t subToTopic2);
    event void receivedType3Logic();
    event void receivedType4Logic(uint16_t senderId, uint16_t topic, uint16_t value);
}