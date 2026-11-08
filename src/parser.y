%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<../src/tree.h>
#include<../src/strtab.h>

extern int yylineno;
extern int yylex(void);

int yywarning(char *msg);
int yyerror(char *msg);


typedef struct treenode tree;
extern tree *ast;

/* nodeTypes refer to different types of internal and external nodes
  that can be part of the abstract syntax tree.
  */


/* NOTE: mC has two kinds of scopes for variables : local and global.
  Variables declared outside any function are considered globals,
    whereas variables (and parameters) declared inside a function foo
    are local to foo.
  You should update the scope variable whenever you are inside a production
    that matches function definition (funDecl production).
  The rationale is that you are entering that function, so all variables,
    arrays, and other functions should be within this scope.
  You should pass this variable whenever you are
    calling the ST_insert or ST_lookup functions.
  This variable should be updated to scope = ""
    to indicate global scope whenever funDecl finishes.
  Treat these hints as helpful directions only.
  You may implement all of the functions as you like
    and not adhere to my instructions.
  As long as the directory structure is correct and the file names are correct,
    we are okay with it.
  */
char* scope = "";
static int valid_function = 0;
static int duplicate_scope = 0;

/*
 * Adds an identifier to the symbol table in the current scope.
 * Reports an error if ST_insert returns a negative value.
 * Returns the symbol table index, or the negative value on failure.
 */
static void diagnostic(const char *message) { printf("error: line %d: %s\n", yylineno, message); }
static int declare_symbol(char *id, int type, int kind) {
    int i = ST_insert(id, scope, type, kind);
    if (i < 0) diagnostic("Symbol declared multiple times.");
    return i;
}
/* -1 means an earlier error; -2 is a mixed expression. */
static int expr_type(tree *n) {
    if (!n) return -1;
    if (n->nodeKind == INTEGER) return INT_TYPE;
    if (n->nodeKind == CHAR) return CHAR_TYPE;
    if (n->nodeKind == VAR || n->nodeKind == FUNCCALLEXPR) {
        int i = n->val; return i < 0 ? -1 : strTable[i].data_type;
    }
    if (n->numChildren == 1) return expr_type(n->children[0]);
    if (n->numChildren == 3) {
        int a=expr_type(n->children[0]), b=expr_type(n->children[2]);
        if (a == -1 || b == -1) return -1;
        return a == b && a != VOID_TYPE ? a : -2;
    }
    return -1;
}
static int expression_shape(tree *n) {
    while (n && n->numChildren == 1 && n->nodeKind != VAR && n->nodeKind != FUNCCALLEXPR) n=n->children[0];
    return n && n->nodeKind == VAR && n->numChildren == 1 && n->val >= 0 && strTable[n->val].symbol_type == ARRAY ? ARRAY : SCALAR;
}

/*
 * Recursively evaluates integer constant expressions in the AST.
 * Stores the result in *out and returns 1 if successful.
 * Returns 0 if the expression cannot be evaluated, uses an
 * unsupported operation, or attempts to divide by zero.
 */
static int constant_value(tree *n, long long *out) {
    if (!n) return 0;
    if (n->nodeKind == INTEGER) { *out=n->val; return 1; }
    if (n->numChildren == 1) return constant_value(n->children[0],out);
    if (n->numChildren == 3 && (n->nodeKind == ADDEXPR || n->nodeKind == TERM)) {
        long long a,b; if (!constant_value(n->children[0],&a) || !constant_value(n->children[2],&b)) return 0;
        switch (n->children[1]->val) {
        case ADD: *out=a+b; break; case SUB: *out=a-b; break;
        case MUL: *out=a*b; break; case DIV: if (!b) return 0; *out=a/b; break; default: return 0;
        } return 1;
    } return 0;
}

/*
 * Recursively walks the argument list and counts arguments using *position.
 * Sets *bad to 1 when an argument's known data type does not match
 * the corresponding function parameter's data type.
 */
