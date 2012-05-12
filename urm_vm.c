#include <stdlib.h>
#include <string.h>

#include "urm_vm.h"
#include "urm_program.h"
#include "urm_x86.h"

void allocate(URMVM* vm, unsigned int index) {
    if(index >= vm->number_of_registers) {
        vm->registers = (unsigned int*)realloc(vm->registers, (index + 1) * sizeof(unsigned int));
        vm->number_of_registers = index + 1;
        vm->registers[index] = 0;
    }
}

void preallocate_registers(URMVM* vm, URMProgram* program, unsigned int* registers, unsigned int n) {
    int i = 0;
    allocate(vm, 0);
    for(; i < program->instructions; ++i) {
        URMInstruction* instr = program->instruction_list[i];

        switch(instr->instruction) {
            case OP_INC:
            case OP_DEC:
            case OP_JZ:
                allocate(vm, instr->arg_list[0]);
                break;
        }
    }

    unsigned int preallocations = vm->number_of_registers < n ? vm->number_of_registers : n;
    for(i = 0; i < preallocations; ++i) {
        vm->registers[i] = registers[i];
    }
}

unsigned int start_program(URMVM* vm, URMProgram* program, unsigned int** registers, unsigned int* n) {
    if(program->errors > 0) {
        return 0;
    }

    vm->registers = NULL;
    vm->number_of_registers = 0;
    vm->index = 0;
    vm->stopped = 0;
    preallocate_registers(vm, program, program->registers, program->number_of_registers);
    
    if(vm->native) {
        return start_native(vm, program, registers, n);
    }

    while(!vm->stopped) {
        URMInstruction* instr = program->instruction_list[vm->index];

        switch(instr->instruction) {
            case OP_INC:
                vm->registers[instr->arg_list[0]]++;
                break;
            case OP_DEC:
                if(vm->registers[instr->arg_list[0]] > 0) {
                    vm->registers[instr->arg_list[0]]--;
                }
                break;
            case OP_JZ:
                if(vm->registers[instr->arg_list[0]] == 0) {
                    vm->index += instr->arg_list[1];
                    continue;
                }
                break;
            case OP_JMP:
                vm->index += instr->arg_list[0];
                continue;
            case OP_HALT:
                vm->stopped = 1;
                break;
            default:
                return 0;
        }

        vm->index++;
    }

    *n = vm->number_of_registers;
    *registers = (unsigned int*)realloc(*registers, sizeof(unsigned int) * (*n));
    memcpy(*registers, vm->registers, sizeof(unsigned int) * (*n));
    return 1;
}

void free_vm(URMVM* vm) {
    if(vm->number_of_registers > 0 && vm->registers != NULL) {
        free(vm->registers);
        vm->registers = NULL;
    }
}

