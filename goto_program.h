#ifndef _H_GOTO_PROGRAM
#define _H_GORO_PROGRAM

#include "urm_program.h"
#include "dictionary.h"

typedef struct GotoProgram {
    URMInstruction** instruction_list;
    unsigned int instructions;
    unsigned char loop_style;
    char** error_list;
    unsigned int errors;
    URMStackMarker* parsing_stack;
    unsigned int stack_size;
    unsigned int* registers;
    unsigned int number_of_registers;
    unsigned char current_char;
    unsigned int current_label;
    unsigned long byte;
    unsigned long consumed;
    DictNode* labelMap;
    DictNode* unresolvables;
} GotoProgram;

#endif
