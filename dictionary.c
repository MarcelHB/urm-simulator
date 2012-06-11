#include "dictionary.h"

// move to AVR?

//-----------------------------------------------------------------------------
void dictionary_insert(DictNode *root, void *key, void *value, int (*locator)(void*, void*)) {
    if(locator(root->key, key) >= 0) {
        if(root->left == NULL) {
            root->left = (DictNode*)malloc(sizeof(DictNode));
            *(root->left) = (DictNode) { 
                key,
                value,
                NULL,
                NULL
            };
        } else {
            dictionary_insert(root->left, key, value, locator);
        }
    } else {
        if(root->right == NULL) {
            root->right = (DictNode*)malloc(sizeof(DictNode));
            *(root->right) = (DictNode) { 
                key,
                value,
                NULL,
                NULL
            };
        } else {
            dictionary_insert(root->right, key, value, locator);
        }
    }
}

//-----------------------------------------------------------------------------
void* dictionary_find(DictNode *root, void *key, int (*locator)(void*, void*)) {
    if(locator(root->key, key) == 0) {
        return root->value;
    } else if(root->key, key) > 0) {
        if(root->left != NULL) {
            return dictionary_find(root->left, key, locator);
        } else {
            return NULL;
        }
    } else if(root->key, key) < 0) {
        if(root->right != NULL) {
            return dictionary_find(root->right, key, locator);
        } else {
            return NULL;
        }
    }
}

//-----------------------------------------------------------------------------
void dictionary_free(DictNode *root) {
    if(root->left != NULL) {
        dictionary_free(root->left);
    }
    if(root->right != NULL) {
        dictionary_free(root->right);
    }
   
    free(root->key);
    free(root->value);
    free(root);
}
