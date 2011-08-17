{-# LANGUAGE OverloadedStrings, TypeSynonymInstances, FlexibleInstances #-}

{- |
   Module      : Data.GraphViz.Printing
   Description : Helper functions for converting to Dot format.
   Copyright   : (c) Ivan Lazar Miljenovic
   License     : 3-Clause BSD-style
   Maintainer  : Ivan.Miljenovic@gmail.com

   This module defines simple helper functions for use with
   "Text.PrettyPrint".  It also re-exports all the pretty-printing
   combinators from that module.

   Note that the 'PrintDot' instances for 'Bool', etc. match those
   specified for use with Graphviz.

   You should only be using this module if you are writing custom node
   types for use with "Data.GraphViz.Types".  For actual printing of
   code, use @'Data.GraphViz.Types.printDotGraph'@ (which produces a
   'Text' value).

   The Dot language specification specifies that any identifier is in
   one of four forms:

       * Any string of alphabetic ([a-zA-Z\\200-\\377]) characters,
         underscores ('_') or digits ([0-9]), not beginning with a
         digit;

       * a number [-]?(.[0-9]+ | [0-9]+(.[0-9]*)? );

       * any double-quoted string (\"...\") possibly containing
         escaped quotes (\\\");

       * an HTML string (\<...\>).

   (Note that the first restriction is referring to a byte-by-byte
   comparison using octal values; when using UTF-8 this corresponds to
   all characters @c@ where @ord c >= 128@.)

   Due to these restrictions, you should only use 'text' when you are
   sure that the 'Text' in question is static and quotes are
   definitely needed/unneeded; it is better to use the 'Text'
   instance for 'PrintDot'.  For more information, see the
   specification page:
      <http://graphviz.org/doc/info/lang.html>
-}
module Data.GraphViz.Printing
    ( module Text.PrettyPrint.Leijen.Text.Monadic
    , DotCode
    , renderDot -- Exported for Data.GraphViz.Types.printSGID
    , PrintDot(..)
    , unqtText
    , dotText
    , printIt
    , addQuotes
    , unqtEscaped
    , printEscaped
    , wrap
    , commaDel
    , printField
    , angled
    , fslash
    ) where

import Data.GraphViz.Util
import Data.GraphViz.State
-- To avoid orphan instances and cyclic imports
import Data.GraphViz.Attributes.ColorScheme

-- Only implicitly import and re-export combinators.
import Text.PrettyPrint.Leijen.Text.Monadic hiding ( SimpleDoc(..)
                                                   , renderPretty
                                                   , renderCompact
                                                   , displayT
                                                   , displayIO
                                                   , putDoc
                                                   , hPutDoc
                                                   , Pretty(..)
                                                   , bool
                                                   , string)
import qualified Text.PrettyPrint.Leijen.Text.Monadic as PP
import qualified Data.Text.Lazy as T
import Data.Text.Lazy(Text)

import Data.Char(toLower)
import qualified Data.Set as Set
import Data.Word(Word8, Word16)
import Control.Monad(ap)
import Control.Monad.Trans.State

-- -----------------------------------------------------------------------------

-- | A type alias to indicate what is being produced.
type DotCode = State GraphvizState Doc

instance Show DotCode where
  showsPrec d = showsPrec d . renderDot

-- | Correctly render Graphviz output.
renderDot :: DotCode -> Text
renderDot = PP.displayT . PP.renderPretty 0.4 80
            . flip evalState initialState

-- | A class used to correctly print parts of the Graphviz Dot language.
--   Minimal implementation is 'unqtDot'.
class PrintDot a where
  -- | The unquoted representation, for use when composing values to
  --   produce a larger printing value.
  unqtDot :: a -> DotCode

  -- | The actual quoted representation; this should be quoted if it
  --   contains characters not permitted a plain ID String, a number
  --   or it is not an HTML string.  Defaults to 'unqtDot'.
  toDot :: a -> DotCode
  toDot = unqtDot

  -- | The correct way of representing a list of this value when
  --   printed; not all Dot values require this to be implemented.
  --   Defaults to Haskell-like list representation.
  unqtListToDot :: [a] -> DotCode
  unqtListToDot = list . mapM unqtDot

  -- | The quoted form of 'unqtListToDot'; defaults to wrapping double
  --   quotes around the result of 'unqtListToDot' (since the default
  --   implementation has characters that must be quoted).
  listToDot :: [a] -> DotCode
  listToDot = dquotes . unqtListToDot

-- | Convert to DotCode; note that this has no indentation, as we can
--   only have one of indentation and (possibly) infinite line lengths.
printIt :: (PrintDot a) => a -> Text
printIt = renderDot . toDot

instance PrintDot Int where
  unqtDot = int

instance PrintDot Integer where
  unqtDot = text . T.pack . show

instance PrintDot Word8 where
  unqtDot = int . fromIntegral

instance PrintDot Word16 where
  unqtDot = int . fromIntegral

instance PrintDot Double where
  -- If it's an "integral" double, then print as an integer.  This
  -- seems to match how Graphviz apps use Dot.
  unqtDot d = if d == fromIntegral di
              then int di
              else double d
      where
        di = round d

  toDot d = if any ((==) 'e' . toLower) $ show d
            then dquotes ud
            else ud
    where
      ud = unqtDot d

  unqtListToDot = hcat . punctuate colon . mapM unqtDot

  listToDot [d] = toDot d
  listToDot ds  = dquotes $ unqtListToDot ds

instance PrintDot Bool where
  unqtDot True  = text "true"
  unqtDot False = text "false"

instance PrintDot Char where
  unqtDot = char

  toDot = qtChar

  unqtListToDot = unqtDot . T.pack

  listToDot = toDot . T.pack

instance PrintDot Text where
  unqtDot = unqtString

  toDot = qtString

-- | For use with @OverloadedStrings@ to avoid ambiguous type variable errors.
unqtText :: Text -> DotCode
unqtText = unqtDot

-- | For use with @OverloadedStrings@ to avoid ambiguous type variable errors.
dotText :: Text -> DotCode
dotText = toDot

-- | Check to see if this 'Char' needs to be quoted or not.
qtChar :: Char -> DotCode
qtChar c
  | restIDString c = char c -- Could be a number as well.
  | otherwise      = dquotes $ char c

needsQuotes :: Text -> Bool
needsQuotes str
  | T.null str      = True
  | isKeyword str   = True
  | isIDString str  = False
  | isNumString str = False
  | otherwise       = True

addQuotes :: Text -> DotCode -> DotCode
addQuotes = bool id dquotes . needsQuotes

-- | Escape quotes in Strings that need them.
unqtString     :: Text -> DotCode
unqtString ""  = empty
unqtString str = unqtEscaped [] str -- no quotes? no worries!

-- | Escape quotes and quote Texts that need them (including keywords).
qtString :: Text -> DotCode
qtString = printEscaped []

instance (PrintDot a) => PrintDot [a] where
  unqtDot = unqtListToDot

  toDot = listToDot

wrap       :: DotCode -> DotCode -> DotCode -> DotCode
wrap b a d = b <> d <> a

commaDel     :: (PrintDot a, PrintDot b) => a -> b -> DotCode
commaDel a b = unqtDot a <> comma <> unqtDot b

printField     :: (PrintDot a) => Text -> a -> DotCode
printField f v = text f <> equals <> toDot v

-- | Escape the specified chars as well as @\"@.
unqtEscaped    :: [Char] -> Text -> DotCode
unqtEscaped cs = text . addEscapes cs

-- | Escape the specified chars as well as @\"@ and then wrap the
--   result in quotes.
printEscaped        :: [Char] -> Text -> DotCode
printEscaped cs str = addQuotes str' $ text str'
  where
    str' = addEscapes cs str

-- | Ensure the provided characters are all escaped.  Note that we
--   cannot convert to 'DotCode' immediately because 'printEscaped'
--   needs to pass the result from this to 'addQuotes' to determine if
--   it needs to be quoted or not.
addEscapes    :: [Char] -> Text -> Text
addEscapes cs = foldr escape T.empty . withNext
  where
    cs' = Set.fromList $ quote : slash : cs
    slash = '\\'
    quote = '"'
    escape (c,c') str
      | c == slash && c' `Set.member` escLetters = c `T.cons` str
      | c `Set.member` cs'                       = slash `T.cons` (c `T.cons` str)
      | c == '\n'                                = slash `T.cons` ('n' `T.cons` str)
      | otherwise                                = c `T.cons` str

    -- When a slash precedes one of these characters, don't escape the slash.
    escLetters = Set.fromList ['N', 'G', 'E', 'T', 'H', 'L', 'n', 'l', 'r']

    -- Need to check subsequent characters when escaping slashes, but
    -- don't want to lose the last character when zipping, so append a space.
    withNext ""  = []
    withNext str = T.zip `ap` ((`T.snoc` ' ') . T.tail) $ str

angled :: DotCode -> DotCode
angled = wrap langle rangle

fslash :: DotCode
fslash = char '/'

-- -----------------------------------------------------------------------------
-- These instances are defined here to avoid cyclic imports and orphan instances

instance PrintDot ColorScheme where
  unqtDot cs = do setColorScheme cs
                  case cs of
                    X11       -> unqtText "X11"
                    Brewer bs -> unqtDot bs

instance PrintDot BrewerScheme where
  unqtDot (BScheme n l) = unqtDot n <> unqtDot l

instance PrintDot BrewerName where
  unqtDot Accent   = unqtText "accent"
  unqtDot Blues    = unqtText "blues"
  unqtDot Brbg     = unqtText "brbg"
  unqtDot Bugn     = unqtText "bugn"
  unqtDot Bupu     = unqtText "bupu"
  unqtDot Dark2    = unqtText "dark2"
  unqtDot Gnbu     = unqtText "gnbu"
  unqtDot Greens   = unqtText "greens"
  unqtDot Greys    = unqtText "greys"
  unqtDot Oranges  = unqtText "oranges"
  unqtDot Orrd     = unqtText "orrd"
  unqtDot Paired   = unqtText "paired"
  unqtDot Pastel1  = unqtText "pastel1"
  unqtDot Pastel2  = unqtText "pastel2"
  unqtDot Piyg     = unqtText "piyg"
  unqtDot Prgn     = unqtText "prgn"
  unqtDot Pubu     = unqtText "pubu"
  unqtDot Pubugn   = unqtText "pubugn"
  unqtDot Puor     = unqtText "puor"
  unqtDot Purd     = unqtText "purd"
  unqtDot Purples  = unqtText "purples"
  unqtDot Rdbu     = unqtText "rdbu"
  unqtDot Rdgy     = unqtText "rdgy"
  unqtDot Rdpu     = unqtText "rdpu"
  unqtDot Rdylbu   = unqtText "rdylbu"
  unqtDot Rdylgn   = unqtText "rdylgn"
  unqtDot Reds     = unqtText "reds"
  unqtDot Set1     = unqtText "set1"
  unqtDot Set2     = unqtText "set2"
  unqtDot Set3     = unqtText "set3"
  unqtDot Spectral = unqtText "spectral"
  unqtDot Ylgn     = unqtText "ylgn"
  unqtDot Ylgnbu   = unqtText "ylgnbu"
  unqtDot Ylorbr   = unqtText "ylorbr"
  unqtDot Ylorrd   = unqtText "ylorrd"

