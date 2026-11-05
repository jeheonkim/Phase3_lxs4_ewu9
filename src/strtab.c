#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include "strtab.h"

const char *dataTypeStr[3] = {"int", "char", "void"};
const char *symbolTypeStr[3] = {"", "[]", "()"};

/* The symbolTable, which will be implemented as a hash table
  */
struct strEntry strTable[MAXIDS];

/* Provided is a hash function that you may call to get an integer back. */
int hash(unsigned char *str) {
  unsigned long hash = 5381;
  int c;
  while ((c = *str++)) {
    hash += (hash << 5) + c;
  }
  return hash % MAXIDS; /* MAXIDS defined in strtab.h */
}

/* Create our own copy since scanner text is reused for the next token */

static char *copyString(const char *text){
  char *copy = malloc(strlen(text)+1);
  if(copy == NULL){
    perror("Failed to allocate symbol-table string");
    exit(EXIT_FAILURE);
  }
  strcpy(copy,text);
  return copy;

}

static int symbolHash(char *id, char *scope){
  char *key = malloc(strlen(scope)+ strlen(id)+1);
  if(key == NULL){
    perror("Failed to allocate symbol-table key");
    exit (EXIT_FAILURE);
  }
  strcpy(key,scope);
  strcat(key,id);
  int index = hash((unsigned char *)key);
  free(key);
  return index;
}



int ST_insert(char *id, char *scope, int data_type, int symbol_type){

  int index = ST_lookup(id, scope);
  if(index != -1){
    return index;
  }

  index = symbolHash(id,scope);
  for(int checked = 0; checked < MAXIDS; checked++){
    if(strTable[index].id ==NULL){
      strTable[index].id = copyString(id);
      strTable[index].scope = copyString(scope);
      strTable[index].data_type = data_type;
      strTable[index].symbol_type = symbol_type;
      return index;
    }
    index = (index+1) % MAXIDS;
  }
  fprintf(stderr,"Error: symbol table is full\n");
  exit(EXIT_FAILURE);

  /* TODO: Use ST_lookup to check if the id is already in the symbol table.
    If yes, ST_lookup will return an index that is not -1.
    if index != -1, that means the variable is already in the hashtable.
    Hence, no need to insert that variable again.
    However, if index == -1,
      then use linear probing to find an empty spot and insert there.
    Then return that index.
    */
}

int ST_lookup(char *id, char *scope) {
  int index = symbolHash(id,scope);
  for(int checked = 0; checked<MAXIDS; checked++){
    if(strTable[index].id == NULL){
      return -1;
    }
    if(strcmp(strTable[index].id,id) ==0 && strcmp(strTable[index].scope,scope)==0){
      return index;
    }
    index = (index+1) % MAXIDS;
  }

  /* TODO: Use the hash value to check if the index position has the "id".
    If not, keep looking for id until you find an empty spot.
    If you find "id", return that index.
    If you arrive at an empty spot, that means "id" is not there.
    Then return -1. 
    */

  return -1;
}

void output_entry(int i){
  printf("%d: %s ", i, dataTypeStr[strTable[i].data_type]);
  printf("%s:%s%s\n",
    strTable[i].scope, strTable[i].id, symbolTypeStr[strTable[i].symbol_type]);
}
