/*Added missing definitions and removed initial fragmented code*/
#include "strtab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Added missing symbol table storage, error counter, and labels for printing entries. */
struct strEntry strTable[MAXIDS];
int semanticErrorCount = 0;
static const char *dataTypeStr[] = {"int", "char", "void"};
static const char *symbolTypeStr[] = {"", "[]", "()"};

/* Added the missing hash helper to choose a table slot using the identifier and scope. */
static unsigned symbolHash(const char *id, const char *scope) {
    unsigned long hash = 5381;
    while (*scope) hash = hash * 33 + (unsigned char)*scope++;
    while (*id) hash = hash * 33 + (unsigned char)*id++;
    return (unsigned)(hash % MAXIDS);
}

/* Restored the lookup function to find identifiers in the specified scope and handle hash collisions. */
int ST_lookup(char *id, char *scope) {
    if (!id || !scope) return -1;
    unsigned index = symbolHash(id, scope);
    for (int i = 0; i < MAXIDS; i++, index = (index + 1) % MAXIDS) {
        if (!strTable[index].id) return -1;
        if (!strcmp(strTable[index].id, id) && !strcmp(strTable[index].scope, scope)) return (int)index;
    }
    return -1;
}

/* Changed to reject same-scope duplicates and initialize array_size to -1 for new symbols. */
int ST_insert(char *id, char *scope, int data_type, int symbol_type) {
    if (ST_lookup(id, scope) != -1) return -1;
    unsigned index = symbolHash(id, scope);
    for (int i = 0; i < MAXIDS; i++, index = (index + 1) % MAXIDS) {
        if (!strTable[index].id) {
            strTable[index].id = strdup(id); strTable[index].scope = strdup(scope);
            strTable[index].data_type = data_type; strTable[index].symbol_type = symbol_type;
            strTable[index].array_size = -1; return (int)index;
        }
    }
    fprintf(stderr, "symbol table full\n"); exit(EXIT_FAILURE);
}
const char *get_symbol_id(int index) {
    return index >= 0 && index < MAXIDS && strTable[index].id ? strTable[index].id : "unknown";
}
void print_sym_tab(void) {
    for (int i = 0; i < MAXIDS; i++) if (strTable[i].id) output_entry(i);
}
/* Phase 3: Search the function-local scope first, then global scope.
   Keep ST_lookup unchanged because declaration checking needs exact scope.
  */
int ST_lookupVisible(const char *id, const char *scope){
  if(id == NULL) return -1;

  if(scope != NULL && scope[0] != '\0'){
    int local = ST_lookup((char *)id, (char *)scope);
    if(local != -1) return local;
  }

  return ST_lookup((char *)id, "");
}

/* Phase 3: Store a declared array size (array parameters have no size). */
int ST_setArraySize(int entry_index, int array_size){
  if(entry_index < 0 || entry_index >= MAXIDS ||
     strTable[entry_index].id == NULL ||
     strTable[entry_index].symbol_type != ARRAY)
    return -1;

  if(strTable[entry_index].array_size != -1) return -1;

  strTable[entry_index].array_size = array_size;
  return 0;
}

/* Phase 3: Append a parameter's type to a function signature. */
int ST_addParameter(const char *function_name, int data_type, int symbol_type){
  if(function_name == NULL ||
     (symbol_type != SCALAR && symbol_type != ARRAY))
    return -1;

  int index = ST_lookup((char *)function_name, "");
  if(index == -1 || strTable[index].symbol_type != FUNCTION)
    return -1;

  struct strEntry *entry = &strTable[index];
  if(entry->param_count == entry->param_capacity){
    int new_capacity = entry->param_capacity ? entry->param_capacity * 2 : 4;
    struct paramInfo *grown = realloc(entry->params,
                                (size_t)new_capacity * sizeof(*grown));
    if(grown == NULL){
      perror("Failed to allocate function parameter types");
      exit(EXIT_FAILURE);
    }
    entry->params = grown;
    entry->param_capacity = new_capacity;
  }

  entry->params[entry->param_count].data_type = data_type;
  entry->params[entry->param_count].symbol_type = symbol_type;
  entry->param_count++;
  return 0;
}

void output_entry(int i){
  /* Phase 3: Print array sizes and function parameter signatures. */
  if(i < 0 || i >= MAXIDS || strTable[i].id == NULL) return;

  printf("%d: %s ", i, dataTypeStr[strTable[i].data_type]);
  printf("%s:%s", strTable[i].scope, strTable[i].id);

  if(strTable[i].symbol_type == ARRAY){
    if(strTable[i].array_size >= 0)
      printf("[%d]", strTable[i].array_size);
    else
      printf("%s", symbolTypeStr[ARRAY]);
  }
  else if(strTable[i].symbol_type == FUNCTION){
    printf("(");
    for(int p = 0; p < strTable[i].param_count; p++){
      if(p > 0) printf(", ");
      printf("%s", dataTypeStr[strTable[i].params[p].data_type]);
      if(strTable[i].params[p].symbol_type == ARRAY)
        printf("%s", symbolTypeStr[ARRAY]);
    }
    printf(")");
  }
  else{
    printf("%s", symbolTypeStr[strTable[i].symbol_type]);
  }
  printf("\n");
}
