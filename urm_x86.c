#include <string.h>
#include <stdlib.h>

#include "urm_program.h"
#include "urm_vm.h"
#include "urm_x86.h"

const unsigned int chunk_size = 1024;

void push_bytes(Compilation* c, char* bytes, const unsigned int n) {
    // TODO: overflow checks
    if(c->byte + n >= c->size) {
        unsigned int chunks = 1;
        
        if(n > chunk_size) {
            chunks = n / chunk_size + 1;
        }
        c->byte_code = (char*)realloc(c->byte_code, (c->size + chunk_size * chunks) * sizeof(char));
        c->size += chunk_size * chunks;
    }
    memcpy(c->byte_code + c->byte, bytes, n);
    c->byte += n;
}

void reset_stack(Compilation* c) {
    char b[] = { 0x83, 0xC4, 0x04 }; // ADD ESP, 4
    push_bytes(c, (char*)&b, sizeof(b)); 
}

void ret(Compilation* c) {
    char b[] = { 0xC3 }; // RET
    push_bytes(c, (char*)&b, sizeof(b));
}

void increase(Compilation* c, const unsigned int reg) {
    // TODO: handle offsets > 255
    if(c->iteration_depth > 0 && c->iteration_stack[c->iteration_depth-1].reg == reg) {
        char b[] = { 0x41 };                                        // INC ECX
        push_bytes(c, (char*)&b, sizeof(b));
    } else {
        char b[] = { 0x8B, 0x44, 0x24, 0x08,                        // MOV EAX, [ESP+8]
                     0x83, 0xC0, reg * sizeof(unsigned int),        // ADD EAX, reg * 4
                     0x8B, 0x54, 0x24, 0x08,                        // MOV EDX, [ESP+8]
                     0x83, 0xC2, reg * sizeof(unsigned int),        // ADD EDX, reg * 4
                     0x8B, 0x12,                                    // MOV EDX, [EDX]
                     0x42,                                          // INC EDX
                     0x89, 0x10                                     // MOV [EAX], EDX
        };
        push_bytes(c, (char*)&b, sizeof(b));
    }
}

void decrease(Compilation* c, const unsigned int reg) {
    // TODO: handle offsets > 255
    if(c->iteration_depth > 0 && c->iteration_stack[c->iteration_depth-1].reg == reg) {
        char b[] = { 0x85, 0xC9,                                    // TEST ECX, ECX
                     0x74, 0x01,                                    // JZ 0x01
                     0x49                                           // DEC ECX
        };
    } else {
        char b[] = { 0x8B, 0x44, 0x24, 0x08,                        // MOV EAX, [ESP+8]
                     0x83, 0xC0, reg * sizeof(unsigned int),        // ADD EAX, reg * 4
                     0x8B, 0x00,                                    // MOV EAX, [EAX]
                     0x85, 0xC0,                                    // TEST EAX, EAX
                     0x74, 0x11,                                    // JZ 0x11
                     0x8B, 0x44, 0x24, 0x08,                        // MOV EAX, [ESP+8]
                     0x83, 0xC0, reg * sizeof(unsigned int),        // ADD EAX, reg * 4
                     0x8B, 0x54, 0x24, 0x08,                        // MOV EDX, [ESP+8]
                     0x83, 0xC2, reg * sizeof(unsigned int),        // ADD EDX, reg * 4
                     0x4A,                                          // DEC EDX
                     0x89, 0x10                                     // MOV [EAX], EDX
        };
        push_bytes(c, (char*)&b, sizeof(b));
    }
}

void jump_if_zero(Compilation* c, const unsigned int reg) {
    // TODO: handle long jumps
    // TODO: cheating version as in Ruby?
    if(c->iteration_depth > 0) {
        unsigned int old_counter_register = c->iteration_stack[c->iteration_depth-1].reg;
        char b[] = { 0x89, 0x4C, 0x24, old_counter_register * sizeof(unsigned int) + 8 }; // MOV [ESP+8+(old_reg*4)], ECX
        push_bytes(c, (char*)&b, sizeof(b));
    }
	
    char b[] = { 0x8B, 0x44, 0x24, 0x08,                        // MOV EAX, [ESP+8]
                 0x83, 0xC0, reg * sizeof(unsigned int),        // ADD EAX, reg * 4
                 0x8B, 0xC8,                                    // MOV ECX, EAX
                 0x85, 0xC9,                                    // TEST ECX, ECX <-- need to jump back here
                 0x74, 0x00                                     // JZ (to be determined before JUMP)
    };
    push_bytes(c, (char*)&b, sizeof(b));
    c->iteration_stack = (IterationStackMarker*)realloc(c->iteration_stack, sizeof(IterationStackMarker) * ++(c->iteration_depth));
    c->iteration_stack[c->iteration_depth-1] = (IterationStackMarker){ reg, c->byte - 4 };
}

void jump(Compilation* c) {
    // TODO: find jump target
    char b[] = { 0xE9, 0x00, 0x00, 0x00, 0x00 };                                  // JMP LONG (back to TEST)
    push_bytes(c, (char*)&b, sizeof(b));
    
    unsigned int current_byte = c->byte, 
        test_byte = c->iteration_stack[c->iteration_depth].test_offset,
        test_address = (int)&(c->byte_code[test_byte]);
    int distance = current_byte - test_byte;
    
    // JZ xx is 3 bytes ahead
    c->byte_code[test_byte+3] = distance + 1;
    // JMP xx is 4 previous bytes
    c->byte_code[current_byte-4] = (char)(test_address >> 24);
    c->byte_code[current_byte-3] = (char)(test_address >> 16); 
    c->byte_code[current_byte-2] = (char)(test_address >> 8); 
    c->byte_code[current_byte-1] = (char)(test_address); 
    
    c->iteration_stack = (IterationStackMarker*)realloc(c->iteration_stack, sizeof(IterationStackMarker) * --(c->iteration_depth));
    
    if(c->iteration_depth > 0) {
        unsigned int old_counter_register = c->iteration_stack[c->iteration_depth-1].reg;
        char ecx_bytes[] = { 0x89, 0x4C, 0x24, old_counter_register * sizeof(unsigned int) + 8 }; // MOV ECX, [ESP+8+(old_reg*4)] 
        push_bytes(c, (char*)&ecx_bytes, sizeof(ecx_bytes));
    }
}

char* compile_x86(URMVM* vm, URMProgram* program) {
    Compilation c = { NULL, 0, 0, NULL, 0 };
    
    int i = 0;
    for(; i < program->instructions; ++i) {
        URMInstruction* instr = &(program->instruction_list[i]);

        switch(instr->instruction) {
            case OP_INC:
                increase(&c, (unsigned int)instr->arg_list[0]);
                break;
            case OP_DEC:
                decrease(&c, (unsigned int)instr->arg_list[0]);
                break;
            case OP_JZ:
                jump_if_zero(&c, (unsigned int)instr->arg_list[0]);
                break;
            case OP_JMP:
                jump(&c);
                break;
        }
    }
    
    reset_stack(&c);
    ret(&c);
    
    return c.byte_code;
}

unsigned int start_native(URMVM* vm, URMProgram* program, unsigned int** registers, unsigned int* n) {
    char* instructions = compile_x86(vm, program);

    asm("PUSHL %0" : : "r"(program->registers) );
    asm("CALL %0" : : "r"(instructions) );

    free(instructions);
    *n = vm->number_of_registers;
    *registers = (unsigned int*)realloc(*registers, sizeof(unsigned int) * (*n));
    memcpy(*registers, vm->registers, sizeof(unsigned int) * (*n));
    return 1;
}
