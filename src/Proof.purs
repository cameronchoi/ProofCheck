module Proof
    ( Deduction(..)
    , Proof(..)
    , empty
    , isEmpty
    , addDeduction
    , renderReason
    , getAssumptions
    ) where

import Prelude
    ( (<>), (<$>), ($), (>>>), (==), (/=), (+), (-)
    , show, bind, map, pure
    )
import Data.String.Common (joinWith)
import Data.Set (Set)
import Data.Set as Set
import Data.Either (Either(..))
import Data.Either as E
import Data.Maybe (Maybe(..))
import Data.Array as A
import Data.Traversable (traverse)
import Data.Foldable (length)

import WFF (WFF)
import Deduction

data Deduction = Deduction
    { assumptions :: Set Int
    , deduction :: WFF String
    , rule :: DeductionRule
    , reasons :: Array Int
    }

data Proof = Proof
    { lines :: Array Deduction
    , assumptions :: Set Int
    }

renderReason :: Deduction -> String
renderReason (Deduction d) =
    renderRule d.rule
    <> " "
    <> joinWith "," (show <$> d.reasons)

empty :: Proof
empty = Proof
    { lines : []
    , assumptions : Set.empty
    }

isEmpty :: Proof -> Boolean
isEmpty (Proof p) = length p.lines == 0

pack :: Deduction ->
    {formula :: WFF String, isAssumption :: Boolean, assumptions :: Set Int}
pack (Deduction d) =
    { formula : d.deduction
    , isAssumption : isAssumption d.rule
    , assumptions : d.assumptions
    }

addDeduction :: Deduction -> Proof -> Either String Proof
addDeduction (Deduction d) (Proof p) = do
    antes <- E.note "Invalid line number in reason"
        $ traverse ((_ - 1) >>> A.index p.lines >>> map pack) d.reasons
    assumptions <- matchDeduction antes d.deduction d.rule
    case assumptions of
        Just x | x == d.assumptions -> Right $ Proof $
            p { lines = p.lines <> [Deduction d] }
        Just _ -> Left "Incorrect assumptions"
        _ | Set.size d.assumptions /= 1 -> Left "Wrong number of assumptions"
        _ | d.assumptions `Set.subset` p.assumptions ->
            Left "Assumption number already in use"
        _ -> Right $ Proof $
            { lines : p.lines <> [Deduction d]
            , assumptions : p.assumptions `Set.union` d.assumptions
            }

getNextUnused :: Set Int -> Int
getNextUnused s = case Set.findMin $ plus `Set.difference` s of
    Nothing -> 1
    Just m -> m
    where
        plus = Set.insert 1 $ Set.map (_ + 1) s

getAssumptions :: Deduction -> Proof -> Either String (Set Int)
getAssumptions (Deduction d) (Proof p) = do
    antes <- E.note "Invalid line number in reason"
        $ traverse ((_ - 1) >>> A.index p.lines >>> map pack) d.reasons
    assumptions <- matchDeduction antes d.deduction d.rule
    case assumptions of
        Just s -> pure s
        Nothing -> pure $ Set.singleton $ getNextUnused p.assumptions