static void check_args(tree *args, struct strEntry *fn, int *position, int *bad) {
    if (!args) return;
    if (args->nodeKind == ARGLIST) { for(int i=0;i<args->numChildren;i++) check_args(args->children[i],fn,position,bad); return; }
    int p=(*position)++; int t=expr_type(args);
    if (p < fn->param_count && t != -1 && (t != fn->params[p].data_type)) *bad=1;
}

/*
 * Looks up the function and stores its symbol table index in the node.
 * Reports an error if the name does not refer to a declared function
 * or if the argument count or types do not match its parameters.
 */
static void check_call(tree *node, tree *args, const char *name) {
    int i=ST_lookupVisible(name,scope); node->val=i;
    if (i < 0 || strTable[i].symbol_type != FUNCTION) { diagnostic("Undefined function"); node->val=-1; return; }
    int count=0,bad=0; check_args(args,&strTable[i],&count,&bad);
    if(count < strTable[i].param_count) diagnostic("Too few arguments provided in function call.");
    else if(count > strTable[i].param_count) diagnostic("Too many arguments provided in function call.");
    else if(bad) diagnostic("Argument type mismatch in function call.");
}

/* Resolves a variable and checks array indexing, index types, and constant bounds. */
static void check_var(tree *node, const char *name, tree *index) {
    int i=ST_lookupVisible(name,scope); node->val=i;
    if(i < 0 || strTable[i].symbol_type == FUNCTION) { diagnostic("Undeclared variable"); node->val=-1; return; }
    if(index) {
        if(strTable[i].symbol_type != ARRAY) diagnostic("Non-array identifier used as an array.");
        else { int t=expr_type(index); long long v;
            if(t != -1 && t != INT_TYPE) diagnostic("Array indexed using non-integer expression.");
            else if(t == INT_TYPE && strTable[i].array_size >= 0 && constant_value(index,&v) && (v < 0 || v >= strTable[i].array_size)) diagnostic("Statically sized array indexed with constant, out-of-bounds expression.");
        }
    }
}
%}

/* the union describes the fields available in the yylval variable */
%union
{
    int value;
    struct treenode *node;
    char *strval;
}
%locations

/*Add token declarations below.
  The type <value> indicates that the associated token will be
    of a value type such as integer, float etc.,
    and <strval> indicates that the associated token will be of string type.
  */
%token <strval> ID
%token <value> INTCONST CHARCONST
%token STRCONST

%token KWD_IF KWD_ELSE KWD_WHILE
%token KWD_INT KWD_CHAR KWD_VOID KWD_RETURN

%token OPER_ADD OPER_SUB OPER_MUL OPER_DIV
%token OPER_LT OPER_LTE OPER_GT OPER_GTE
%token OPER_EQ OPER_NEQ OPER_ASGN

%token LSQ_BRKT RSQ_BRKT
%token LCRLY_BRKT RCRLY_BRKT
%token LPAREN RPAREN
%token COMMA SEMICLN

%token KWD_STRING
%token OPER_MOD OPER_AT OPER_INC OPER_DEC
%token OPER_AND OPER_OR OPER_NOT

/* Declares the error tokens returned by the scanner. */
%token ERROR ILLEGAL_TOK


/* TODO: Declare non-terminal symbols as of type node.
  Provided below is one example.
  node is defined as 'struct treenode *node' in the above union data structure.
  This declaration indicates to parser that these non-terminal variables
    will be implemented using a 'treenode *' type data structure.
  Hence, the circles you draw when drawing a parse tree,
    the following lines are telling yacc that these
    will eventually become circles in an AST.
  This is one of the connections between the AST you draw by hand
    and how yacc implements code to concretize that.
  We provide with two examples:
    program and declList from the grammar. Make sure to add the rest.
  */

%type <node> program declList decl
%type <node> varDecl typeSpecifier funDecl
%type <node> formalDeclList formalDecl funBody
%type <node> statementList statement compoundStmt
%type <node> assignStmt condStmt loopStmt returnStmt
%type <node> var expression relop addExpr addop
%type <node> term mulop factor funCallExpr argList
%type <node> funcTypeName

/* Later declarations have higher precedence.
   Prefer attaching else to the nearest unmatched if. */
%nonassoc IF_WITHOUT_ELSE
%nonassoc KWD_ELSE



