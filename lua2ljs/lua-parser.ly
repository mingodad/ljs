%name LuaParser

%stack_size 1000

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

  enum TokenFlags {
    noSemicolonNeeded = 0x01,
  };

  typedef struct LuaParserToken {
    int token_id;
    int space_before_size;
    int space_before_pos;
    int token_value_size;
    const char *token_value;
    int flags;
  } LuaParserToken;

 // void dummyFree(void *p) {assert(p);};

  typedef struct LuaParserState {
    const char *src;
    void **stack;
    int stack_size, stack_top;
    int noToCompound;
  } LuaParserState;

  void initializeLuaParserState(LuaParserState *pState) {
    pState->src = NULL;
    pState->stack = NULL;
    pState->stack_size = 0;
    pState->stack_top = 0;
    pState->noToCompound = 0;
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
    /*
    * There is a problem with this when the last stement is not followed by a '\n'
    * right now we are avoiding it by adding a '\n' at the end when reading the file
    */
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

  int getLuaParserStateForwardCount(LuaParserState *pState, LuaParserToken *tk) {
    int idx = pState->stack_top-2;
    int top = idx;
    while(idx >= 0 && pState->stack[idx] != tk) --idx;
    return top - idx;
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
  void moveTokenValue(LuaParserToken *tk, LuaParserToken *tk_src) {
    if(tk->token_value_size < 0) free((void*)tk->token_value);
    tk->token_value_size = tk_src->token_value_size;
    tk->token_value = tk_src->token_value;
    tk_src->token_value = NULL;
    tk_src->token_value_size = 0;
  }
  void local2var(LuaParserToken *tk) {setTokenValue(tk, "var");}

  int _canMakePlusPlusMinusMinus(LuaParserState *pState, LuaParserToken *tkSrc, LuaParserToken *tkAssign, LuaParserToken *tk1,
						LuaParserToken *tkOp, const char *mORp) {
    LuaParserToken *tkAftertOp = getNextLuaParserState(pState, tkOp);
    if(tkAftertOp->token_value_size == 1 && tkAftertOp->token_value[0] == '1') {
	newStrFmt(tkSrc, "%s%.*s", mORp, tkSrc->token_value_size, tkSrc->token_value);
	setTokenValue(tkAftertOp, "");
	setTokenValue(tk1, "");
	setTokenValue(tkOp, "");
	setTokenValue(tkAssign, "");
	return 1;
    }
    return 0;
  }

  void checkSetAssignTokenOpToken(LuaParserState *pState, LuaParserToken *tkSrc, LuaParserToken *tkAssign, LuaParserToken *tk1) {

   /* compound assignment can produce a wrong result when there is more than one expression on the right side */
   /* so it's a bad idea to do it blindly */

    if(tkAssign->token_id != TK_ASSIGN) return;
    if(pState->noToCompound) return;
    if(getNextLuaParserState(pState, tkSrc) != tkAssign) return; //if it's a list assignment do nothing
    if(tkSrc->token_value_size == tk1->token_value_size) {
      if(strncmp(tkSrc->token_value, tk1->token_value, tkSrc->token_value_size) == 0) {
        LuaParserToken *tkOp = getNextLuaParserState(pState, tk1);
	int forwardCount = getLuaParserStateForwardCount(pState, tk1);

	if(forwardCount > 2) return; //only safe to do it with two ahead tokens/expressions
	//printf("== %.*s : %d\n", tkSrc->token_value_size, tkSrc->token_value, forwardCount);

        const char *newOp = NULL;
        switch(tkOp->token_id) {
          case TK_PLUS:
            if(_canMakePlusPlusMinusMinus(pState, tkSrc, tkAssign, tk1, tkOp, "++")) return;
            newOp = "+=";
          break;
          case TK_MINUS:
            if(_canMakePlusPlusMinusMinus(pState, tkSrc, tkAssign, tk1, tkOp, "--")) return;
            newOp = "-=";
          break;
/* this ones are safe only if there is one more expresion */
          case TK_MOD:
            newOp = "%=";
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

  void setTokenFlag(LuaParserToken *tk, enum TokenFlags fv, int OnOff) {
    if(OnOff) tk->flags |= fv;
    else tk->flags &= ~fv;
  }

  void fixLongStringQuote(LuaParserToken *tk) {
    if(tk->token_value[1] == '[') {
      /* we need at least one '=' on the quote to differentiate from arrays */
      int tk_vsz = abs(tk->token_value_size);
      int sz = tk_vsz + 2;
      char *str = malloc(sz+1);
      snprintf(str, sz+1, "[=[%.*s]=]", tk_vsz-4, tk->token_value+2);
      if(tk->token_value_size < 0) free((void*)tk->token_value);
      tk->token_value = str;
      tk->token_value_size = sz * -1;
    }
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
                              if(!(tk->flags & noSemicolonNeeded))
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

stat       ::= DO(A) block END(B) . { setTokenValue(A, "{"); setTokenValue(B, "}"); setTokenFlag(B, noSemicolonNeeded, 1);}
stat       ::= WHILE(A) exp DO(B) block END(C) . { setTokenValue(A, "while("); setTokenValue(B, ") {"); setTokenValue(C, "}"); setTokenFlag(C, noSemicolonNeeded, 1);}
stat       ::= repetition DO(A) block END(B) . { setTokenValue(A, ") {"); setTokenValue(B, "}"); setTokenFlag(B, noSemicolonNeeded, 1);}
stat       ::= REPEAT(A) ublock . { setTokenValue(A, "do {"); }
stat       ::= IF(A) conds END(B) . { setTokenValue(A, "if("); setTokenValue(B, "}"); setTokenFlag(B, noSemicolonNeeded, 1);}
stat       ::= FUNCTION funcname funcbody .
stat       ::= setlist(A) ASSIGN(B) explist1(C) . {checkSetAssignTokenOpToken(pState, A, B, C);}
stat       ::= functioncall .

//%ifdef LUA_GOTO // lua 5.2 and up
stat       ::= GOTO ident .
stat       ::= LABEL(A) . { newStrFmt(A, "%.*s", A->token_value_size-3, A->token_value+2);  setTokenFlag(A, noSemicolonNeeded, 1);}
//%endif

repetition ::= FOR(A) ident ASSIGN explist23 . {setTokenValue(A, "for(");}
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
binding    ::= LOCAL(A) FUNCTION ident funcbody . { local2var(A);}
/*binding    ::= LOCAL(A) FUNCTION(B) ident(C) funcbody . { local2var(A); moveTokenValue(B, C); setTokenValue(C, "= function");}*/

funcname   ::= dottedname .
funcname   ::= dottedname COLON(A) ident . { setTokenValue(A, "::");}

dottedname ::= ident .
dottedname ::= dottedname DOT ident .

namelist   ::= ident .
namelist   ::= namelist COMMA ident .

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

exp        ::= NIL(A) .  { setTokenValue(A, "null");}
exp        ::= TRUE .
exp        ::= FALSE .
exp        ::= NUMBER .
exp        ::= string .
exp        ::= ELLIPSIS .
exp        ::= function .
exp        ::= prefixexp .
exp        ::= tableconstructor .
//unary operators
exp        ::= NOT(A) exp . [NOT]  { setTokenValue(A, "!");}
exp        ::= LEN exp . [NOT]
exp        ::= MINUS exp . [NOT]
//binary operators
exp        ::= exp OR(A) exp . { setTokenValue(A, "||");}
exp        ::= exp AND(A) exp . { setTokenValue(A, "&&");}
exp        ::= exp LT exp .
exp        ::= exp LTEQ exp .
exp        ::= exp BT exp .
exp        ::= exp BTEQ exp .
exp        ::= exp EQ exp .
exp        ::= exp NEQ(A) exp . { setTokenValue(A, "!=");}
exp        ::= exp CONCAT exp . //{ setTokenValue(A, "+");}
exp        ::= exp PLUS exp .
exp        ::= exp MINUS exp .
exp        ::= exp MUL exp .
exp        ::= exp DIV exp .
exp        ::= exp MOD exp .
exp        ::= exp POW(A) exp .  { setTokenValue(A, "**");}

//%ifdef LUA_BITOP //lua 5.3 and up
%left      IDIV SHL SHR .
%left      BITAND BITOR .
%right    BITNOT .
exp        ::= BITNOT exp . [NOT]
exp        ::= exp IDIV(A) exp . { setTokenValue(A, "idiv");}
exp        ::= exp SHL exp .
exp        ::= exp SHR exp .
exp        ::= exp BITAND exp .
exp        ::= exp BITOR exp .
exp        ::= exp BITNOT(A) exp . { setTokenValue(A, "^");}
//%endif

setlist    ::= var .
setlist    ::= setlist COMMA var .

var        ::= ident .
var        ::= prefixexp LBRACKET exp RBRACKET .
var        ::= prefixexp DOT ident .

prefixexp  ::= var .
prefixexp  ::= functioncall .
prefixexp  ::= OPEN exp RPAREN .

functioncall ::= prefixexp args .
functioncall ::= prefixexp COLON(A) ident args . { setTokenValue(A, "->");}

args        ::= LPAREN RPAREN .
args        ::= LPAREN explist1 RPAREN .
args(A)        ::= tableconstructor . { newStrFmt(A, "(%.*s", A->token_value_size, A->token_value);
                                                        setTokenValue(getLastLuaParserState(pState), "})"); }
args(A)        ::= string . { newStrFmt(A, "(%.*s)", A->token_value_size, A->token_value);}

function    ::= FUNCTION funcbody . {LuaParserToken *tk = getLastLuaParserState(pState);
                                                          /* here we invert the setting done on funcbody */ setTokenFlag(tk, noSemicolonNeeded, 0);}

funcbody    ::= params block END(A) . { setTokenValue(A, "}");  setTokenFlag(A, noSemicolonNeeded, 1);}

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
field       ::= ident ASSIGN exp .
field       ::= LBRACKET exp RBRACKET ASSIGN exp .

ident     ::= NAME(A) . {
                                      #define SELF_NAME "self"
                                      if(A->token_value_size == (sizeof(SELF_NAME)-1)
                                            && strncmp(A->token_value, SELF_NAME, A->token_value_size) == 0) setTokenValue(A, "this");
                                      #undef SELF_NAME
                                      #define VAR_NAME "var"
                                      else if(A->token_value_size == (sizeof(VAR_NAME)-1)
                                            && strncmp(A->token_value, VAR_NAME, A->token_value_size) == 0) setTokenValue(A, "_v_var");
                                      #undef VAR_NAME
                                    }

string    ::= STRING .
string    ::= LONGSTRING(A) . {fixLongStringQuote(A);}

//comment ::= COMMENT .
//comment ::= LONGCOMMENT .
