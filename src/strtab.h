#ifndef STRTAB_H
#define STRTAB_H
#define MAXIDS 1000

#include <stddef.h>   /* NULL */

enum dataType {INT_TYPE, CHAR_TYPE, VOID_TYPE};
enum symbolType {SCALAR, ARRAY, FUNCTION};

typedef struct param{
    int data_type;
    int symbol_type;
    struct param* next;
} param;

typedef struct strEntry{
    char* id;
    char* scope;
    int   data_type;
    int   symbol_type;
    int   size; //Num elements if array, num params if function
    param*  params;
} symEntry;

/* You should use a linear linklist to keep track of all parameters passed to a function. The working_list_head should point to the beginning of the linklist and working_list_end should point to the end. Whenever a parameter is passed to a function, that node should also be added in this list. */
/* Declared here, DEFINED once in strtab.c. A definition in a header would be
   repeated in every file that includes it, and the link would fail. */
extern param *working_list_head;
extern param *working_list_end;

typedef struct table_node{
    symEntry* strTable[MAXIDS];
    int numChildren;
    struct table_node* parent;
    struct table_node* first_child; // First subscope
    struct table_node* last_child;  // Most recently added subscope
    struct table_node* next; // Next subscope that shares the same parent
} table_node; // Describes each node in the symbol table tree and is used to implement a tree for the nested scope as discussed in lecture 13 and 14.

extern table_node* current_scope; // A global variable that should point to the symbol table node in the scope tree as discussed in lecture 13 and 14. Define it once, in strtab.c.



/* Inserts a symbol into the current symbol table tree. Please note that this function is used to insert into the tree of symbol tables and NOT the AST. Hash the id with djb2 to get a starting slot, then probe until we find an empty slot or the id.
   The arguments are in the same order as in Phase 2, so your Phase 2 calls still compile unchanged.
   Returns the symbol's index, which is unique for the whole run: store it in an identifier node's val, and pass it to connect_params. Returns -1 if the name is already declared in the current scope. */
int ST_insert(char *id, char *scope, int data_type, int symbol_type);

/* The function for looking up if a symbol exists in the current_scope. Always start looking for the symbol from the node that is being pointed to by the current_scope variable, then walk up to the parent scopes. Returns NULL if the symbol is not declared anywhere in scope. */
symEntry* ST_lookup(char *id);

/* The index ST_insert returned for this entry, or -1. Use it to fill in an identifier node's val. */
int ST_index(symEntry *e);

/* The identifier text for an index. printAst in tree.c calls this to label an identifier node. */
char* get_symbol_id(int index);

/* Prints the whole scope tree. driver.c calls this for the --sym flag. */
void print_sym_tab();

/* Creates a param* whenever formalDecl in the parser.y file declares a formal parameter. Please note that we are maining a separate linklist to keep track of all the formal declarations because until the function body is processed, we will not know the number of parameters in advance. Link list provides a way for the formalDecl to declare as many parameters as needed.*/
void add_param(int data_type, int symbol_type);

/*connect_params is called in parser.y right after the parameter list, before the funBody is processed. At this point, the parser has already seen all the formal parameter declaration and has built the entire list of parameters to the function, and attaching it now is what lets a recursive call inside the body see the right signature. This list is pointed to by the working_list_head pointer. The function's params field should end up pointing at the head of that list, and its size at num_params. Pass the index that ST_insert returned for the function. */
void connect_params(int i, int num_params);

// Creates a new scope within the current scope and sets that as the current scope.
void new_scope();

// Moves towards the root of the sym table tree.
void up_scope();

#endif
