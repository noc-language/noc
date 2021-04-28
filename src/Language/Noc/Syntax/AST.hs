module Language.Noc.Syntax.AST
  ( parseNoc,
    parseNocFile,
    ParseError,
    Expr,
    Atom (QuoteAtom, WordAtom, FloatAtom,StringAtom),
    Program,
    Declaration (..),
    REPLInput (DeclInput, ExprInput),
  )
where

----------------------- Modules --------------------------------------------------
import Language.Noc.Syntax.Lexer
import Text.Parsec
import Text.Parsec.String (Parser, parseFromFile)

----------------------- Atoms Parser ----------------------------------------------
data Atom = QuoteAtom Expr | WordAtom String | FloatAtom Double | StringAtom String deriving (Show, Eq)

type Expr = [Atom]

word :: Parser Atom
word = WordAtom <$> identifier

strLiteral :: Parser Atom
strLiteral = StringAtom <$> stringLiteral

number :: Parser Atom
number = FloatAtom . either fromIntegral id <$> naturalOrFloat

quote :: Parser Atom
quote = QuoteAtom <$> (brackets stack)

stack :: Parser Expr
stack = many $ lexeme (quote <|> number <|> strLiteral <|> word)

----------------------- Declaration Parser ------------------------------------------
data Declaration = Declaration {declName :: String, declVal :: Expr} deriving (Show, Eq)

type Program = [Declaration]

manyTill1 :: Parser Char -> Parser String -> Parser String
manyTill1 p pend = (:) <$> p <*> (manyTill p pend)
               
function :: Parser Declaration
function = do
  lexeme $ reserved "def"
  name <- lexeme $ (:) <$> (letter <|> char '_') <*> (manyTill1 (alphaNum <|> char '\'' <|> char '_') (whiteSpace >> symbol "="))
  content <- (lexeme $ braces $ (whiteSpace *> stack))
  pure $ Declaration name content

program :: Parser Program
program = whiteSpace *> (many function) <* eof

----------------------- REPL Parser -------------------------------------------------
data REPLInput = DeclInput Declaration | ExprInput Expr deriving (Show,Eq)

replFunction :: Parser REPLInput
replFunction = (function <* eof) >>= (pure . DeclInput)

replExpression :: Parser REPLInput
replExpression = (whiteSpace *> stack) >>= (pure . ExprInput)

----------------------- Parse Functions ----------------------------------------------
parseNoc :: String -> Either ParseError REPLInput
parseNoc expr = parse (replFunction <|> replExpression) "" expr

parseNocFile :: String -> IO (Either ParseError Program)
parseNocFile path = parseFromFile program path