COMPONENT=PubSubApp

CFLAGS += -I./Imports

CFLAGS += -DTOSH_DATA_LENGTH=14

#CFLAGS += -I$(TOSDIR)/lib/printf
#CFLAGS += -DNEW_PRINTF_SEMANTICS

include $(MAKERULES)
