#ifndef TREE_H
#define TREE_H

#define MAXCHILDREN 100

enum nodeKind { PROGRAM, DECLLIST, DECL, VARDECL, TYPESPEC, FUNDECL, FORMALDECLLIST, FORMALDECL, FUNBODY, LOCALDECLLIST, STATEMENTLIST, STATEMENT, COMPOUNDSTMT, ASSIGNSTMT, CONDSTMT, LOOPSTMT, RETURNSTMT, EXPRESSION, RELOP, ADDEXPR, ADDOP, TERM, MULOP, FACTOR, FUNCCALLEXPR, ARGLIST, INTEGER, IDENTIFIER, VAR, ARRAYDECL, CHAR, FUNCTYPENAME };
enum operatorKind { ADD, SUB, MUL, DIV, LT, LTE, EQ, GTE, GT, NEQ };

typedef struct treenode tree;

/* tree node - you may want to add more fields */
struct treenode {
      char *strval;
      int line;
      int nodeKind;
      int numChildren;
      int val;
      int scope; // Used for var/id. Index of the scope. This works b/c only global and local.
      int type;
      int sym_type; // Only used by var to distinguish SCALAR vs ARRAY
      tree *parent;
      tree *children[MAXCHILDREN];
};

extern tree *ast; /* pointer to AST root, defined in tree.c */

/* builds sub tree with zeor children  */
tree *maketree(int kind);

/* builds sub tree with leaf node */
tree *maketreeWithVal(int kind, int val);
tree *maketreeWithStrVal(int kind, const char *value);

void addChild(tree *parent, tree *child);

void printAst(tree *root, int nestLevel);

/* Phase 3: Traverse the AST to detect undeclared variables. */
void checkUndeclaredVars(struct treenode *root, const char *scope);

/* Adds all children of sublist to list */
void flattenList(tree *list, tree *subList);

/* tree manipulation macros */
/* if you are writing your compiler in C, you would want to have a large collection of these */

#define nextAvailChild(node) node->children[node->numChildren]
#define getChild(node, index) node->children[index]

#endif
