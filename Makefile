# Compiler and assembler
CC      = gcc
CXX     = g++
NASM    = nasm

# AddressSanitizer flags for debug
SAN_FLAGS = -fsanitize=address -fno-omit-frame-pointer

# Base flags
BASE_CFLAGS    = -Wall -Wextra -std=c17
BASE_CXXFLAGS  = -Wall -Wextra -std=c++20
BASE_NASMFLAGS = -f elf64 -w+all -w+error
BASE_LDFLAGS   = -z noexecstack

# Build type: 'release' or 'debug'
BUILD ?= release

# Flags based on build type
ifeq ($(BUILD),debug)
	CFLAGS    = $(BASE_CFLAGS) -O0 -g3 $(SAN_FLAGS)
	CXXFLAGS  = $(BASE_CXXFLAGS) -O0 -g3 $(SAN_FLAGS)
	NASMFLAGS = $(BASE_NASMFLAGS) -g -F dwarf
	LDFLAGS   = $(BASE_LDFLAGS) $(SAN_FLAGS) -g
else
	CFLAGS    = $(BASE_CFLAGS) -O2
	CXXFLAGS  = $(BASE_CXXFLAGS) -O2
	NASMFLAGS = $(BASE_NASMFLAGS)
	LDFLAGS   = $(BASE_LDFLAGS)
endif

# Sources and objects
ASM_SRC       = nsqrt.asm
ASM_OBJ       = nsqrt.o

C_SRC         = nsqrt_example.c
C_OBJ         = nsqrt_example_64.o
C_BIN         = nsqrt_example_64

CPP_SRC       = nsqrt_example.cpp
CPP_OBJ       = nsqrt_example_cpp.o
CPP_BIN       = nsqrt_example_cpp

TEST_CPP_SRC  = testerka.cpp
TEST_CPP_OBJ  = testerka.o
TEST_BIN      = testerka

.PHONY: all debug release clean

# Default to release
all: release

debug:
	$(MAKE) all BUILD=debug

release:
	$(MAKE) build BUILD=release

build: $(C_BIN) $(CPP_BIN) $(TEST_BIN)

# Assemble
$(ASM_OBJ): $(ASM_SRC)
	$(NASM) $(NASMFLAGS) -o $@ $<

# Compile
$(C_OBJ): $(C_SRC)
	$(CC) $(CFLAGS) -c -o $@ $<

$(CPP_OBJ): $(CPP_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(TEST_CPP_OBJ): $(TEST_CPP_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

# Link
$(C_BIN): $(C_OBJ) $(ASM_OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

$(CPP_BIN): $(CPP_OBJ) $(ASM_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^ -lgmp

$(TEST_BIN): $(TEST_CPP_OBJ) $(ASM_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^ -lgmp

# Clean
clean:
	rm -f $(ASM_OBJ) $(C_OBJ) $(CPP_OBJ) $(TEST_CPP_OBJ) $(C_BIN) $(CPP_BIN) $(TEST_BIN)
