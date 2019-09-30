{
module Main where
import Lexer
}

%name parse
%tokentype { Token }
%error { parseError }

%token 
    and                 { TAnd       }
    array               { TArray     }
    begin               { TBegin     }
    boolean             { TBoolean   }
    char                { TChar      }
    dispose             { TDispose   }
    div                 { TDivInt    }
    do                  { TDo        }
    else                { TElse      }
    end                 { TEnd       }
    false               { TFalse     }
    forward             { TForward   }
    function            { TFunction  }
    goto                { TGoto      }
    if                  { TIf        }
    integer             { TInteger   }
    label               { TLabel     }
    mod                 { TMod       }
    new                 { TNew       }
    nil                 { TNil       }
    not                 { TNot       }
    of                  { TOf        }
    or                  { TOr        }
    procedure           { TProcedure }
    program             { TProgram   }
    real                { TReal      }
    result              { TResult    }
    return              { TReturn    }
    then                { TThen      }
    true                { TTrue      }
    var                 { TVar       }
    while               { TWhile     }
    id                  { TId          $$ }
    intconst            { TIntconst    $$ }
    realconst           { TRealconst   $$ }
    charconst           { TCharconst   $$ }
    stringconst         { TStringconst $$ }
    '='                 { TLogiceq      }
    '>'                 { TGreater      }
    '<'                 { TSmaller      }
    diff                { TDifferent    }
    greq                { TGreaterequal }
    smeq                { TSmallerequal }
    '+'                 { TAdd          }
    '-'                 { TMinus        }
    '*'                 { TMul          }
    '/'                 { TDivReal      }
    '^'                 { TPointer      }
    '@'                 { TAdress       }
    equal               { TEq           }
    ';'                 { TSeperator    }
    '.'                 { TDot          }
    '('                 { TLeftparen    }
    ')'                 { TRightparen   }
    ':'                 { TUpdown       }
    ','                 { TComma        }
    '['                 { TLeftbracket  }
    ']'                 { TRightbracket }

%nonassoc '<' '>' '=' greq smeq diff
%left '+' '-' or
%left '*' '/' div mod and
%left not
%left NEG POS
%right '^'
%left '@'
%%

Program :: { Program }
        : program id ';' Body '.'                     { P $2 $4 }

Body    :: { Body }
        : Locals Block                                { B $1 $2 }  

Locals :: { [Local] }
        : Locals Local                                { $2 : $1 }
        | {-empty-}                                   { []      }

Local   :: { Local }
        : var Variables                               { LoVar $2          }
        | label id Ids ';'                            { LoLabel ($2 : $3) }
        | Header ';' Body ';'                         { LoHeadBod $1 $3   }
        | forward Header ';'                          { LoForward $2      }

Variables : Variables IdsAndType                      { $2 : $1 }
          | IdsAndType                                { [$1]    }

IdsAndType : id Ids ':' Type ';'                      { ($4,$1 : $2) } 

Ids    : Ids ',' id                                   { $3 : $1 }
       | {-empty-}                                    { []      }

Header : procedure id '(' Arguments1 ')'              { Procedure $2 $4   } 
       | function id '(' Arguments1 ')' ':' Type      { Function $2 $4 $7 }

Arguments1 : {-empty-}                                { [] }
           | Arguments2                               { $1 }

Arguments2 : Arguments2 ';' Formal                    { $3 : $1 }
           | Formal                                   { [$1]    }

Formal : Vars id Ids ':' Type                         { ($5,$2:$3) }
 
Vars : {-empty-}                                      { [] }
     | var                                            { [] }

Type : integer                                        { Tint        }     
     | real                                           { Treal       }
     | boolean                                        { Tbool       }
     | char                                           { Tchar       }
     | array Array of Type                            { ArrayT $4   }
     | '^' Type                                       { PointerT $2 }

Array : '[' intconst ']'                              { [] }
      | {-empty-}                                     { [] }

Block : begin Stmt Stmts end                          { Bl ($2:$3) } 

Stmts : Stmts ';' Stmt                                { $3 : $1 } 
      | {-empty-}                                     { []      }

Stmt : {-empty-}                                      { SEmpty       } 
     | LValue equal Expr                              { SEqual $1 $3 }
     | Block                                          { SBlock $1    }
     | Call                                           { SCall  $1    }
     | if Expr then Stmt Else                         { SIf $2 $4 $5 }     
     | while Expr do Stmt                             { SWhile $2 $4 }
     | id ':' Stmt                                    { SId    $1 $3 }
     | goto id                                        { SGoto (tokenizer $1) }
     | return                                         { SReturn      }
     | new New LValue                                 { SNew   $2 $3 }
     | dispose Dispose LValue                         { SDispose $3  }

Else : else Stmt                                      { SElse $2 }
     | {-empty-}                                      { SEmpty   }

New  : '[' Expr ']'                                   { $2     }
     | {-empty-}                                      { EEmpty }

