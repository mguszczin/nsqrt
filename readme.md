# Integer Square Root in Assembly  

## Overview  
This project implements an **integer square root function** `nsqrt` in x86-64 assembly, callable from C.  

That is, `nsqrt` returns the integer part (floor) of the square root of \( X \).  

---

## Function Interface  
```c
void nsqrt(uint64_t *Q, uint64_t *X, unsigned n);
