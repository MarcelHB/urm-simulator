include config.mk

SRC = $(wildcard *.c)

all: source

source: $(SRC)
	$(CC) $(CCFLAGS) -c $+
  
clean: rm -f *.o
  