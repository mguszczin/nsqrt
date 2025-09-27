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
### Algorithm Description

The algorithm computes the integer square root iteratively, one bit at a time. Let  

$$
Q_j = \sum_{i=1}^{j} q_i \, 2^{\,n-i}, \quad q_i \in \{0,1\},
$$  

represent the partial result after \(j\) iterations, and let \(R_j\) be the remainder after \(j\) iterations. Initialize  

$$
Q_0 = 0, \quad R_0 = X.
$$

At iteration \(j\), compute the bit \(q_j\) of the result using  

$$
T_{j-1} = 2^{\,n-j+1} Q_{j-1} + 4^{\,n-j}.
$$ 

Then  

$$
q_j =
\begin{cases} 
1 & \text{if } R_{j-1} \ge T_{j-1}, \\
0 & \text{otherwise},
\end{cases}
\quad
R_j = R_{j-1} - q_j \, T_{j-1}.
$$  

After \(n\) iterations, the final remainder satisfies  

$$
R_n = X - Q_n^2, \quad 0 \le R_n \le 2 Q_n.
$$ 
