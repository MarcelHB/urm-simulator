#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "urm_program.h"

static const unsigned int MAX_DECIMAL_NUMBER_BYTES = 10;

void next(URMProgram* program, FILE* stream) {
    program->current_char = fgetc(stream);
    program->byte++;
}

void revert(URMProgram* program, FILE* stream) {
    program->byte--;
    fseek(stream, -1, SEEK_CUR);
}

void next_char(URMProgram* program, FILE* stream) {
    next(program, stream);
    while(!feof(stream) && program->current_char == ' ') {
        next(program, stream);
    }
}

int parse_positive_border_int(const char* buffer) {
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

void add_instruction(URMProgram* program, URMInstruction* instruction) {
    program->instruction_list = (URMInstruction**)realloc(program->instruction_list, sizeof(URMInstruction*) * ++program->instructions);
    program->instruction_list[program->instructions-1] = instruction;
}

void add_error(URMProgram* program, char* message) {
    program->error_list = (char**)realloc(program->error_list, sizeof(char*) * ++program->errors);
    char* message_copy = (char*)malloc(strlen(message) + 1);
    memcpy(message_copy, message, strlen(message) + 1);
    program->error_list[program->errors-1] = message_copy;
}

void push_parsing_stack(URMProgram* program, enum URMParsingToken token) {
    program->parsing_stack = (URMStackMarker*)realloc(program->parsing_stack, sizeof(URMStackMarker) * ++program->stack_size);

    URMStackMarker marker = {
        token,
        program->instructions - 1,
        program->byte
    };
    program->parsing_stack[program->stack_size-1] = marker;
}

URMStackMarker* top_parsing_stack(URMProgram* program) {
    return &(program->parsing_stack[program->stack_size-1]);
}

void pop_parsing_stack(URMProgram* program) {
    program->parsing_stack = (URMStackMarker*)realloc(program->parsing_stack, sizeof(URMStackMarker) * --program->stack_size);
}

int parse_positive_int(URMProgram* program, FILE* stream) {
    // assuming int being 4 bytes, special cases soon?
    unsigned int i = 0;
    unsigned char digit_buffer[MAX_DECIMAL_NUMBER_BYTES+1];
    memset(digit_buffer, 0, MAX_DECIMAL_NUMBER_BYTES+1);

    while(!feof(stream) && i < 10 && program->current_char >= 48 &&
        program->current_char <= 57) {
        digit_buffer[i] = program->current_char;
        i++;
        next(program, stream);
    }

    if(digit_buffer[0] != 0) {
        revert(program, stream);
        int number = 0;
        if(i < 10) {
            sscanf(digit_buffer, "%d", &number);
            return number;
        } else {
            return parse_positive_border_int((char*)&digit_buffer);
        }
    } else {
        return -1;
    }
}

unsigned int parse_operation(URMProgram* program, FILE* stream) {
    enum URMInstructionSymbol instruction = 0;

    switch(program->current_char) {
        case URM_SYMBOL_INC:
            instruction = OP_INC;
            break;
        case URM_SYMBOL_DEC:
            instruction = OP_DEC;
            break;
        default:
            return 0;
    }

    next(program, stream);
    int number = parse_positive_int(program, stream);

    if(number >= 0) {
        URMInstruction* urmi = (URMInstruction*)malloc(sizeof(URMInstruction));
        *urmi = (URMInstruction)  { 
            instruction, 
            1,
            (int*)malloc(sizeof(int))
        };
        *(urmi->arg_list) = number;
        add_instruction(program, urmi);

        return 1;
    } else {
        add_error(program, "NaN for operation register");
        return 0;
    }
}

unsigned int parse_iteration(URMProgram* program, FILE* stream) {
    if(program->current_char == URM_SYMBOL_IT_BEGIN) {
        URMInstruction* urmi = (URMInstruction*)malloc(sizeof(URMInstruction));
        *urmi = (URMInstruction)  { 
            OP_JZ, 
            0,
            NULL
        };
        add_instruction(program, urmi);
        push_parsing_stack(program, ITERATION);

        return 1;
    } else {
        return 0;
    }
}

unsigned int parse_iteration_end(URMProgram* program, FILE* stream) {
    URMStackMarker* marker = top_parsing_stack(program);
    
    if(program->current_char == URM_SYMBOL_IT_END && marker->token == ITERATION) {
        unsigned int distance = program->instructions - marker->instruction_number;
        URMInstruction* urmi = (URMInstruction*)malloc(sizeof(URMInstruction));
        *urmi = (URMInstruction)  { 
            OP_JMP, 
            1,
            (int*)malloc(sizeof(int))
        };        
        // TODO: max distance
        *(urmi->arg_list) = ((int)distance) * -1;
        add_instruction(program, urmi);

        next_char(program, stream);
        int count_register = parse_positive_int(program, stream);

        if(count_register == -1) {
            add_error(program, "no operation register");
            pop_parsing_stack(program);
            return 0;
        }

        URMInstruction* conditional_jump = program->instruction_list[marker->instruction_number];
        conditional_jump->args = 2;
        conditional_jump->arg_list = (int*)malloc(sizeof(int)*2);
        conditional_jump->arg_list[0] = count_register;
        // TODO: overflow check
        conditional_jump->arg_list[1] = distance + 1;
        
        // LOOP-style validation
        if(program->loop_style) {
            unsigned int i = marker->instruction_number, loop_style = 1;
            
            while(i != program->instructions && loop_style) {
                switch(program->instruction_list[i]->instruction) {
                    case OP_INC:
                        if(program->instruction_list[i]->arg_list[0] == count_register) {
                            add_error(program, "attempting to increase the count register");
                            loop_style = 0;
                        }
                        break;
                    case OP_DEC:
                        if(program->instruction_list[i]->arg_list[0] == count_register) {
                            if(i != program->instructions - 2) {
                                add_error(program, "decreasing of counter at wrong location");
                                loop_style = 0;
                            }
                        }
                        break;
                }
                
                if(i == program->instructions - 2) {
                    if(program->instruction_list[i]->instruction != OP_DEC || 
                        program->instruction_list[i]->arg_list[0] != count_register) {
                        add_error(program, "not decreasing the counter");
                        loop_style = 0;
                    }
                }
                ++i;
            }
        }

        pop_parsing_stack(program);
        return 1;
    }
    return 0;
}

unsigned int parse_destination_list(URMProgram* program, FILE* stream, unsigned int** destinations) {
    unsigned int n = 0;
    unsigned int parsing = 1;
    while(parsing) {
        int number = parse_positive_int(program, stream);
        unsigned int number_safe = number;

        if(number != -1) {
            n++;
            *destinations = (unsigned int*)realloc(*destinations, n * sizeof(unsigned int));
            (*destinations)[n-1] = number_safe;
        } else {
            add_error(program, "expected destination");
            break;
        }

        next_char(program, stream);

        switch(program->current_char) {
            case URM_SYMBOL_IT_END:
                parsing = 0;
                break;
            case URM_SYMBOL_COMMA:
                next_char(program, stream);
                break;
           default:
                add_error(program, "expected ',' or ')'");
                parsing = 0;
                break;
        }
    }
    return n;
}

void move(URMProgram* program, const unsigned int source, unsigned int* dests, const unsigned int n) {
    URMInstruction* urmi_jz = (URMInstruction*)malloc(sizeof(URMInstruction));
    *urmi_jz = (URMInstruction)  { 
        OP_JZ, 
        2,
        (int*)malloc(sizeof(int)*2) 
    };
    add_instruction(program, urmi_jz);
    unsigned int exit_jump_location = program->instructions - 1;

    int i = 0;
    for(; i < n; ++i) {
        URMInstruction* urmi_inc = (URMInstruction*)malloc(sizeof(URMInstruction));
        *urmi_inc = (URMInstruction)  { 
            OP_INC, 
            1,
            (int*)malloc(sizeof(int))
        };
        *(urmi_inc->arg_list) = (int)dests[i];
        add_instruction(program, urmi_inc);
    }

    URMInstruction* urmi_dec = (URMInstruction*)malloc(sizeof(URMInstruction));
     *urmi_dec = (URMInstruction)  { 
        OP_DEC, 
        1,
        (int*)malloc(sizeof(int))
    };
    *(urmi_dec->arg_list) = (int)source;
    add_instruction(program, urmi_dec);
    
    // TODO: distance overflow, very long jumps
    unsigned int distance = program->instructions - exit_jump_location;
    URMInstruction* urmi_jmp = (URMInstruction*)malloc(sizeof(URMInstruction));
    *urmi_jmp = (URMInstruction)  { 
        OP_JMP, 
        1,
        (int*)malloc(sizeof(int))
    };
    *(urmi_jmp->arg_list) = ((int)distance) * -1;
    add_instruction(program, urmi_jmp);

    // TODO overflow
    urmi_jz->arg_list[0] = source;
    urmi_jz->arg_list[1] = distance + 1;
}

void change(URMProgram* program, const unsigned int source, unsigned int** dests, const unsigned int n) {
    // TODO: overflow check
    *dests = (unsigned int*)realloc(*dests, (n+1)*sizeof(unsigned int));
    (*dests)[n] = 0;
    move(program, source, *dests, n + 1);
    move(program, 0, (unsigned int*)&source, 1);
}

unsigned int parse_operation_with_args(URMProgram* program, FILE* stream) {
    enum { MOVE, CHANGE } instruction = MOVE;

    switch(program->current_char) {
        case URM_SYMBOL_MOVE:
            instruction = MOVE;
            break;
        case URM_SYMBOL_CHANGE:
            instruction = CHANGE;
            break;
        default:
            return 0;
    }

    next_char(program, stream);

    if(program->current_char == URM_SYMBOL_IT_BEGIN) {
        next_char(program, stream);

        int source_register = parse_positive_int(program, stream);
        unsigned int source_register_safe = 0;
        if(source_register == -1) {
            add_error(program, "no source register");
            return 0;
        }

        source_register_safe = source_register;

        unsigned int* destination_list = (unsigned int*)malloc(0);
        unsigned int destinations = 0;

        next_char(program, stream);
        switch(program->current_char) {
            case URM_SYMBOL_IT_END:
                free(destination_list);
                return 1;
            case URM_SYMBOL_SEPERATOR:
                next_char(program, stream);
                destinations = parse_destination_list(program, stream, &destination_list);
                break;
            default:
                free(destination_list);
                return 0;
        }

        if(instruction == MOVE) {
            move(program, source_register_safe, destination_list, destinations);
        } else {
            change(program, source_register_safe, &destination_list, destinations);
        }

        free(destination_list);
        return 1;
    } else {
        add_error(program, "missing operation arguments");
        return 0;
    }
}

unsigned int parse_operations(URMProgram* program, FILE* stream) {
    if(program->current_char != URM_SYMBOL_SEPERATOR) {
        if(!parse_iteration(program, stream)) {
            if(!parse_operation(program, stream)) {
                return parse_operation_with_args(program, stream);
            }
        }
    }

    return 1;
}

unsigned int next_token(URMProgram* program, FILE* stream) {
    if(!feof(stream)) {
        next_char(program, stream);
        if(program->stack_size == 0) {
            return parse_operations(program, stream);
        } else {
            URMStackMarker* marker = top_parsing_stack(program);
            if(marker->token == ITERATION) {
                if(!parse_operations(program, stream)) {
                    return parse_iteration_end(program, stream);
                }
            }
        }
        return 1;
    }
    return 0;
}

unsigned int parse(URMProgram* program, FILE* stream) {
    if(program->errors > 0) {
        return 0;
    }

    if(program->instructions > 0) {
        return 0;
    }

    while(next_token(program, stream)) {
    }

    URMInstruction* urmi = (URMInstruction*)malloc(sizeof(URMInstruction));
    *urmi = (URMInstruction)  { 
        OP_HALT, 
        0,
        NULL
    };
    add_instruction(program, urmi);

    if(program->stack_size > 0) {
        add_error(program, "stack not closed");
        return 0;
    }

    return 1;
}

void free_program(URMProgram* program) {
    if(program->instructions > 0 && program->instruction_list != NULL) {
        int i = 0;
        for(; i < program->instructions; ++i) {
            free(program->instruction_list[i]->arg_list);
            free(program->instruction_list[i]);
        }
        free(program->instruction_list);
        program->instruction_list = NULL;
    }

    if(program->errors > 0 && program->error_list != NULL) {
        int i = 0;
        for(; i < program->errors; ++i) {
            free(program->error_list[i]);
        }
        free(program->error_list);
        program->error_list = NULL;
    }

    if(program->parsing_stack != NULL) {
        free(program->parsing_stack);
        program->parsing_stack = NULL;
    }

    if(program->registers != NULL) {
        free(program->registers);
        program->registers = NULL;
    }
}

URMProgram* preconfigure_program(unsigned int* registers, const unsigned int n) {
    return preconfigure_program_loop(registers, n, 0);
}

URMProgram* preconfigure_program_loop(unsigned int* registers, const unsigned int n, const unsigned char loop) {
    URMProgram* program = (URMProgram*)malloc(sizeof(URMProgram));
    *program = (URMProgram)  {
        NULL,
        0,
        loop,
        NULL,
        0,
        NULL,
        0,
        (unsigned int*)malloc(sizeof(unsigned int) * n),
        n,
        0,
        0
    };
    memcpy(program->registers, registers, n*sizeof(unsigned int));

    return program;
}
