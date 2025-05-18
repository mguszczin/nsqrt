# Makefile: Debug and Release builds

# Compiler and assembler\ nCC      = gcc
CXX     = g++
NASM    = nasm

# AddressSanitizer flags (optional for debug)
SAN_FLAGS = -fsanitize=address -fno-omit-frame-pointer

# Base flags
BASE_CFLAGS   = -Wall -Wextra -std=c17
BASE_CXXFLAGS = -Wall -Wextra -std=c++20
BASE_NASMFLAGS= -f elf64 -g -F dwarf -w+all -w+error
BASE_LDFLAGS  = -z noexecstack

# Debug configuration
DEBUG_CFLAGS   = $(BASE_CFLAGS) -O0 -g3 $(SAN_FLAGS)
DEBUG_CXXFLAGS = $(BASE_CXXFLAGS) -O0 -g3 $(SAN_FLAGS)
DEBUG_NASMFLAGS= $(BASE_NASMFLAGS)
DEBUG_LDFLAGS  = $(BASE_LDFLAGS) $(SAN_FLAGS)

# Release configuration
RELEASE_CFLAGS   = $(BASE_CFLAGS) -O2
RELEASE_CXXFLAGS = $(BASE_CXXFLAGS) -O2
RELEASE_NASMFLAGS= $(BASE_NASMFLAGS)
RELEASE_LDFLAGS  = $(BASE_LDFLAGS)

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

# Default to release build
all: release

# Build debug targets
debug: CFLAGS   = $(DEBUG_CFLAGS)
debug: CXXFLAGS = $(DEBUG_CXXFLAGS)
debug: NASMFLAGS= $(DEBUG_NASMFLAGS)
debug: LDFLAGS  = $(DEBUG_LDFLAGS)
debug: $(C_BIN) $(CPP_BIN) $(TEST_BIN)

# Build release targets
release: CFLAGS   = $(RELEASE_CFLAGS)
release: CXXFLAGS = $(RELEASE_CXXFLAGS)
release: NASMFLAGS= $(RELEASE_NASMFLAGS)
release: LDFLAGS  = $(RELEASE_LDFLAGS)
release: $(C_BIN) $(CPP_BIN) $(TEST_BIN)

# Assemble nsqrt.asm
$(ASM_OBJ): $(ASM_SRC)
	$(NASM) $(NASMFLAGS) -o $@ $<

# Compile C sources
$(C_OBJ): $(C_SRC)
	$(CC) $(CFLAGS) -c -o $@ $<

# Compile C++ sources
$(CPP_OBJ): $(CPP_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(TEST_CPP_OBJ): $(TEST_CPP_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

# Link executables
$(C_BIN): $(C_OBJ) $(ASM_OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

$(CPP_BIN): $(CPP_OBJ) $(ASM_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^ -lgmp

$(TEST_BIN): $(TEST_CPP_OBJ) $(ASM_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^ -lgmp

# Clean build artifacts
clean:
	rm -f $(ASM_OBJ) $(C_OBJ) $(CPP_OBJ) $(TEST_CPP_OBJ) $(C_BIN) $(CPP_BIN) $(TEST_BIN)
