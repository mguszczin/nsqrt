# Integer Square Root in Assembly  

## Overview  
This project implements an **integer square root function** `nsqrt` in x86-64 assembly, callable from C.  

That is, `nsqrt` returns the integer part (floor) of the square root of \( X \).  

## Function Interface  
```c
void nsqrt(uint64_t *Q, uint64_t *X, unsigned n);
```
- pointer to the memory where the result will be stored.
- pointer to the binary representation of input **X**. This memory is modifiable and is used as work space during computation.
- - **`n`** – The bit length of the desired result.  
  - It is guaranteed that `n` is a multiple of 64.  
  - `n` ∈ [64, 256000].
## How to use? 
You can compile the source file using 
```c
nasm -f elf64 -w+all -w+error -o nsqrt.o nsqrt.asm
```
and after that you can link the object file. For example: 
```c
gcc -o nsqrt_example_64.o foo.c
```
## Algorithm description
The algorithm computes the result iteratively. Let 
\[
Q_j = \sum_{i=1}^{j} q_i 2^{n-i},
\] 
where \(q_i \in \{0,1\}\) represents the bit determined in the \(i\)-th iteration, and \(R_j\) is the remainder after \(j\) iterations. We initialize \(Q_0 = 0\) and \(R_0 = X\). 

In iteration \(j\), we compute the bit \(q_j\) of the result. Define 
\[
T_{j-1} = 2^{n-j+1} Q_{j-1} + 4^{n-j}.
\] 

If \(R_{j-1} \ge T_{j-1}\), set \(q_j = 1\) and \(R_j = R_{j-1} - T_{j-1}\); otherwise, set \(q_j = 0\) and \(R_j = R_{j-1}\). This gives the recurrence:
\[
R_j = R_{j-1} - q_j (2^{n-j+1} Q_{j-1} + 4^{n-j}).
\] 
After \(n\) iterations, the final remainder is 
\[
R_n = X - Q_n^2.
\] 

It can be shown that 
\[
0 \le R_n \le 2 Q_n.
\]