%start program

%%
/* TODO: Your grammar and semantic actions go here.
  We provide with two example productions
    and their associated code for adding non-terminals to the AST.
  */

program         : declList
                 {
                    tree *progNode = maketree(PROGRAM);
                    addChild(progNode, $1);
                    ast = progNode;
                 }
                ;

declList        : decl
                 {
                    tree* declListNode = maketree(DECLLIST);
                    addChild(declListNode, $1);
                    $$ = declListNode;
                 }
                | declList decl
                 {
                    tree* declListNode = maketree(DECLLIST);
                    addChild(declListNode, $1);
                    addChild(declListNode, $2);
                    $$ = declListNode;
                 }
                ;


decl            : varDecl
                 {
                    tree *declNode = maketree(DECL);
                    addChild(declNode, $1);
                    $$ = declNode;
                 }
                | funDecl
                 {
                    tree *declNode = maketree(DECL);
                    addChild(declNode, $1);
                    $$ = declNode;
                 }
                ;
varDecl         : typeSpecifier ID SEMICLN
                 {
                    tree *node = maketree(VARDECL);
                    addChild(node, $1);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $2));
                    declare_symbol($2, $1->val, SCALAR);
                    $$ = node;
                 }
                | typeSpecifier ID LSQ_BRKT INTCONST RSQ_BRKT SEMICLN
                 {
                    tree *node = maketree(VARDECL);
                    addChild(node, $1);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $2));
                    addChild(node, maketreeWithVal(INTEGER, $4));
                    int entry = declare_symbol($2, $1->val, ARRAY);
                    if ($4 == 0) diagnostic("Array variable declared with size of zero.");
                    ST_setArraySize(entry, $4);
                    $$ = node;
                 }
                ;
typeSpecifier    : KWD_INT
                  {
                     $$ = maketreeWithVal(TYPESPEC, 0);
                  }
                 | KWD_CHAR
                  {
                     $$ = maketreeWithVal(TYPESPEC, 1);
                  }
                 | KWD_VOID
                  {
                     $$ = maketreeWithVal(TYPESPEC, 2);
                  }
                 ;
funcTypeName    : typeSpecifier ID LPAREN
                 {
                    tree *node = maketree(FUNCTYPENAME);
                    tree *nameNode =
                        maketreeWithStrVal(IDENTIFIER, $2);

                    /* Store the function's type and name together. */
                    addChild(node, $1);
                    addChild(node, nameNode);

                    /* Register the function in global scope. */
                    int function_index = declare_symbol($2, $1->val, FUNCTION);
                    valid_function = function_index >= 0;

                    /* A duplicate function gets an isolated local scope. */
                    if (valid_function) scope = nameNode->strval;
                    else {
                        char temp[64];
                        snprintf(temp, sizeof(temp), "#duplicate%d", ++duplicate_scope);
                        scope = strdup(temp);
                    }

                    $$ = node;
                 }
                ;
funDecl         : funcTypeName formalDeclList RPAREN funBody
                 {
                    tree *node = maketree(FUNDECL);
                    addChild(node, $1);
                    addChild(node, $2);
                    addChild(node, $4);


                    scope = "";
                    $$ = node;
                 }
                | funcTypeName RPAREN funBody
                 {
                    tree *node = maketree(FUNDECL);
                    addChild(node, $1);
                    addChild(node, $3);


                    scope = "";
                    $$ = node;
                 }
                ;
formalDeclList  : formalDecl
                 {
                    tree *node = maketree(FORMALDECLLIST);
                    addChild(node, $1);
                    $$ = node;
                 }
                | formalDecl COMMA formalDeclList
                 {
                    tree *node = maketree(FORMALDECLLIST);
                    addChild(node, $1);
                    addChild(node, $3);
                    $$ = node;
                 }
                ;
