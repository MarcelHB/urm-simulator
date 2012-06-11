#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "goto_program.h"

//-----------------------------------------------------------------------------
void next(GotoProgram *program, FILE *stream) {
    program->current_char = fgetc(stream);
    program->byte++;
}

//-----------------------------------------------------------------------------
void next_char(GotoProgram *program, FILE *stream) {
    next(program, stream);
    while(!feof(stream) && program->current_char == ' ') {
        next(program, stream);
    }
}

//-----------------------------------------------------------------------------
void accept(GotoProgram *program, FILE *stream) {
    program->consumed = ftell(stream);
    next_char(program, stream);
}

//-----------------------------------------------------------------------------
void skip_line(GotoProgram *program, FILE *stream) {
    while(program->current_char != '\n') {
        next(program, stream);
    }
}

//-----------------------------------------------------------------------------
int parse_positive_border_int(const char *buffer) {
    int number = 0;
    if(buffer[9] <= 50 &&
        buffer[8] <= 49 &&
        buffer[7] <= 52 &&
        buffer[6] <= 55 &&
        buffer[5] <= 52 &&
        buffer[4] <= 56 &&
        buffer[3] <= 51 &&
        buffer[2] <= 54 &&
        buffer[1] <= 52 &&
        buffer[0] <= 55) {
        sscanf(buffer, "%d", &number);
        return number;
    } else {
        return -1;
    }
}

//-----------------------------------------------------------------------------
void add_instruction(GotoProgram *program, URMInstruction *instruction) {
    program->instruction_list = (URMInstruction**)realloc(program->instruction_list, sizeof(URMInstruction*) * ++program->instructions);
    program->instruction_list[program->instructions-1] = instruction;
}

//-----------------------------------------------------------------------------
int next_line(GotoProgram *program, FILE *stream) {
    if(!feof(stream)) {
        next_char(program, stream);
        
        if(program->current_char == GOTO_COMMENT) {
            skip_line(program, stream);
            return 1;
        }
        
        return parse_instruction(program, stream);
    }
}

//-----------------------------------------------------------------------------
int label_locator(void* key1, void* key2) {
}

//-----------------------------------------------------------------------------
unsigned int get_label_mapping(GotoProgram *program, unsigned int label, short int *success) {
    unsigned int *result = (unsigned int*)dictionary_find(program->labelMap, (void*)&label, label_locator);
    if(result == NULL) {
        *success = 0;
        return 0;
    } else {
        *success = 1;
        return *result;
    }
}

//-----------------------------------------------------------------------------
int set_label_mapping(GotoProgram *program, unsigned int label, unsigned int instruction) {
    unsigned int *label_copy = (unsigned int*)malloc(sizeof(unsigned int)),
        *instruction_copy = (unsigned int*)malloc(sizeof(unsigned int));
    *label_copy = label, *instruction_copy = instruction;

    dictionary_insert(program->labelMap, (void*)label_copy, (void*)instruction_copy, label_locator);
}

//-----------------------------------------------------------------------------
int parse_instruction(GotoProgram *program, FILE *stream) {
    int label_number = parse_positive_int(program, stream);
    short int found = 0;
    
    if(label_number == -1) {
        return 0;
    }
    
    // TODO: check for max allowed labels
    program->current_label = number;
    get_label_mapping(program, number, &found);

    if(found) {
        add_error(program, "[compiling] label duplication");
        return 0;
    }
    
    set_label_mapping(program, number, program->instructions);
    
    next_char(program, stream);
    if(program->current_char == GOTO_LABEL) {
        next_char(program, stream);
    }
    
    if(!parse_modification(program, stream)) {
        return parse_condition(program, stream);
    }
} 

//-----------------------------------------------------------------------------
int parse(GotoProgram *program, FILE *stream) {
    if(program->errors > 0)  {
        return 0;
    }
    
    if(program->instructions > 0) {
        return 1;
    }
    
    while(next_line(program, stream)) {
    }
    
    URMInstruction *urmi = (URMInstruction*)malloc(sizeof(URMInstruction));
    *urmi = (URMInstruction)  { 
        OP_HALT, 
        0,
        NULL
    };
    add_instruction(program, urmi);
    
    resolve(program);
}
