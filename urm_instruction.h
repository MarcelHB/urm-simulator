#ifndef _H_URM_INSTRUCTIONS
#define _H_URM_INSTRUCTIONS

enum URMInstructionSymbol { OP_HALT, OP_JMP, OP_JZ, OP_INC, OP_DEC };

typedef struct URMInstruction {
    enum URMInstructionSymbol instruction;
    unsigned int args;
    int* arg_list;
} URMInstruction;

#endif
