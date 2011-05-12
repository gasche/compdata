{-# LANGUAGE TemplateHaskell, TypeOperators, MultiParamTypeClasses,
  FlexibleInstances, FlexibleContexts, UndecidableInstances, GADTs,
  KindSignatures #-}
--------------------------------------------------------------------------------
-- |
-- Module      :  Examples.MultiParam.EvalAlgM
-- Copyright   :  (c) 2011 Patrick Bahr, Tom Hvitved
-- License     :  BSD3
-- Maintainer  :  Tom Hvitved <hvitved@diku.dk>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- Monadic Expression Evaluation without PHOAS
--
-- The example illustrates how to use generalised parametric compositional
-- data types to implement a small expression language, with a sub language of
-- values, and a monadic evaluation function mapping expressions to values.
-- The lack of PHOAS means that -- unlike the example in
-- 'Examples.MultiParam.EvalM' -- a monadic algebra can be used.
--
--------------------------------------------------------------------------------

module Examples.MultiParam.EvalAlgM where

import Data.Comp.MultiParam
import Data.Comp.MultiParam.Show ()
import Data.Comp.MultiParam.HDitraversable
import Data.Comp.MultiParam.Derive
import Control.Monad (liftM)

-- Signature for values and operators
data Value :: (* -> *) -> (* -> *) -> * -> * where
              Const :: Int -> Value a e Int
              Pair :: e i -> e j -> Value a e (i,j)
data Op :: (* -> *) -> (* -> *) -> * -> * where
           Add :: e Int -> e Int -> Op a e Int
           Mult :: e Int -> e Int -> Op a e Int
           Fst :: e (i,j) -> Op a e i
           Snd :: e (i,j) -> Op a e j

-- Signature for the simple expression language
type Sig = Op :+: Value

-- Derive boilerplate code using Template Haskell
$(derive [instanceHDifunctor, instanceHTraversable, instanceHFoldable,
          instanceEqHD, instanceShowHD, smartConstructors]
         [''Value, ''Op])

-- Monadic term evaluation algebra
class EvalM f v where
  evalAlgM :: AlgM Maybe f (Term v)

$(derive [liftSum] [''EvalM])

-- Lift the monadic evaluation algebra to a monadic catamorphism
evalM :: (HDitraversable f Maybe (Term v), EvalM f v)
         => Term f i -> Maybe (Term v i)
evalM = cataM evalAlgM

instance (Value :<: v) => EvalM Value v where
  evalAlgM (Const n) = return $ iConst n
  evalAlgM (Pair x y) = return $ iPair x y

instance (Value :<: v) => EvalM Op v where
  evalAlgM (Add x y)  = do n1 <- projC x
                           n2 <- projC y
                           return $ iConst $ n1 + n2
  evalAlgM (Mult x y) = do n1 <- projC x
                           n2 <- projC y
                           return $ iConst $ n1 * n2
  evalAlgM (Fst v)    = liftM fst $ projP v
  evalAlgM (Snd v)    = liftM snd $ projP v

projC :: (Value :<: v) => Term v Int -> Maybe Int
projC v = case project v of
            Just (Const n) -> return n
            _ -> Nothing

projP :: (Value :<: v) => Term v (i,j) -> Maybe (Term v i, Term v j)
projP v = case project v of
            Just (Pair x y) -> return (x,y)
            _ -> Nothing

-- Example: evalMEx = Just (iConst 5)
evalMEx :: Maybe (Term Value Int)
evalMEx = evalM ((iConst 1) `iAdd` (iConst 2 `iMult` iConst 2) :: Term Sig Int)