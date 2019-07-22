{
  module Lexer (main) where
}

%wrapper "basic"

$digit  = [0-9]
$letter = [A-Za-z]
$special=[\.\;\,\$\|\*\+\?\#\~\-\{\}\(\)\^\/\_\\\@]


@id = [A-Za-z][A-Za-z_]*
@intconst = $digit+
@realconst =  $digit+\.$digit+
           |  $digit+\.$digit+e$digit+
           |  $digit+\.$digit+e\+$digit+
           |  $digit+\.$digit+e\-$digit+
@stringconst = \"[$printable # [\"]]\"

tokens :-

  $white* ;
  and                   {TAnd}
  array                 {TArray}
  begin                 {TBegin}
  boolean               {TBoolean}
  char                  {TChar}
  dispose               {TDispose}
  div                   {TDiv}
  do                    {TDo}
  else                  {TElse}
  end                   {TEnd}
  false                 {TFalse}
  forward               {TForward}
  function              {TFunction}
  goto                  {TGoto}
  if                    {TIf}
  integer               {TInteger}
  label                 {TLabel}
  mod                   {TMod}
  new                   {TNew}
  nil                   {TNil}
  not                   {TNot}
  of                    {TOf}
  or                    {TOr}
  procedure             {TProcedure}
  program               {TProgram}
  real                  {TReal}
  result                {TResult}
  return                {TReturn}
  then                  {TThen}
  true                  {TTrue}
  var                   {TVar}
  while                 {TWhile}
  @id                   {TId}
  @intconst             {TIntconst}
  @realconst            {TRealconst}
  @stringconst          {TStringconst}