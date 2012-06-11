#ifndef _H_DICTIONARY
#define _H_DICTIONARY

typedef struct DictNode {
    void* key;
    void* value;
    DictNode* left;
    DictNode* right;
} DictNode;

void dictionary_insert(DictNode*, void*, void*, int (*l)(void*,void*));
void* dictionary_find(DictNode*, void*, int (*l)(void*,void*));
void dictionary_free(DictNode*);

#endif
