
-- CHRIS: I had to fork this to fix a bug.
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.LargeWord
-- Copyright   :  (c) Dominic Steinitz 2004
-- License     :  BSD
--
-- Maintainer  :  dominic@steinitz.org
-- Stability   :  experimental
-- Portability :  portable
--
-- Provides Word128, Word192 and Word256 and a way of producing other
-- large words if required.
--
-----------------------------------------------------------------------------

module Frenetic.LargeWord
  ( LargeKey(..)
  , Word96
  , Word128
  , Word160
  , Word192
  , Word224
  , Word256
  , loHalf
  , hiHalf
  ) where

import Data.Word
import Data.Bits
import Numeric
import Data.Char

-- Keys have certain capabilities.

class LargeWord a where
   largeWordToInteger :: a -> Integer
   integerToLargeWord :: Integer -> a
   largeWordPlus :: a -> a -> a
   largeWordAnd :: a -> a -> a
   largeWordOr :: a -> a -> a
   largeWordShift :: a -> Int -> a
   largeWordXor :: a -> a -> a
   largeBitSize :: a -> Int
   largeWordComplement :: a -> a

-- Word8 is a key in the obvious way

instance LargeWord Word8 where
  largeWordToInteger = toInteger
  integerToLargeWord = fromInteger
  largeWordPlus = (+)
  largeWordAnd  = (.&.)
  largeWordOr   = (.|.)
  largeWordShift = shift
  largeWordXor   = xor
  largeBitSize   = bitSize
  largeWordComplement = complement

-- Word16 is a key in the obvious way

instance LargeWord Word16 where
  largeWordToInteger = toInteger
  integerToLargeWord = fromInteger
  largeWordPlus = (+)
  largeWordAnd  = (.&.)
  largeWordOr   = (.|.)
  largeWordShift = shift
  largeWordXor   = xor
  largeBitSize   = bitSize
  largeWordComplement = complement


-- Word32 is a key in the obvious way.

instance LargeWord Word32 where
   largeWordToInteger = toInteger
   integerToLargeWord = fromInteger
   largeWordPlus = (+)
   largeWordAnd = (.&.)
   largeWordOr = (.|.)
   largeWordShift = shift
   largeWordXor = xor
   largeBitSize = bitSize
   largeWordComplement = complement


-- Word64 is a key in the obvious way.

instance LargeWord Word64 where
   largeWordToInteger = toInteger
   integerToLargeWord = fromInteger
   largeWordPlus = (+)
   largeWordAnd = (.&.)
   largeWordOr = (.|.)
   largeWordShift = shift
   largeWordXor = xor
   largeBitSize = bitSize
   largeWordComplement = complement

-- Define larger keys from smaller ones.

data LargeKey a b = LargeKey a b
   deriving (Eq, Ord)

{-# INLINE loHalf #-}
loHalf (LargeKey a b) = a
{-# INLINE hiHalf #-}
hiHalf (LargeKey a b) = b

instance (Ord a, Bits a, LargeWord a, Bits b, LargeWord b) =>
   LargeWord (LargeKey a b) where
      largeWordToInteger (LargeKey lo hi) =
         largeWordToInteger lo + (2^(bitSize lo)) * largeWordToInteger hi
      integerToLargeWord x =
         let (h,l) =  x `quotRem` (2^(bitSize lo))
             (lo,hi) = (integerToLargeWord l, integerToLargeWord h) in
                LargeKey lo hi
      largeWordPlus (LargeKey alo ahi) (LargeKey blo bhi) =
         LargeKey lo' hi' where
            lo' = alo + blo
            hi' = ahi + bhi + if lo' < alo then 1 else 0
      largeWordAnd (LargeKey alo ahi) (LargeKey blo bhi) =
         LargeKey lo' hi' where
            lo' = alo .&. blo
            hi' = ahi .&. bhi
      largeWordOr (LargeKey alo ahi) (LargeKey blo bhi) =
         LargeKey lo' hi' where
            lo' = alo .|. blo
            hi' = ahi .|. bhi
      largeWordXor (LargeKey alo ahi) (LargeKey blo bhi) =
         LargeKey lo' hi' where
            lo' = alo `xor` blo
            hi' = ahi `xor` bhi
      largeWordShift w 0 = w
      largeWordShift (LargeKey lo hi) x =
         if bitSize lo < bitSize hi
            then LargeKey (shift lo x)
                          (shift hi x .|. (shift (conv lo) (x - (bitSize lo))))
            else LargeKey (shift lo x)
                          (shift hi x .|. (conv $ shift lo (x - (bitSize lo))))
         where conv = integerToLargeWord . largeWordToInteger
      largeBitSize ~(LargeKey lo hi) = largeBitSize lo + largeBitSize hi
      largeWordComplement (LargeKey lo hi) = LargeKey (largeWordComplement lo) (largeWordComplement hi)

instance (Ord a, Bits a, LargeWord a, Bits b, LargeWord b) => Show (LargeKey a b) where
    show p = "0x" ++ (showHex (largeWordToInteger p) "")

instance (Ord a, Bits a, LargeWord a, Bits b, LargeWord b) =>
   Num (LargeKey a b) where
      (+) = largeWordPlus
      fromInteger = integerToLargeWord
      abs = error "abs undefined over LargeKey."
      (*) = error "* undefined over LargeKey."
      signum = error "signum undefined over LargeKey."


-- Larger keys are instances of Bits provided their constituents are keys.

instance (Ord a, Bits a, LargeWord a, Bits b, LargeWord b) =>
   Bits (LargeKey a b) where
      (.&.) = largeWordAnd
      (.|.) = largeWordOr
      xor = largeWordXor
      shift = largeWordShift
      bitSize = largeBitSize
      complement = largeWordComplement
      isSigned = error "isSigned undefined over LargeKey."

instance (Ord a, Bits a, Bounded a, Integral a, LargeWord a,
                 Bits b, Bounded b, Integral b, LargeWord b) =>
   Bounded (LargeKey a b) where
      minBound = 0
      maxBound =
         result where
            result =
               fromIntegral $
               (1 + fromIntegral (maxBound `asTypeOf` (boflk result)))*
                  (1 + fromIntegral (maxBound `asTypeOf` (aoflk result))) - 1

aoflk :: (LargeKey a b) -> a
aoflk = error "aoflk undefined."
boflk :: (LargeKey a b) -> b
boflk = error "boflk undefined."

-- TODO(astory): properly derive Ord so that sets don't suck
instance (Ord a, Bits a, LargeWord a, Ord b, Bits b, LargeWord b) =>
   Integral (LargeKey a b) where
      toInteger = largeWordToInteger
      quotRem a b = (fromInteger q, fromInteger r) where
        -- This quotRem is Integer quotRem, so we don't have an infinite loop.
        (q, r) = quotRem (toInteger a) (toInteger b)

instance (Ord a, Bits a, LargeWord a, Ord b, Bits b, LargeWord b) =>
   Real (LargeKey a b) where
   toRational = error "toRational undefined over LargeKey."

instance Enum (LargeKey a b) where
  toEnum = error "toEnum undefined over LargeKey."
  fromEnum = error "fromEnum undefined over LargeKey."

type Word96  = LargeKey Word32 Word64
type Word128 = LargeKey Word64 Word64
type Word160 = LargeKey Word32 Word128
type Word192 = LargeKey Word64 Word128
type Word224 = LargeKey Word32 Word192
type Word256 = LargeKey Word64 Word192
