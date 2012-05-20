#ifndef _H_URM_PROGRAM
#define _H_URM_PROGRAM

#include <stdio.h>

#include "urm_symbols.h"
#include "urm_instruction.h"

enum URMParsingToken { ITERATION };

typedef struct URMStackMarker {
    enum URMParsingToken token;
    unsigned int instruction_number;
    unsigned long byte;
} URMStackMarker;

typedef struct URMProgram {
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
    unsigned long byte;
    unsigned long consumed;
} URMProgram;

void accept(URMProgram*, FILE*);
void next(URMProgram*, FILE*);
void next_char(URMProgram*, FILE*);
unsigned int next_token(URMProgram*, FILE*);

void add_instruction(URMProgram*, URMInstruction*);
void add_error(URMProgram*, char*);
void push_parsing_stack(URMProgram*, enum URMParsingToken);
void pop_parsing_stack(URMProgram*);
URMStackMarker* top_parsing_stack(URMProgram*);

unsigned int parse(URMProgram*, FILE*);
unsigned int parse_destination_list(URMProgram*, FILE*, unsigned int**);
unsigned int parse_operation(URMProgram*, FILE*);
unsigned int parse_operations(URMProgram*, FILE*);
unsigned int parse_iteration(URMProgram*, FILE*);
unsigned int parse_iteration_end(URMProgram*, FILE*);
int parse_positive_border_int(const char*);
int parse_positive_int(URMProgram*, FILE*);

void move(URMProgram*, const unsigned int, unsigned int*, const unsigned int);
void change(URMProgram*, const unsigned int, unsigned int**, const unsigned int);

URMProgram* preconfigure_program(unsigned int*, const unsigned int);
URMProgram* preconfigure_program_loop(unsigned int*, const unsigned int, const unsigned char);
void free_program(URMProgram*);

#endif
