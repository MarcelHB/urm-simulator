include config.mk

SRC = $(wildcard *.c)
OBJ = $(wildcard *.o)

all: source objects

source: $(SRC)
	$(CC) $(CCFLAGS) -c $+
	
objects:
	$(CC) $(LDFLAGS) $(OBJ) -o urm.exe
  
clean: rm -f *.o
  