formalDecl      : typeSpecifier ID
                 {
                    tree *node = maketree(FORMALDECL);
                    addChild(node, $1);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $2));
                    declare_symbol($2, $1->val, SCALAR);
                    if (valid_function) ST_addParameter(scope, $1->val, SCALAR);
                    $$ = node;
                 }
                | typeSpecifier ID LSQ_BRKT RSQ_BRKT
                 {
                    tree *node = maketree(FORMALDECL);
                    addChild(node, $1);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $2));
                    declare_symbol($2, $1->val, ARRAY);
                    if (valid_function) ST_addParameter(scope, $1->val, ARRAY);
                    $$ = node;
                 }
                ;
funBody         : LCRLY_BRKT statementList RCRLY_BRKT
                 {
                    tree *node = maketree(FUNBODY);
                    addChild(node, $2);
                    $$ = node;
                 }
                ;
statementList   : /* empty */
                 {
                    $$ = maketree(STATEMENTLIST);
                 }
                | statement statementList
                 {
                    tree *node = maketree(STATEMENTLIST);
                    addChild(node, $1);
                    addChild(node, $2);
                    $$ = node;
                 }
                ;
statement       : SEMICLN
                 {
                    $$ = maketree(STATEMENT);
                 }
                | varDecl
                 {
                    tree *node = maketree(STATEMENT);
                    addChild(node, $1);
                    $$ = node;
                 }
                | compoundStmt
                 {
                    tree *node = maketree(STATEMENT);
                    addChild(node, $1);
                    $$ = node;
                 }
                | assignStmt
                 {
                    tree *node = maketree(STATEMENT);
                    addChild(node, $1);
                    $$ = node;
                 }
                | condStmt
                 {
                    tree *node = maketree(STATEMENT);
                    addChild(node, $1);
                    $$ = node;
                 }
                | loopStmt
                 {
                    tree *node = maketree(STATEMENT);
                    addChild(node, $1);
                    $$ = node;
                 }
                | returnStmt
                 {
                    tree *node = maketree(STATEMENT);
                    addChild(node, $1);
                    $$ = node;
                 }
                ;

compoundStmt   : LCRLY_BRKT statementList RCRLY_BRKT
                 {
                    tree *node = maketree(COMPOUNDSTMT);
                    addChild(node, $2);
                    $$ = node;
                 }
                ;

assignStmt     : var OPER_ASGN expression SEMICLN
                 {
                    tree *node = maketree(ASSIGNSTMT);
                    addChild(node, $1);
                    addChild(node, $3);
                    int lhs = expr_type($1), rhs = expr_type($3);
                    if (lhs != -1 && rhs != -1 && (lhs != rhs || expression_shape($1) != expression_shape($3)))
                        diagnostic("Type mismatch in assignment.");
                    $$ = node;
                 }
                | expression SEMICLN
                 {
                    tree *node = maketree(ASSIGNSTMT);
                    addChild(node, $1);
                    $$ = node;
                 }
                ;

condStmt       : KWD_IF LPAREN expression RPAREN statement %prec IF_WITHOUT_ELSE
                 {
                    tree *node = maketree(CONDSTMT);
                    addChild(node, $3);
                    addChild(node, $5);
                    $$ = node;
                 }
                | KWD_IF LPAREN expression RPAREN statement KWD_ELSE statement
                 {
                    tree *node = maketree(CONDSTMT);
                    addChild(node, $3);
                    addChild(node, $5);
                    addChild(node, $7);
                    $$ = node;
                 }
                ;

loopStmt       : KWD_WHILE LPAREN expression RPAREN statement
                 {
                    tree *node = maketree(LOOPSTMT);
                    addChild(node, $3);
                    addChild(node, $5);
                    $$ = node;
                 }
                ;

returnStmt     : KWD_RETURN SEMICLN
                 {
                    $$ = maketree(RETURNSTMT);
                 }
                | KWD_RETURN expression SEMICLN
                 {
                    tree *node = maketree(RETURNSTMT);
                    addChild(node, $2);
                    $$ = node;
                 }
                ;

var            : ID
                 {
                    tree *node = maketree(VAR);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $1));
                    check_var(node, $1, NULL);
                    $$ = node;
                 }
                | ID LSQ_BRKT addExpr RSQ_BRKT
                 {
                    tree *node = maketree(VAR);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $1));
                    addChild(node, $3);
                    check_var(node, $1, $3);
                    $$ = node;
                 }
                ;