Dispose : '[' ']'                                     { [] }
        | {-empty-}                                   { [] }

Expr   : LValue                                       { L $1 }
       | RValue                                       { R $1 }

LValue : id                                           { LId $1     }
       | result                                       { LResult    }
       | stringconst                                  { LString $1 }
       | LValue '[' Expr ']'                          { LValueExpr $1 $3 }
       | Expr '^'                                     { LExpr $1   }
       | '(' LValue ')'                               { LParen $2  }

RValue : intconst                                     { RInt     $1 }
       | true                                         { RTrue       }
       | false                                        { RFalse      } 
       | realconst                                    { RReal    $1 }
       | charconst                                    { RChar    $1 }
       | '(' RValue ')'                               { RParen   $2 }
       | nil                                          { RNil        }
       | Call                                         { RCall    $1 }
       | '@' LValue %prec NEG                         { RPapaki  $2 }
       | not  Expr                                    { RNot     $2 }
       | '+'  Expr %prec POS                          { RPos     $2 }
       | '-'  Expr %prec NEG                          { RNeg     $2 }
       | Expr '+'  Expr                               { RPlus    $1 $3 }
       | Expr '*'  Expr                               { RMul     $1 $3 }
       | Expr '-'  Expr                               { RMinus   $1 $3 }
       | Expr '/'  Expr                               { RRealDiv $1 $3 }
       | Expr div  Expr                               { RDiv     $1 $3 }
       | Expr mod  Expr                               { RMod     $1 $3 }
       | Expr or   Expr                               { ROr      $1 $3 }
       | Expr and  Expr                               { RAnd     $1 $3 }
       | Expr '='  Expr                               { REq      $1 $3 }
       | Expr diff Expr                               { RDiff    $1 $3 }
       | Expr '<'  Expr                               { RLess    $1 $3 }
       | Expr '>'  Expr                               { RGreater $1 $3 }
       | Expr greq Expr                               { RGreq    $1 $3 }
       | Expr smeq Expr                               { RSmeq    $1 $3 }

       
Call : id '(' Call2 ')'                               { CId $1 $3 }

Call2 : {-empty-}                                     { []      }
      | Expr Call3                                    { $1 : $2 }

Call3 : Call3 ',' Expr                                { $3 : $1 } 
      | {-empty-}                                     { []      }

    
{

parseError _ = error ("Parse error\n")

tokenizer :: Token -> String
tokenizer token = show token

data Program =
  P String Body
  deriving(Show)

data Body =
  B [Local] Block
  deriving(Show)

data Local =
  LoVar Variables         |
  LoLabel [String]        |
  LoHeadBod Header Body   |
  LoForward Header
  deriving(Show)

type Id = String
type MoreVariables = [Id]
type Variables = [ (Type, MoreVariables) ]
type Labels = MoreVariables

data Header =
  Procedure String Arguments1 |
  Function String Arguments1 Type
  deriving(Show)

type Arguments1 = [Formal]
type Arguments2 = Arguments1

type Formal = (Type,[String])

data Type =
  Tint          | 
  Treal         |
  Tbool         |
  Tchar         |
  ArrayT Type   |
  PointerT Type 
  deriving(Show)


type Stmts = [Stmt]

data Block =
  Bl Stmts
  deriving(Show)
  
data Stmt = 
  SEmpty             | 
  SEqual LValue Expr |
  SBlock Block       |
  SCall Call         |
  SIf Expr Stmt Stmt |
  SWhile Expr Stmt   |
  SId Id Stmt        |
  SGoto Id           |
  SReturn            |
  SNew Expr LValue   |
  SDispose LValue    |
  SElse Stmt
  deriving(Show)

data Expr =
 L LValue |
 R RValue |
 EEmpty
 deriving(Show)

data LValue =
  LId Id                 |
  LResult                |
  LString String         |
  LValueExpr LValue Expr |
  LExpr Expr             |
  LParen LValue
  deriving(Show)

data RValue =
  RInt Int           |
  RTrue              |
  RFalse             |
  RReal Double       |
  RChar Char         |
  RParen RValue      |
  RNil               |
  RCall Call         |
  RPapaki LValue     |
  RNot     Expr      |
  RPos     Expr      |
  RNeg     Expr      |
  RPlus    Expr Expr |
  RMul     Expr Expr |
  RMinus   Expr Expr |
  RRealDiv Expr Expr |
  RDiv     Expr Expr |
  RMod     Expr Expr |
  ROr      Expr Expr |
  RAnd     Expr Expr |
  REq      Expr Expr |
  RDiff    Expr Expr |
  RLess    Expr Expr |
  RGreater Expr Expr |
  RGreq    Expr Expr |
  RSmeq    Expr Expr
  deriving(Show)

data Call =
  CId Id [Expr]
  deriving(Show)

main = getContents >>= print . parse . alexScanTokens 
}
