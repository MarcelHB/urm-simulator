#include <stdio.h>
#include <stdlib.h>

#include "urm_vm.h"
#include "urm_program.h"

int main() {
    unsigned int initial_values[4] = { 0, 0, 500, 600 };
    URMVM *vm = new_vm();
    URMProgram *program = preconfigure_program_loop((unsigned int*)&initial_values, 4, 1);
    unsigned int results = 0;
    unsigned int *result_registers = NULL;
    FILE *file = fopen("misc/program.txt", "r");
    
    if(file == NULL) {
        printf("Unable to open file!\n");
    }

    parse(program, file);
#if 0
    unsigned int i = 0;
    for(; i < program->instructions; ++i) {
        printf("instruction %u: %d\n", i, program->instruction_list[i]->instruction);
        unsigned int j = 0;
        for(; j < program->instruction_list[i]->args; ++j) {
            printf("arg %u: %d\n", j, program->instruction_list[i]->arg_list[j]);
        }
    }
    
    for(i = 0; i < program->errors; ++i) {
        printf("error: %s\n", program->error_list[i]);
    }
#endif
    if(start_program(vm, program, &result_registers, &results)) {
        printf("Results:\n");
        int i = 0;
        for(; i < results; ++i) {
            printf ("Register %u, result %u\n", i, result_registers[i]);
        }
    } else {
        printf("Error in execution!\n");
    }

    fclose(file);
    free(result_registers);
    free_program(program);
    free(program);
    free_vm(vm);
    free(vm);

    return 0;
}
