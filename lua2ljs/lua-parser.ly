%name LuaParser

%token_type { LuaParserToken* }
//%token_type { char* }

//for each rule action with C code the destruction must be done
//on that C code because lemon do not generate the destructor for that
//%token_destructor {free($$);}
//%token_destructor {dummyFree($$);} //for debug

%include {

  #include <stdio.h>
  #include <string.h>
  #include <stdlib.h>
  #include <limits.h>
  #include <stdarg.h>
  #include <assert.h>
  #include "lua-parser.h"

  enum SepcialTokens {
    TK_SPACE = TK_LEMON_LAST_TOKEN,
    TK_COMMENT,
    TK_LONGCOMMENT,
    TK_THEEND
  };

  typedef struct LuaParserToken {
    int token_id;
    int space_before_size;
    int space_before_pos;
    int token_value_size;
    const char *token_value;
  } LuaParserToken;

 // void dummyFree(void *p) {assert(p);};

  typedef struct LuaParserState {
    const char *src;
    void **stack;
    int stack_size, stack_top;
  } LuaParserState;

  void initializeLuaParserState(LuaParserState *pState) {
    pState->src = NULL;
    pState->stack = NULL;
    pState->stack_size = 0;
    pState->stack_top = 0;
  }

  void resetLuaParserState(LuaParserState *pState) {
    for(int i=0; i < pState->stack_top; ++i) {
      LuaParserToken *tk = pState->stack[i];
      if(tk->token_value_size < 0) {
        free((void*)tk->token_value);
      }
      free(tk);
    }
    free(pState->stack);
    initializeLuaParserState(pState);
  }

  void pushLuaParserToken(LuaParserState *pState, LuaParserToken *tk) {
    int new_top = pState->stack_top + 1;
    if(new_top >= pState->stack_size) {
      size_t new_size = ((pState->stack_size) ? pState->stack_size * 2 : 32);
      void *new_stack = realloc(pState->stack, new_size * sizeof(void*));
      if(!new_stack) {
        printf("Failed to allocate memory of size = %d\n", (int) new_size);
        exit(1);
      }
      pState->stack = new_stack;
      pState->stack_size = new_size;
    }
    //printf("%d: %d : %.*s\n", pState->stack_top, tk->token_id, tk->token_value_size, pState->src + tk->token_value_pos);fflush(stdout);
    //printf("push = %d : %d\n", pState->stack_top, pState->stack_size);
    pState->stack[pState->stack_top++] = tk;
  }

  int getLuaParserStateChildren(LuaParserState *pState, LuaParserToken *tk) {
    int children = 0;
    for(int i=pState->stack_top-1; i >= 0; --i) {
      if(pState->stack[i] == tk) break;
      ++children;
    }
    return children;
  }

  LuaParserToken *getLastLuaParserState(LuaParserState *pState) {
    int idx = pState->stack_top-2;
    LuaParserToken *ltk = pState->stack[idx];
    for(; idx >= 0; --idx) {
      //if the token is a comment/space skip it
      if(ltk->token_id < TK_LEMON_LAST_TOKEN) break;
      ltk = pState->stack[idx];
    }
    return ltk;
  }

  LuaParserToken *getNextLuaParserState(LuaParserState *pState, LuaParserToken *tk) {
    int idx = pState->stack_top-2;
    int top = idx;
    LuaParserToken *ltk = pState->stack[idx];
    while(idx >= 0 && pState->stack[idx] != tk) --idx;
    while(++idx <= top) {
      ltk = pState->stack[idx];
      //if the token is a comment/space skip it
      if(ltk->token_id < TK_LEMON_LAST_TOKEN) break;
    }
    return ltk;
  }

  char *newStrFmt(LuaParserToken *tk, const char* fmt, ...) __attribute__ ((__format__ (__printf__, 2, 3)));
  char *newStrFmt(LuaParserToken *tk, const char* fmt, ...) {
    char tmp[8];
    va_list args;
    va_start(args, fmt);
    int sz = vsnprintf(tmp, sizeof(tmp), fmt, args);
    if(sz < 0) {
      printf("bad format string |%s|\n", fmt);
      exit(1);
    }
    va_end(args);

    char *str = malloc(sz+1);
    va_start(args, fmt);
    sz = vsnprintf(str, sz+1, fmt, args);
    va_end(args);
    if(tk->token_value_size < 0) free((void*)tk->token_value);
    tk->token_value = str;
    tk->token_value_size = -sz;
    return str;
  }

  void doOutput(LuaParserState *pState) {
    for(int i=0; i < pState->stack_top; ++i) {
      LuaParserToken *tk = pState->stack[i];
      if(tk->token_id < 0) {
        fprintf(stdout, "%c", tk->token_id*-1);
        continue;
      }
      if(tk->space_before_size) {
        fprintf(stdout, "%.*s", tk->space_before_size, pState->src + tk->space_before_pos);
      }
      //if(tk->children) fprintf(stderr, "|%d|", tk->children);
      fprintf(stdout, "%.*s", abs(tk->token_value_size), tk->token_value);
    }
  }

  void setTokenValue(LuaParserToken *tk, const char *str) {
    if(tk->token_value_size < 0) free((void*)tk->token_value);
    tk->token_value_size = strlen(str);
    tk->token_value = str;
  }
  void local2var(LuaParserToken *tk) {setTokenValue(tk, "var");}
  
  void checkSetAssignTokenOpToken(LuaParserState *pState, LuaParserToken *tkSrc, LuaParserToken *tkAssign, LuaParserToken *tk1) {
    if(tkAssign->token_id != TK_ASSIGN) return;
    if(tkSrc->token_value_size == tk1->token_value_size) {
      if(strncmp(tkSrc->token_value, tk1->token_value, tkSrc->token_value_size) == 0) {
        LuaParserToken *tkOp = getNextLuaParserState(pState, tk1);
        const char *newOp = NULL;
        switch(tkOp->token_id) {
          case TK_PLUS:
            newOp = "+="; 
          break;
          case TK_MINUS:
            newOp = "-="; 
          break;
          case TK_MUL:
            newOp = "*="; 
          break;
          case TK_DIV:
            newOp = "/="; 
          break;
        }
        if(newOp) {
          setTokenValue(tkAssign, newOp);
          setTokenValue(tk1, "");
          setTokenValue(tkOp, "");
        }
      }
    }
  }
  
  void dumpToken(LuaParserToken *tk) {
    printf("%d : %.*s\n", tk->token_id, tk->token_value_size, tk->token_value);
  }

}

