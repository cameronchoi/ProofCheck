module Json.Symbol
    ( toJson
    , fromJson
    , allFromJson
    ) where

import Prelude (($), (<>), (<$), (<$>), (&&), bind, pure)
import Data.Foldable (foldM)
import Data.Argonaut.Core (Json)
import Data.Argonaut.Core as AC
import Foreign.Object as O
import Data.Tuple (Tuple(..))
import Data.Either (Either(..))
import Data.Either as E

import Parser (parseSymbol)
import Json.WFF as JW
import Symbol (Symbol(..), SymbolMap)
import Symbol as S

toJson :: Symbol -> Json
toJson (UnarySymbol u) = AC.fromObject $ O.fromFoldable
    [ Tuple "symbol" $ AC.fromString u.operator.symbol
    , Tuple "prop" $ AC.fromString "A"
    , Tuple "definition" $ JW.toJson $ "A" <$ u.definition
    ]
toJson (BinarySymbol b) = AC.fromObject $ O.fromFoldable
    [ Tuple "symbol" $ AC.fromString b.operator.symbol
    , Tuple "propa" $ AC.fromString "A"
    , Tuple "propb" $ AC.fromString "B"
    , Tuple "definition" $
        JW.toJson $ (if _ then "A" else "B") <$> b.definition
    ]

fromObject :: SymbolMap -> O.Object Json -> Either String Symbol
fromObject m o | O.member "prop" o = do
    symJson <- E.note "Symbol is missing name" $ O.lookup "symbol" o
    symbol <- AC.caseJsonString (Left "Symbol name is not a string")
        parseSymbol symJson
    propJson <- E.note "Symbol is missing prop" $ O.lookup "prop" o
    prop <- AC.caseJsonString (Left "Symbol prop is not a string")
        Right propJson
    defJson <- E.note "Symbol is missing definition" $ O.lookup "definition" o
    definition <- JW.fromJson m defJson
    S.makeUnary prop symbol definition
fromObject m o | (O.member "propa" && O.member "propb") o = do
    symJson <- E.note "Symbol is missing name" $ O.lookup "symbol" o
    symbol <- AC.caseJsonString (Left "Symbol name is not a string")
        parseSymbol symJson
    propaJson <- E.note "Symbol is missing propa" $ O.lookup "propa" o
    propa <- AC.caseJsonString (Left "Symbol propa is not a string")
        Right propaJson
    propbJson <- E.note "Symbol is missing propb" $ O.lookup "propb" o
    propb <- AC.caseJsonString (Left "Symbol propb is not a string")
        Right propbJson
    defJson <- E.note "Symbol is missing definition" $ O.lookup "definition" o
    definition <- JW.fromJson m defJson
    S.makeBinary propa propb symbol definition
fromObject _ _ = Left "Symbol is missing propositions"

fromJson :: SymbolMap -> Json -> Either String Symbol
fromJson m = AC.caseJsonObject (Left "Symbol definition is not an object") $
    fromObject m

type Symbols = { symbols :: Array Symbol, symbolMap :: SymbolMap }

addOne :: Symbols -> Json -> Either String Symbols
addOne s j = do
    newSym <- fromJson s.symbolMap j
    newMap <- S.updateMap s.symbolMap newSym
    pure { symbols : s.symbols <> [newSym], symbolMap : newMap }

allFromJson :: Json -> Either String Symbols
allFromJson = AC.caseJsonArray (Left "Symbols are not in a list")
    (foldM addOne { symbols : [], symbolMap : S.defaultMap })
