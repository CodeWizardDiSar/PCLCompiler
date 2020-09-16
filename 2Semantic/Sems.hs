module Sems where
import Control.Monad.Trans.Either
import System.IO as S
import System.Exit
import Common
import InitSymTab (initSymTab)
import LocalsSems 
import ValTypes
import StmtSems
import LLVM.Context
import LLVM.Module
import Emit (codegen,codegen')
import SemsCodegen
import qualified LLVM.AST as AST
import qualified LLVM.AST.Type as T
import qualified LLVM.AST.Constant as C
import qualified LLVM.AST.Float as F
import Data.String.Transform

process :: IO ()
process = sems'

sems' :: IO ()
sems' = do
  c <- S.getContents
  putStrLn c
  parserCases' $ parser c

parserCases' :: Either Error Program -> IO ()
parserCases' = \case 
  Left e    -> die e
  Right ast -> astSems' ast

astSems' :: Program -> IO ()
astSems' ast =
  let runProgramSems = programSems >>> runEitherT >>> runState
  in case runProgramSems ast initState of
    (Right _,(_,_,m,_)) -> codegen' m
    (Left e,_)          -> die e

-- same name of fun inside of other fun?
sems :: IO Program
sems = do
  c <- S.getContents
  putStrLn c
  p <- parserCases $ parser c
  --print p
  return p

parserCases :: Either Error Program -> IO Program
parserCases = \case 
  Left e    -> die e
  Right ast -> astSems ast

astSems :: Program -> IO Program
astSems ast =
  let runProgramSems = programSems >>> runEitherT >>> runState
  in case runProgramSems ast initState of
    (Right _,_) -> return ast
    (Left e,_)  -> die e

programSems :: Program -> Sems ()
programSems (P id body) = do
  modifyMod $ \mod -> mod { AST.moduleName = idToShort id }
  initSymTab
  defineFun "main" T.void [] $ mainCodegen body

idToShort = idString >>> toShortByteString

mainCodegen :: Body -> Sems ()
mainCodegen body = do
  entry <- addBlock "entry"
  setBlock entry
  bodySems body
  retVoid

bodySems :: Body -> Sems ()
bodySems (Body locals stmts) = do
  localsSems (reverse locals) 
  stmtsSems (reverse stmts) 
  checkUnusedLabels

checkUnusedLabels :: Sems ()
checkUnusedLabels = getLabelMap >>= toList >>> (mapM_ $ \case
  (id,False) -> errAtId "Label declared but not used: " id
  _          -> return ())

localsSems :: [Local] -> Sems ()
localsSems locals = mapM_ localSems locals >> checkUndefDclrs

localSems :: Local -> Sems ()
localSems = \case
  VarsWithTypeList vwtl -> varsWithTypeListSemsIR $ reverse vwtl
  Labels ls             -> insToSymTabLabels $ reverse ls
  HeaderBody h b        -> headerBodySems h b
  Forward h             -> forwardSems h

varsWithTypeListSemsIR rvwtl = do
  varsWithTypeListSems rvwtl
  mapM_ cgenVars rvwtl

cgenVars :: ([Id],Type) -> Sems ()
cgenVars (ids,ty) = mapM_ (cgenVar ty) $ reverse ids

cgenVar :: Type -> Id -> Sems ()
cgenVar ty id = do 
  var <- alloca $ toTType ty
  assign (idString id) var

headerBodySems :: Header -> Body -> Sems ()
headerBodySems h b = do
  headerParentSems h
  (e,sms,m,cgen) <- get
  put $ (e,emptySymbolTable:sms,m,cgen)
  headerChildSems h
  bodySems b
  checkResult
  put (e,sms,m,cgen)

stmtsSems :: [Stmt] -> Sems ()
stmtsSems ss = mapM_ stmtSems ss

stmtSems :: Stmt -> Sems ()
stmtSems = \case
  Empty                         -> return ()
  Assignment posn lVal expr     -> do
                                     assignmentSems posn lVal expr
                                     cgenAssign lVal expr 
  Block      stmts              -> stmtsSems $ reverse stmts
  CallS      (id,exprs)         -> callSems id $ reverse exprs
  IfThen     posn e s           -> do
                                     (ty,op) <- exprTypeOper e
                                     boolCases posn "if-then" ty
                                     stmtSems s
  IfThenElse posn e s1 s2       -> do
                                     (ty,op) <- exprTypeOper e
                                     boolCases posn "if-then-else" ty
                                     stmtsSems [s1,s2]
  While      posn e stmt        -> do
                                     (ty,op) <- exprTypeOper e
                                     boolCases posn "while" ty
                                     stmtSems stmt
  Label      lab stmt           -> lookupInLabelMap lab >>= labelCases lab >> stmtSems stmt
  GoTo       lab                -> lookupInLabelMap lab >>= goToCases lab
  Return                        -> return ()
  New        posn new lVal      -> newSems posn new lVal
  Dispose    posn disptype lVal -> disposeSems posn disptype lVal

cgenAssign :: LVal -> Expr -> Sems ()
cgenAssign lVal expr = do
  (_,lValOper) <- lValTypeOper lVal
  (_,exprOper) <- exprTypeOper expr
  store lValOper exprOper

callSems :: Id -> [Expr] -> Sems ()
callSems id exprs = searchCallableInSymTabs id >>= \case
  ProcDclr fs -> formalsExprsMatch id fs exprs
  Proc     fs -> formalsExprsMatch id fs exprs
  _           -> errAtId "Use of function in call statement: " id

assignmentSems :: (Int,Int) -> LVal -> Expr -> Sems ()
assignmentSems posn = \case
  StrLiteral str -> \_ -> errPos posn $ "Assignment to string literal: " ++ str
  lVal           -> lValExprTypes lVal >=> notStrLiteralSems posn

newSems :: (Int,Int) -> New -> LVal -> Sems ()
newSems posn = \case
  NewNoExpr -> lValType >=> newNoExprSems posn
  NewExpr e -> exprLValTypes e >=> newExprSems posn

disposeSems :: (Int,Int) -> DispType -> LVal -> Sems ()
disposeSems posn = \case
  Without -> lValType >=> dispWithoutSems posn
  With    -> lValType >=> dispWithSems posn

exprTypeOper :: Expr -> Sems (Type,AST.Operand)
exprTypeOper = \case
  LVal lval -> lValTypeOper lval
  RVal rval -> rValTypeOper rval

lValTypeOper :: LVal -> Sems (Type,AST.Operand)
lValTypeOper = \case
  IdL         id             -> searchVarInSymTabs id
  Result      posn           -> resultType posn
  StrLiteral  str            -> right $ Array (Size $ length str + 1) CharT
  Indexing    posn lVal expr -> lValExprTypes lVal expr >>= indexingCases posn
  Dereference posn expr      -> exprTypeOper expr >>= dereferenceCases posn
  ParenL      lVal           -> lValType lVal

exprLValTypeOpers expr lVal = do
  eto <- exprTypeOper expr
  lto <- lValTypeOper lVal
  return (eto,lto)

lValExprTypeOpers lVal expr = do
  lto <- lValTypeOper lVal 
  eto <- exprTypeOper expr
  return (lto,eto)

rValTypeOper :: RVal -> Sems (Type,AST.Operand)
rValTypeOper = \case
  IntR    int        -> right (IntT,cons $ C.Int 16 $ toInteger int)
  TrueR              -> right (BoolT,cons $ C.Int 1 1)
  FalseR             -> right (BoolT,cons $ C.Int 1 0)
  RealR   double     -> right (RealT,cons $ C.Float $ F.Double double) --X86_FP80
  CharR   char       -> right (CharT,cons $ C.Int 8 $ toInteger $ ord char)
  ParenR  rVal       -> rValTypeOper rVal
  NilR               -> right (Nil,cons $ C.Null $ ptr VoidType)
  CallR   (id,exprs) -> callType id $ reverse exprs
  Papaki  lVal       -> lValTypeOper lVal >>= \(ty,op) -> right (Pointer ty,op)
  Not     posn expr  -> exprTypeOper expr >>= notCases posn
  Pos     posn expr  -> exprTypeOper expr >>= unaryOpNumCases posn "'+'"
  Neg     posn expr  -> exprTypeOper expr >>= unaryOpNumCases posn "'-'"
  Plus    posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn IntT RealT "'+'"
  Mul     posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn IntT RealT "'*'"
  Minus   posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn IntT RealT "'-'"
  RealDiv posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn RealT RealT "'/'"
  Div     posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpIntCases posn "'div'"
  Mod     posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpIntCases posn "'mod'"
  Or      posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpBoolCases posn "'or'"
  And     posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpBoolCases posn "'and'"
  Eq      posn e1 e2 -> exprsTypeOpers e1 e2 >>= comparisonCases posn "'='"
  Diff    posn e1 e2 -> exprsTypeOpers e1 e2 >>= comparisonCases posn "'<>'"
  Less    posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn BoolT BoolT "'<'"
  Greater posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn BoolT BoolT "'>'"
  Greq    posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn BoolT BoolT "'>='"
  Smeq    posn e1 e2 -> exprsTypeOpers e1 e2 >>= binOpNumCases posn BoolT BoolT "'<='"

exprsTypeOpers exp1 exp2 = mapM exprTypeOper [exp1,exp2]

callType :: Id -> [Expr] -> Sems (Type,AST.Operand)
callType id exprs = do
  callable <- searchCallableInSymTabs id 
  case callable of
    FuncDclr fs t -> formalsExprsMatch id fs exprs >> right (t,undefined)
    Func  fs t    -> formalsExprsMatch id fs exprs >> right (t,undefined)
    _             -> errAtId "Use of procedure where a return value is required: " id

formalsExprsMatch :: Id -> [Frml] -> [Expr] -> Sems ()
formalsExprsMatch id fs exprs = do
  types <- mapM (exprTypeOper >=> return . fst) exprs 
  formalsExprsTypesMatch 1 id (formalsToTypes fs) types
