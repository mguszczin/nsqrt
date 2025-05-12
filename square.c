void square(uint64_t *Q, uint64_t *X, unsigned n){
    int blocks = n / 64;

    for(int i = 0; i < blocks; i++) Q[i] ^= Q[i];   // zerujemy Q[i]
    
    int shift = n;
    for(int i = 1; i <= n; i++) {
    calc_new(Q, shift);
    check_bigger(X,Q,n);
    if(check_bigger) substract(X, Q, n);
    shift--;
    }
}