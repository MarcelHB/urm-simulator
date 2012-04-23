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

void decrease(Compilation* c, const unsigned int reg) {
    // TODO: handle offsets > 255
    // TODO: handle iterator if reg in ECX!!
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

void jump_if_zero(Compilation* c, const unsigned int reg) {
    // TODO: Backup superior counter!
    // TODO: handle long jumps
    char b[] = { 0x8B, 0x44, 0x24, 0x08,                        // MOV EAX, [ESP+8]
                 0x83, 0xC0, reg * sizeof(unsigned int),        // ADD EAX, reg * 4
                 0x8B, 0xC8,                                    // MOV ECX, EAX
                 0x85, 0xC9,                                    // TEST ECX, ECX <-- need to jump back here
                 0x74, 0x00                                     // JZ (to be determined before JUMP)
    };
    push_bytes(c, (char*)&b, sizeof(b));
}

void jump(Compilation* c) {
    // TODO: find jump target
    // TODO: handle long jumps
    char b[] = { 0xEB, 0x00 };                                  // JMP (back to TEST)
    // TODO: Restore superior counter!
    push_bytes(c, (char*)&b, sizeof(b));
}

char* compile_x86(URMVM* vm, URMProgram* program) {
    Compilation c = { NULL, 0, 0 };
    
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
    
    asm("PUSHL %0" : : "r"(program->registers) : );
    asm("CALL %0" : : "r"(instructions) : );

    free(instructions);
    *n = vm->number_of_registers;
    *registers = (unsigned int*)realloc(*registers, sizeof(unsigned int) * (*n));
    memcpy(*registers, vm->registers, sizeof(unsigned int) * (*n));
    return 1;
}
