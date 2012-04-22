#include <stdio.h>

#include "urm_vm.h"
#include "urm_program.h"

int main() {
    unsigned int initial_values[4] = { 0, 0, 500, 600 };
    URMVM vm;
    URMProgram* program = preconfigure_program((unsigned int*)&initial_values, 4);
    unsigned int results = 0;
    unsigned int* result_registers = NULL;
    FILE* file = fopen("program.txt", "r");
    
    if(file == NULL) {
        printf("Unable to open file!\n");
    }

    parse(program, file);
#if 1
    unsigned int i = 0;
    for(; i < program->instructions; ++i) {
        printf("instruction %u: %d\n", i, program->instruction_list[i].instruction);
        unsigned int j = 0;
        for(; j < program->instruction_list[i].args; ++j) {
            printf("arg %u: %d\n", j, program->instruction_list[i].arg_list[j]);
        }
    }
#endif
    if(start_program(&vm, program, &result_registers, &results)) {
        printf("Results:\n");
        int i = 0;
        for(; i < results; ++i) {
            printf ("Register %u, result %u\n", i, result_registers[i]);
        }
    } else {
        printf("Error in execution!\n");
    }

    fclose(file);
    free_program(program);
    free_vm(&vm);

    return 0;
}
