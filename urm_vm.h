#ifndef _H_URM_VM
#define _H_URM_VM

#include "urm_program.h"

typedef struct URMVM {
    unsigned int index;
    unsigned int stopped;
    unsigned int* registers;
    unsigned int number_of_registers;
} URMVM;

void allocate(URMVM*, unsigned int);
void preallocate_registers(URMVM*, URMProgram*, unsigned int*, unsigned int);
unsigned int start_program(URMVM*, URMProgram*, unsigned int**, unsigned int*);
void free_vm(URMVM*);

#endif