%extra_argument { LuaParserState *pState }

/*
%parse_accept {
  printf("parsing complete!\n");
}

%parse_failure {
 fprintf(stderr,"Giving up.  Parser is hopelessly lost...\n");
}
*/

%token_prefix    TK_

%fallback  OPEN LPAREN .

%start_symbol chunk

chunk      ::= block .

semi       ::= . { LuaParserToken *tk = getLastLuaParserState(pState);
                              newStrFmt(tk, "%.*s;", tk->token_value_size, tk->token_value); }
semi       ::= SEMICOLON .

block      ::= scope statlist .
block      ::= scope statlist laststat semi .
ublock     ::= block UNTIL(A) exp . { setTokenValue(A, "} while(!(");
                                                        LuaParserToken *tk = getLastLuaParserState(pState);
                                                        newStrFmt(tk, "%.*s) )", tk->token_value_size, tk->token_value); }

scope      ::= .
scope      ::= scope statlist binding semi.

statlist   ::= .
statlist   ::= statlist stat semi .
//statlist   ::= comment .
//statlist   ::= SPACE .
//statlist   ::= THEEND .

stat       ::= DO(A) block END(B) . { setTokenValue(A, "{"); setTokenValue(B, "}");}
stat       ::= WHILE(A) exp DO(B) block END(C) . { setTokenValue(A, "while("); setTokenValue(B, ") {"); setTokenValue(C, "}");}
stat       ::= repetition DO(A) block END(B) . { setTokenValue(A, ") {"); setTokenValue(B, "}");}
stat       ::= REPEAT(A) ublock . { setTokenValue(A, "do {"); }
stat       ::= IF(A) conds END(B) . { setTokenValue(A, "if("); setTokenValue(B, "}");}
stat       ::= FUNCTION funcname funcbody .
stat       ::= setlist(A) ASSIGN(B) explist1(C) . {checkSetAssignTokenOpToken(pState, A, B, C);}
stat       ::= functioncall .

//%ifdef LUA_GOTO // lua 5.2 and up
stat       ::= GOTO NAME .
stat       ::= LABEL(A) . { newStrFmt(A, "%.*s", A->token_value_size-3, A->token_value+2);}
//%endif

repetition ::= FOR(A) NAME ASSIGN explist23 . {setTokenValue(A, "for(");}
repetition ::= FOR(A) namelist IN explist1 . {setTokenValue(A, "for(");}

conds      ::= condlist .
conds      ::= condlist ELSE(A) block . { setTokenValue(A, "} else {");}

condlist   ::= cond .
condlist   ::= condlist ELSEIF(A) cond . { setTokenValue(A, "} else if(");}

