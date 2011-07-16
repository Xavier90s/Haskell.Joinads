> --------------------------------------------------------------------------------
> -- Preprocessor for the joinads 'docase' notation.
> -- For more information see: http://www.cl.cam.ac.uk/~tp322/papers/docase.html 
> -- 
> -- The implementation is based on 'arrowp' preprocessor created by Ross
> -- Paterson (available at http://hackage.haskell.org/package/arrowp)
> -- 
> -- This file implements the main function. It parses the Haskell source code
> -- (using the 'Parser.ly' parser, translates it to 'docase'-free expressions
> -- and then generates the translated Haskell to the specified output file.
> --
> -- All changes in Lexer.hs and Parser.ly that are related to the 'docase'
> -- extension are marked with "added for joinads".
> -----------------------------------------------------------------------------

> module Main (main) where

> import Data.List
> import System.Console.GetOpt
> import System.Environment
> import System.Exit
> import System.IO

> import Language.Haskell.ParseMonad
> import Language.Haskell.Syntax
> import Language.Haskell.Pretty

> import Parser

> data Flag = ParsePretty PPLayout   -- pretty print in this style
>           | Help                   -- give short usage info

> usage :: String -> String
> usage progName = unlines [
>	"usage: " ++ progName ++
>		" [OPTION]... [FILENAME] [SOURCE] [DEST]",
>	"Read arrow notation from SOURCE (derived from FILENAME) and write",
>	"standard Haskell to DEST.",
>	"If no FILENAME, use SOURCE as the original name.",
>	"If no DEST or if DEST is `-', write to standard output.",
>	"If no SOURCE or if SOURCE is `-', read standard input."
>   ]

> sourceError :: SrcLoc -> String -> IO a
> sourceError loc mesg = do
>   hPutStrLn stderr
>	(srcFilename loc ++ ":" ++ show (srcLine loc) ++ ": " ++ mesg ++
>	" in column " ++ show (srcColumn loc))
>   exitFailure

> programError :: String -> IO a
> programError mesg = do
>   progName <- getProgName
>   hPutStrLn stderr (progName ++ ": " ++ mesg)
>   exitFailure

> usageError :: String -> IO a
> usageError mesg = do
>   progName <- getProgName
>   programError (mesg ++
>	 "Try `" ++ progName ++ " --help' for more information.")

> options :: [OptDescr Flag]
> options =
>    [ Option ['p']  ["pretty"]  (OptArg pStyle "STYLE")
>	("pretty print in STYLE[" ++
>	 concat (intersperse "|" (map fst styles)) ++
>	 "](default = " ++ fst (head styles) ++ ")"),
>      Option ['h','?'] ["help"] (NoArg Help) "display this help and exit"]

Available styles: first is default

> styles :: [(String, PPLayout)]
> styles = [
>	("offside",	PPOffsideRule),
>	("semicolon",	PPSemiColon),
>	("inline",	PPInLine),
>	("none",	PPNoLayout)
>   ]

> pStyle :: Maybe String -> Flag
> pStyle Nothing = ParsePretty defaultStyle
> pStyle (Just s) = ParsePretty (lookupStyle s)

> defaultStyle :: PPLayout
> defaultStyle = snd (head styles)

> lookupStyle :: String -> PPLayout
> lookupStyle prefix =
>	head ([s | (n, s) <- styles, prefix `isPrefixOf` n] ++ [defaultStyle])

> main :: IO ()
> main = do cmdline <- getArgs
>           mainHugs cmdline

> mainHugs :: [String] -> IO ()
> mainHugs cmdline =
>    case getOpt Permute options cmdline of
>       (flags, args, []) -> do
>	    action <- case flags of
>		[]  -> return (ParsePretty defaultStyle)
>		[f] -> return f
>		_   -> usageError "too many options\n"
>	    (origName, inName, outName) <- case args of
>		[]      -> return ("-","-","-")
>		[i]     -> return ( i , i ,"-")
>		[i,o]   -> return ( i , i , o )
>		[n,i,o] -> return ( n , i , o )
>		_       -> usageError "too many arguments\n"
>	    let mode = defaultParseMode {parseFilename = origName}
>	    inp <- if inName == "-" then getContents else
>		   readFile inName `catch` \_err ->
>			programError ("can't read `" ++ inName ++ "'")
>	    outH <- if outName == "-" then return stdout else
>		    openFile outName WriteMode `catch` \_err ->
>			programError ("can't write to `" ++ outName ++ "'")
>	    outp <- case action of
>		ParsePretty layout -> case parseModuleWithMode mode inp of
>			ParseOk mod ->
>				return $ prettyPrintWithMode defaultMode{
>						layout = layout,
>						linePragmas = True
>					} mod
>			ParseFailed loc err -> sourceError loc err
>		Help -> do
>			progName <- getProgName
>			return $ usageInfo (usage progName) options
>	    hPutStrLn outH ( -- "{-# LANGUAGE MonadComprehensions #-}\n" ++ 
>                      outp)
>       (_,     _,    errors) -> usageError (concat errors)
