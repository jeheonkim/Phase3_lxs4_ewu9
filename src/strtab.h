#ifndef STRTAB_H
#define STRTAB_H
#define MAXIDS 1000

/* These enums are used in the parser.y file
  when creating nodes in the AST corresponding to the 'typeSpecifier' tokens
  */
enum dataType {INT_TYPE=0, CHAR_TYPE, VOID_TYPE};

/* These nums are passed as the last argument to ST_insert
    when inserting information about
    variable names, array names, and function names into the symbol table
  */
enum symbolType {SCALAR=0, ARRAY, FUNCTION};

/* Phase 3: A function parameter needs both its data type and its symbol type
   (SCALAR or ARRAY) to check function calls.
  */
struct paramInfo {
    int data_type;
    int symbol_type;
};

/* This data structure describes each element of the symbol table
  */
struct strEntry{
    char* id;
    char* scope;
    int   data_type;
    int   symbol_type;

    /* Phase 3: Additional information for arrays and functions. */
    int   array_size;      /* -1 for nonarrays or unsized array parameters */
    int   param_count;     /* number of function parameters */
    int   param_capacity;  /* allocated capacity of params */
    struct paramInfo *params;  /* parameter types for functions */
};


/* Phase 3: Allow semantic analysis to access the symbol table and error count. */
extern struct strEntry strTable[MAXIDS];
extern int semanticErrorCount;

/* id is a lexeme, scope is the scope of the symbol table,
    data_type is the data type of the lexeme,
    and symbol_type is one of the elements of symbolType declared in strtab.h.
  ST_insert should be called from the parser.y file
    whenever a scalar, array, or function is declared.
  Note that these types are declared above in symbolType enum.
  Hint: refer to the production rules varDecl and formalDecl.
  If you remove left recursion or apply left factoring,
    you may need to call ST_insert in other places as well.
  */
int ST_insert(char *id, char *scope, int data_type, int symbol_type);


/* ST_lookup should be called from the parser.y file
    whenever a reference to variable (id or array) or function call is made.
  Hint: refer to the production rules VAR and funcCallExpr.
  */
int ST_lookup(char *id, char *scope);

/* Phase 3: Look for an identifier in the current function scope first,
   then in global scope if no local declaration exists.
  */
int ST_lookupVisible(const char *id, const char *scope);

/* Phase 3: Store the declared size of an array symbol-table entry. */
int ST_setArraySize(int entry_index, int array_size);

/* Phase 3: Append a parameter type to a function's signature. */
int ST_addParameter(const char *function_name, int data_type, int symbol_type);

/* Print the i-th symbol table entry. You may not need this function. */
void output_entry(int i);

#endif