cond       ::= exp THEN(A) block . { setTokenValue(A, ") {");}

laststat   ::= BREAK .
laststat   ::= RETURN .
laststat   ::= RETURN explist1 .

binding    ::= LOCAL(A) namelist . { local2var(A);}
binding    ::= LOCAL(A) namelist ASSIGN(B) explist1 . { local2var(A); /*setTokenValue(B, ":=:");*/}
binding    ::= LOCAL(A) FUNCTION NAME funcbody . { local2var(A);}

funcname   ::= dottedname .
funcname   ::= dottedname COLON(A) NAME . { setTokenValue(A, "::");}

dottedname ::= NAME .
dottedname ::= dottedname DOT NAME .

namelist   ::= NAME .
namelist   ::= namelist COMMA NAME .

explist1   ::= exp .
explist1   ::= explist1 COMMA exp .

explist23  ::= exp COMMA exp .
explist23  ::= exp COMMA exp COMMA exp .

%left      OR .
%left      AND .
%nonassoc      EQ NEQ .
%nonassoc      LT LTEQ BT BTEQ .
%right     CONCAT .
%left      PLUS MINUS .
%left      MUL DIV MOD .
%right     NOT LEN .
%right     POW .

exp        ::= NIL .
exp        ::= TRUE .
exp        ::= FALSE .
exp        ::= NUMBER .
exp        ::= STRING .
exp        ::= LONGSTRING .
exp        ::= ELLIPSIS .
exp        ::= function .
exp        ::= prefixexp .
exp        ::= tableconstructor .
//unary operators
exp        ::= NOT exp . [NOT]
exp        ::= LEN exp . [NOT]
exp        ::= MINUS exp . [NOT]
//binary operators
exp        ::= exp OR exp .
exp        ::= exp AND exp .
exp        ::= exp LT exp .
exp        ::= exp LTEQ exp .
exp        ::= exp BT exp .
exp        ::= exp BTEQ exp .
exp        ::= exp EQ exp .
exp        ::= exp NEQ(A) exp . { setTokenValue(A, "!=");}
exp        ::= exp CONCAT(A) exp . { setTokenValue(A, "+");}
exp        ::= exp PLUS exp .
exp        ::= exp MINUS exp .
exp        ::= exp MUL exp .
exp        ::= exp DIV exp .
exp        ::= exp MOD exp .
exp        ::= exp POW exp .

//%ifdef LUA_BITOP //lua 5.3 and up
%left      IDIV SHL SHR .
%left      BITAND BITOR .
%right    BITNOT .
exp        ::= BITNOT exp . [NOT]
exp        ::= exp IDIV exp .
exp        ::= exp SHL exp .
exp        ::= exp SHR exp .
exp        ::= exp BITAND exp .
exp        ::= exp BITOR exp .
//%endif

setlist    ::= var .
setlist    ::= setlist COMMA var .

var        ::= NAME .
var        ::= prefixexp LBRACKET exp RBRACKET .
var        ::= prefixexp DOT NAME .

prefixexp  ::= var .
prefixexp  ::= functioncall .
prefixexp  ::= OPEN exp RPAREN .

functioncall ::= prefixexp args .
functioncall ::= prefixexp COLON(A) NAME args . { setTokenValue(A, "->");}

args        ::= LPAREN RPAREN .
args        ::= LPAREN explist1 RPAREN .
args(A)        ::= tableconstructor . { newStrFmt(A, "(%.*s", A->token_value_size, A->token_value);
                                                        setTokenValue(getLastLuaParserState(pState), "})"); }
args(A)        ::= STRING . { newStrFmt(A, "(%.*s)", A->token_value_size, A->token_value);}

function    ::= FUNCTION funcbody .

funcbody    ::= params block END(A) . { setTokenValue(A, "}");}

params      ::= LPAREN parlist RPAREN(A) . { setTokenValue(A, ") {");}

parlist     ::= .
parlist     ::= ELLIPSIS .
parlist     ::= namelist .
parlist     ::= namelist COMMA ELLIPSIS .

tableconstructor ::= LBRACE RBRACE .
tableconstructor ::= LBRACE fieldlist RBRACE .
tableconstructor ::= LBRACE fieldlist fieldsep RBRACE .

fieldsep ::= COMMA .
fieldsep ::= SEMICOLON .

fieldlist   ::= field .
fieldlist   ::= fieldlist fieldsep field .

field       ::= exp .
field       ::= NAME ASSIGN exp .
field       ::= LBRACKET exp RBRACKET ASSIGN exp .

//comment ::= COMMENT .
//comment ::= LONGCOMMENT .
