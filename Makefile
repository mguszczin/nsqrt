# Compiler and assembler
CC      = gcc
CXX     = g++
NASM    = nasm

# Flags (debug + no optimization)
CFLAGS     = -Wall -Wextra -std=c17 -O0 -g -g3
CXXFLAGS   = -Wall -Wextra -std=c++20 -O0 -g -g3
NASMFLAGS  = -f elf64 -g -F dwarf -w+all -w+error
LDFLAGS    = -z noexecstack

# Sources and objects
ASM_SRC = nsqrt.asm
ASM_OBJ = nsqrt.o

C_SRC   = nsqrt_example.c
C_OBJ   = nsqrt_example_64.o
C_BIN   = nsqrt_example_64

CPP_SRC = nsqrt_example.cpp
CPP_OBJ = nsqrt_example_cpp.o
CPP_BIN = nsqrt_example_cpp

TEST_CPP_SRC = testerka.cpp
TEST_CPP_OBJ = testerka.o
TEST_BIN     = testerka

# Default target: build everything
all: $(C_BIN) $(CPP_BIN) $(TEST_BIN)

# Assemble nsqrt.asm with NASM (with debug symbols)
$(ASM_OBJ): $(ASM_SRC)
	$(NASM) $(NASMFLAGS) -o $@ $<

# Compile C source
$(C_OBJ): $(C_SRC)
	$(CC) $(CFLAGS) -c -o $@ $<

# Link C executable
$(C_BIN): $(C_OBJ) $(ASM_OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

# Compile C++ source
$(CPP_OBJ): $(CPP_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

# Link C++ executable (with GMP library)
$(CPP_BIN): $(CPP_OBJ) $(ASM_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^ -lgmp

# Compile testerka.cpp (with debug flags and no optimization)
$(TEST_CPP_OBJ): $(TEST_CPP_SRC)
	$(CXX) -Wall -Wextra -std=c++20 -O0 -g -g3 -c -o $@ $<

# Link testerka executable (with GMP library)
$(TEST_BIN): $(TEST_CPP_OBJ) $(ASM_OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^ -lgmp


# Clean build artifacts
clean:
	rm -f $(ASM_OBJ) $(C_OBJ) $(CPP_OBJ) $(TEST_CPP_OBJ) $(C_BIN) $(CPP_BIN) $(TEST_BIN)
