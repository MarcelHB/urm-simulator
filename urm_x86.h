#ifndef _H_URM_X86
#define _H_URM_X86

#include "urm_vm.h"
#include "urm_program.h"

typedef struct IterationStackMarker  {
    unsigned int reg;
    unsigned int test_offset;
} IterationStackMarker;

typedef struct Compilation {
    char* byte_code;
    unsigned int size;
    unsigned int byte;
    IterationStackMarker* iteration_stack;
    unsigned int iteration_depth;
} Compilation;

unsigned int start_native(URMVM*, URMProgram*, unsigned int**, unsigned int*);
char* compile_x86(URMVM*, URMProgram*);

void push_bytes(Compilation*, char*, const unsigned int);

void decrease(Compilation*, const unsigned int);
void increase(Compilation*, const unsigned int);
void jump(Compilation*);
void jump_if_zero(Compilation*, const unsigned int);
void reset_stack(Compilation*);
void ret(Compilation*);
#endif