expression     : addExpr
                 {
                    tree *node = maketree(EXPRESSION);
                    addChild(node, $1);
                    $$ = node;
                 }
                | expression relop addExpr
                 {
                    tree *node = maketree(EXPRESSION);
                    addChild(node, $1);
                    addChild(node, $2);
                    addChild(node, $3);
                    $$ = node;
                 }
                ;

relop          : OPER_LTE
                 {
                    $$ = maketreeWithVal(RELOP, LTE);
                 }
                | OPER_LT
                 {
                    $$ = maketreeWithVal(RELOP, LT);
                 }
                | OPER_GT
                 {
                    $$ = maketreeWithVal(RELOP, GT);
                 }
                | OPER_GTE
                 {
                    $$ = maketreeWithVal(RELOP, GTE);
                 }
                | OPER_EQ
                 {
                    $$ = maketreeWithVal(RELOP, EQ);
                 }
                | OPER_NEQ
                 {
                    $$ = maketreeWithVal(RELOP, NEQ);
                 }
                ;

addExpr        : term
                 {
                    tree *node = maketree(ADDEXPR);
                    addChild(node, $1);
                    $$ = node;
                 }
                | addExpr addop term
                 {
                    tree *node = maketree(ADDEXPR);
                    addChild(node, $1);
                    addChild(node, $2);
                    addChild(node, $3);
                    $$ = node;
                 }
                ;

addop          : OPER_ADD
                 {
                    $$ = maketreeWithVal(ADDOP, ADD);
                 }
                | OPER_SUB
                 {
                    $$ = maketreeWithVal(ADDOP, SUB);
                 }
                ;

term           : factor
                 {
                    tree *node = maketree(TERM);
                    addChild(node, $1);
                    $$ = node;
                 }
                | term mulop factor
                 {
                    tree *node = maketree(TERM);
                    addChild(node, $1);
                    addChild(node, $2);
                    addChild(node, $3);
                    $$ = node;
                 }
                ;

mulop          : OPER_MUL
                 {
                    $$ = maketreeWithVal(MULOP, MUL);
                 }
                | OPER_DIV
                 {
                    $$ = maketreeWithVal(MULOP, DIV);
                 }
                ;

factor         : LPAREN expression RPAREN
                 {
                    tree *node = maketree(FACTOR);
                    addChild(node, $2);
                    $$ = node;
                 }
                | var
                 {
                    tree *node = maketree(FACTOR);
                    addChild(node, $1);
                    $$ = node;
                 }
                | funCallExpr
                 {
                    tree *node = maketree(FACTOR);
                    addChild(node, $1);
                    $$ = node;
                 }
                | INTCONST
                 {
                    tree *node = maketree(FACTOR);
                    addChild(node, maketreeWithVal(INTEGER, $1));
                    $$ = node;
                 }
                | CHARCONST
                 {
                    tree *node = maketree(FACTOR);
                    addChild(node, maketreeWithVal(CHAR, $1));
                    $$ = node;
                 }
                ;

funCallExpr    : ID LPAREN argList RPAREN
                 {
                    tree *node = maketree(FUNCCALLEXPR);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $1));
                    addChild(node, $3);
                    check_call(node, $3, $1);
                    $$ = node;
                 }
                | ID LPAREN RPAREN
                 {
                    tree *node = maketree(FUNCCALLEXPR);
                    addChild(node, maketreeWithStrVal(IDENTIFIER, $1));
                    check_call(node, NULL, $1);
                    $$ = node;
                 }
                ;

argList        : expression
                 {
                    tree *node = maketree(ARGLIST);
                    addChild(node, $1);
                    $$ = node;
                 }
                | argList COMMA expression
                 {
                    tree *node = maketree(ARGLIST);
                    addChild(node, $1);
                    addChild(node, $3);
                    $$ = node;
                 }
                ;
%%
int yywarning(char *msg){
  printf("warning: line %d: %s\n", yylineno, msg);
  return 0;
}

int yyerror(char * msg){
  printf("error: line %d: %s\n", yylineno, msg);
  return 0;
}
