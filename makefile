# Makefile for nsqrt examples

# Compiler settings
CC=gcc
CXX=g++
CFLAGS=-Wall -Wextra -std=c17 -O2
CXXFLAGS=-Wall -Wextra -std=c++20 -O2
LDFLAGS=-z noexecstack
LIBS=-lgmp

# Source files
ASM=nsqrt.o
C_EXAMPLE=nsqrt_example_64
CPP_EXAMPLE=nsqrt_example_cpp

# Object files
C_OBJ=nsqrt_example_64.o
CPP_OBJ=nsqrt_example_cpp.o

.PHONY: all clean

all: $(C_EXAMPLE) $(CPP_EXAMPLE)

$(C_OBJ): nsqrt_example.c
	$(CC) -c $(CFLAGS) -o $@ $<

$(CPP_OBJ): nsqrt_example.cpp
	$(CXX) -c $(CXXFLAGS) -o $@ $<

$(C_EXAMPLE): $(C_OBJ) $(ASM)
	$(CC) $(LDFLAGS) -o $@ $(C_OBJ) $(ASM)

$(CPP_EXAMPLE): $(CPP_OBJ) $(ASM)
	$(CXX) $(LDFLAGS) -o $@ $(CPP_OBJ) $(ASM) $(LIBS)

clean:
	rm -f $(C_OBJ) $(CPP_OBJ) $(C_EXAMPLE) $(CPP_EXAMPLE)