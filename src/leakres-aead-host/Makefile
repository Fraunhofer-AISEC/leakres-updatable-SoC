CC = gcc
CFLAGS = -Wall -Wextra -g -O3 -std=gnu11 -DENABLE_ENCRYPT
DEBUGFLAGS =
INCLUDES = -I./mbedtls.git/include
LFLAGS = -L./mbedtls.git/library -Wl,-rpath=./mbedtls.git/library
LIBS = -lmbedcrypto -lm

SRCS = $(wildcard *.c)

LRAEAD = tests/lraead_test

OBJS = $(SRCS:.c=.o)


.PHONY: clean mbedtls

all: $(LRAEAD) $(LRAEAD_TV)

$(LRAEAD): $(OBJS) $(LRAEAD).o
	$(CC) $(CFLAGS) $(INCLUDES) $(DEBUGFLAGS) -o $(LRAEAD) $(LRAEAD).o $(OBJS) $(LFLAGS) $(LIBS)

$(LRAEAD).o: $(LRAEAD).c
	$(CC) $(CFLAGS) $(INCLUDES) $(DEBUGFLAGS) -c $<  -o $@

$(LRAEAD_TV): $(OBJS) $(LRAEAD_TV).o
	$(CC) $(CFLAGS) $(INCLUDES) $(DEBUGFLAGS) -o $(LRAEAD_TV)  $(LRAEAD_TV).o $(OBJS) $(LFLAGS) $(LIBS)

$(LRAEAD_TV).o: $(LRAEAD_TV).c
	$(CC) $(CFLAGS) $(INCLUDES) $(DEBUGFLAGS) -c $<  -o $@
mbedtls:
	git submodule init
	git submodule update --init --recursive
	cd mbedtls.git ;\
	cmake -DUSE_SHARED_MBEDTLS_LIBRARY=On ;\
	make ;\
	make test

%.o : %.c %.h
	$(CC) $(CFLAGS) $(INCLUDES) $(DEBUGFLAGS) -c $<  -o $@

clean:
	rm -rf $(OBJS) $(LRAEAD).o $(LRAEAD) $(LRAEAD_TV) $(LRAEAD_TV).o
