{
module Parser where
import Lexer
import Prelude hiding (getChar)
import Data.Either
}

%name parse
%tokentype { Token }
%error { parseError }
%monad { Alex }
%lexer { lexwrap } { Eof }

%token
    and         { TAnd          $$ }
    array       { TArray        $$ }
    begin       { TBegin        $$ }
    boolean     { TBoolean      $$ }
    char        { TChar         $$ }
    dispose     { TDispose      $$ }
    div         { TDivInt       $$ }
    do          { TDo           $$ }
    else        { TElse         $$ }
    end         { TEnd          $$ }
    false       { TFalse        $$ }
    forward     { TForward      $$ }
    function    { TFunction     $$ }
    goto        { TGoto         $$ }
    if          { TIf           $$ }
    integer     { TInteger      $$ }
    label       { TLabel        $$ }
    mod         { TMod          $$ }
    new         { TNew          $$ }
    nil         { TNil          $$ }
    not         { TNot          $$ }
    of          { TOf           $$ }
    or          { TOr           $$ }
    procedure   { TProcedure    $$ }
    program     { TProgram      $$ }
    real        { TReal         $$ }
    result      { TResult       $$ }
    return      { TReturn       $$ }
    then        { TThen         $$ }
    true        { TTrue         $$ }
    var         { TVar          $$ }
    while       { TWhile        $$ }
    id          { TId           value posn }
    intconst    { TIntconst     value posn }
    realconst   { TRealconst    value posn }
    charconst   { TCharconst    value posn }
    stringconst { TStringconst  value posn }
    '='         { TLogiceq      $$ }
    '>'         { TGreater      $$ }
    '<'         { TSmaller      $$ }
    diff        { TDifferent    $$ }
    greq        { TGreaterequal $$ }
    smeq        { TSmallerequal $$ }
    '+'         { TAdd          $$ }
    '-'         { TMinus        $$ }
    '*'         { TMul          $$ }
    '/'         { TDivReal      $$ }
    '^'         { TPointer      $$ }
    '@'         { TAdress       $$ }
    equal       { TEq           $$ }
    ';'         { TSeperator    $$ }
    '.'         { TDot          $$ }
    '('         { TLeftparen    $$ }
    ')'         { TRightparen   $$ }
    ':'         { TUpdown       $$ }
    ','         { TComma        $$ }
    '['         { TLeftbracket  $$ }
    ']'         { TRightbracket $$ }

%left RExpr
%left LExpr
%right then else
%nonassoc '<' '>' '=' greq smeq diff
%left '+' '-' or
%left '*' '/' div mod and
%left not
%left NEG POS
%right '^'
%left '@'
%%

Program    :: { Program }
           : program id ';' Body '.'            { P (tokenToId $2) $4 }

Body       :: { Body }
           : Locals Block                       { Body $1 $2 }

Locals     :: { [Local] }
           : {-empty-}                          { []    }
           | Locals Local                       { $2:$1 }

Local      :: { Local }
           : var Variables                      { VarsWithTypeList    $2    }
           | label Ids ';'                      { Labels   $2    }
           | Header ';' Body ';'                { HeaderBody $1 $3 }
           | forward Header ';'                 { Forward $2    }

Variables  :: { [([Id],Type)] }
           : IdsAndType                         { [$1]  }
           | Variables IdsAndType               { $2:$1 }

IdsAndType :: { ([Id],Type) }
           : Ids ':' Type ';'                   { ($1,$3) }

Ids        :: { [Id] }
           : id                                 { [(tokenToId $1) ]  }
           | Ids ',' id                         { (tokenToId $3) :$1 }

Header     :: { Header }
           : procedure id '(' Args ')'          { ProcHeader (tokenToId $2)  $4    }
           | function  id '(' Args ')' ':' Type { FuncHeader  (tokenToId $2)  $4 $7 }

Args       :: { [Formal] }
           : {-empty-}                          { [] }
           | Formals                            { $1 }

Formals    :: { [Formal] }
           : Formal                             { [$1]  }
           | Formals ';' Formal                 { $3:$1 }

Formal     :: { Formal }
           : Optvar Ids ':' Type                { ($1,$2,$4) }

Optvar     :: { PassBy }
Optvar     : {-empty-}                          { Value     }
           | var                                { Reference }

