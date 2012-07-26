module Frenetic.Util
  ( newLift
  , newLift2
  , Set
  , Map
  , module Control.Concurrent.Chan
  , module Control.Concurrent
  , module System.Log.Logger
  , mergeChan
  ) where

import System.Log.Logger hiding (Priority)
import Control.Concurrent.Chan
import Control.Concurrent
import Control.Monad
import Data.Set (Set)
import Data.Map (Map)
import Control.Newtype

newLift :: (Newtype n o) => (o -> o) -> n -> n
newLift f = pack . f . unpack

newLift2 :: (Newtype n o) => (o -> o -> o) -> n -> n -> n
newLift2 f n1 n2 = pack (f (unpack n1) (unpack n2))

mergeChan :: Chan a -> Chan b -> IO (Chan (Either a b))
mergeChan chan1 chan2 = do
  mergedChan <- newChan
  forkIO $ forever $ do
    v <- readChan chan1
    writeChan mergedChan (Left v)
  forkIO $ forever $ do
    v <- readChan chan2
    writeChan mergedChan (Right v)
  return mergedChan