Type :: { Type }
     : integer                            { Int'           }
     | real                               { Real'          }
     | boolean                            { Bool'          }
     | char                               { Char'          }
     | array ArrSize of Type              { Array   $2 $4 }
     | '^' Type                           { Pointer $2    }

ArrSize :: { ArrSize }
        : {-empty-}                          { NoSize  }
        | '[' intconst ']'                   { Size (getInt $2) }

Block :: { [Stmt] }
      : begin Stmts end                    { $2 }

Stmts :: { [Stmt] }
      : Stmt                               { [$1]    }
      | Stmts ';' Stmt                     { $3 : $1 }

Stmt :: { Stmt }
     : {-empty-}                   { Empty }
     | LVal equal Expr             { Equal (posnToLi $2) (posnToLi $2) $1 $3}
     | Block                       { Block $1 }
     | Call                        { Call $1 }
     | if Expr then Stmt           { IfThen (posnToLi $1) (posnToCo $1) $2 $4 }
     | if Expr then Stmt else Stmt { IfThenElse (posnToLi $1) (posnToCo $1) $2 $4 $6 }
     | while Expr do Stmt          { While (posnToLi $1) (posnToCo $1) $2 $4 }
     | id ':' Stmt                 { Label (tokenToId $1) $3 }
     | goto id                     { GoTo (tokenToId $2) }
     | return                      { Return }
     | new New LVal              { New (posnToLi $1) (posnToCo $1) $2 $3 }
     | dispose Dispose LVal      { Dispose (posnToLi $1) (posnToCo $1) $2 $3 }

New        :: { New }
           :  {-empty-}                         { NewEmpty   }
           | '[' Expr ']'                       { NewExpr $2 }

Dispose    : {-empty-}                          { Without }
           | '[' ']'                            { With    }

Expr       :: { Expr }
           : LVal %prec LExpr                 { LVal $1 }
           | RVal %prec RExpr                 { RVal $1 }

LVal     :: { LVal }
           : id                { IdL        (tokenToId $1)    }
           | result            { Result    (posnToLi $1) (posnToCo $1) }
           | stringconst       { StrLiteral    (getString $1)    }
           | LVal '[' Expr ']' { LValExpr (posnToLi $2) (posnToCo $2) $1 $3 }
           | Expr '^'          { LExpr      (posnToLi $2) (posnToCo $2) $1    }
           | '(' LVal ')'      { LParen     $2    }

RVal     :: { RVal }
           : intconst                           { RInt     (getInt $1) }
           | true                               { RTrue       }
           | false                              { RFalse      }
           | realconst                          { RReal    (getReal $1) }
           | charconst                          { RChar    (getChar $1) }
           | '(' RVal ')'                     { RParen   $2 }
           | nil                                { RNil        }
           | Call                               { RCall    $1 }
           | '@' LVal                         { RPapaki  (posnToIntInt $1) $2 }
           | not  Expr                          { RNot     (posnToIntInt $1) $2 }
           | '+'  Expr %prec POS                { RPos     (posnToIntInt $1) $2 }
           | '-'  Expr %prec NEG                { RNeg     (posnToIntInt $1) $2 }
           | Expr '+'  Expr                     { RPlus    (posnToIntInt $2) $1 $3 }
           | Expr '*'  Expr                     { RMul     (posnToIntInt $2) $1 $3 }
           | Expr '-'  Expr                     { RMinus   (posnToIntInt $2) $1 $3 }
           | Expr '/'  Expr                     { RRealDiv (posnToIntInt $2) $1 $3 }
           | Expr div  Expr                     { RDiv     (posnToIntInt $2) $1 $3 }
           | Expr mod  Expr                     { RMod     (posnToIntInt $2) $1 $3 }
           | Expr or   Expr                     { ROr      (posnToIntInt $2) $1 $3 }
           | Expr and  Expr                     { RAnd     (posnToIntInt $2) $1 $3 }
           | Expr '='  Expr                     { REq      (posnToIntInt $2) $1 $3 }
           | Expr diff Expr                     { RDiff    (posnToIntInt $2) $1 $3 }
           | Expr '<'  Expr                     { RLess    (posnToIntInt $2) $1 $3 }
           | Expr '>'  Expr                     { RGreater (posnToIntInt $2) $1 $3 }
           | Expr greq Expr                     { RGreq    (posnToIntInt $2) $1 $3 }
           | Expr smeq Expr                     { RSmeq    (posnToIntInt $2) $1 $3 }

Call       :: { Call }
           : id '(' ArgExprs ')'                { CId (tokenToId $1)  $3 }

ArgExprs   :: { Exprs }
           : {-empty-}                          { [] }
           | Exprs                              { $1 }

Exprs      :: { Exprs }
           : Expr                               { [$1]  }
           | Exprs ',' Expr                     { $3:$1 }

{

parseError :: Token -> Alex a
parseError = posnParseError . posn

posnParseError (AlexPn _ li co) =
  alexError $ concat ["Parse error at line ",show li,", column ",show co]

data Program =
  P Id Body
  deriving(Show)

--instance Show Program with
--  show = \(P i b) -> concat ["P\n\n\n",show i,show b]

data Body =
  Body [Local] [Stmt]
  deriving(Show)

data Id        = Id {
    idString::String
  , idLine::Int
  , idColumn::Int
  }
  deriving(Show)

instance Eq Id where
  x == y = idString x == idString y

instance Ord Id where
  x <= y = idString x <= idString y

data Local =
  VarsWithTypeList [([Id],Type)]    |
  Labels [Id]             |
  HeaderBody Header Body |
  Forward Header
  deriving(Show)

data Header =
  ProcHeader {
    pname :: Id
  , pargs :: [Formal]
  }  |
  FuncHeader  {
    fname :: Id
  , fargs :: [Formal]
  , fty :: Type
  }
  deriving(Show)

data PassBy =
  Value     |
  Reference
  deriving(Show,Eq)

type Formal = (PassBy,[Id],Type)

data Type =
  Nil                |
  Int'                |
  Real'               |
  Bool'               |
  Char'               |
  Array ArrSize Type |
  Pointer Type
  deriving(Show,Eq)

data ArrSize =
  Size Int |
  NoSize
  deriving(Show,Eq)

data Stmt =
  Empty                             |
  Equal Int Int LVal Expr           |
  Block [Stmt]                      |
  Call Call                         |
  IfThen Int Int Expr Stmt          |
  IfThenElse Int Int Expr Stmt Stmt |
  While Int Int Expr Stmt           |
  Label Id Stmt                     |
  GoTo Id                           |
  Return                            |
  New Int Int New LVal              |
  Dispose Int Int DispType LVal
  deriving(Show)

data DispType =
  With    |
  Without
  deriving(Show)

type Exprs = [Expr]

data New =
  NewEmpty     |
  NewExpr Expr
  deriving(Show)

data Expr =
 LVal LVal |
 RVal RVal
 deriving(Show,Ord,Eq)

data LVal =
  IdL Id                 |
  Result Int Int      |
  StrLiteral String         |
  LValExpr Int Int LVal Expr |
  LExpr Int Int Expr             |
  LParen LVal
  deriving(Show,Ord,Eq)

data RVal =
  RInt Int           |
  RTrue              |
  RFalse             |
  RReal Double       |
  RChar Char         |
  RParen RVal      |
  RNil               |
  RCall    Call      |
  RPapaki  (Int,Int) LVal    |
  RNot     (Int,Int) Expr      |
  RPos     (Int,Int) Expr      |
  RNeg     (Int,Int) Expr      |
  RPlus    (Int,Int) Expr Expr |
  RMul     (Int,Int) Expr Expr |
  RMinus   (Int,Int) Expr Expr |
  RRealDiv (Int,Int) Expr Expr |
  RDiv     (Int,Int) Expr Expr |
  RMod     (Int,Int) Expr Expr |
  ROr      (Int,Int) Expr Expr |
  RAnd     (Int,Int) Expr Expr |
  REq      (Int,Int) Expr Expr |
  RDiff    (Int,Int) Expr Expr |
  RLess    (Int,Int) Expr Expr |
  RGreater (Int,Int) Expr Expr |
  RGreq    (Int,Int) Expr Expr |
  RSmeq    (Int,Int) Expr Expr
  deriving(Show,Eq,Ord)

data Call =
  CId Id [Expr]
  deriving(Show,Eq,Ord)

parser s = runAlex s parse
lexwrap = (alexMonadScan >>=)

tokenToId :: Token -> Id
tokenToId = \case
  TId string (AlexPn _ line column) -> Id string line column
  _                                 -> error "Shouldn't happen, not id token"

posnToIntInt :: AlexPosn -> (Int,Int)
posnToIntInt (AlexPn _ l c) = (l,c)

posnToLi :: AlexPosn -> Int
posnToLi (AlexPn _ line _) = line
 
posnToCo :: AlexPosn -> Int
posnToCo (AlexPn _ _ column) = column

}
