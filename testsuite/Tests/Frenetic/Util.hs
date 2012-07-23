module Tests.Frenetic.Util
  ( linear
  , linearHosts
  ) where

import qualified Data.Set as Set
import qualified Data.Map as Map
import Frenetic.NetCore.API
import Frenetic.Pattern
import qualified Frenetic.PolicyGen as PG
import Frenetic.Slices.Slice
import Frenetic.Topo
import qualified Frenetic.TopoGen as TG

import Data.Graph.Inductive.Graph

linear :: Integral n => [[n]] -> (Topo, [Policy])
linear nodess = (topo, policies) where
  nodess' = map Set.fromList nodess
  max = maximum . concat . map Set.toList $ nodess'
  topo = TG.linear (max + 1)
  policies = map mkPolicy nodess'
  mkPolicy nodes = PG.simuFlood $ subgraph (Set.map fromIntegral nodes) topo

linearHosts :: Integral n => [[n]] -> (Topo, [(Slice, Policy)])
linearHosts nodess = (topo,
                      map (\ns -> (mkSlice ns, mkPolicy ns)) nodess')
  where
  nodess' = map Set.fromList nodess
  max = maximum . concat . map Set.toList $ nodess'
  topo = TG.linearHosts (max + 1)
  mkPolicy nodes = PG.simuFlood $ subgraph (wholeSlice nodes) topo
  mkSlice :: Integral n => Set.Set n -> Slice
  mkSlice nodes = Slice (getAllIntLocs nodes)
                        (Map.fromList $ zip (Set.toList $ getAllHostLocs nodes)
                                            (repeat top))
                        (Map.fromList $ zip (Set.toList $ getAllHostLocs nodes)
                                            (repeat top))
  wholeSlice nodes = Set.map fromIntegral $ Set.union switches hosts where
    switches = nodes
    hosts = Set.unions . Set.toList .
            Set.map (\n -> Set.fromList [100 + 10 * n, 101 + 10 * n]) $
            nodes
  getAllIntLocs :: Integral n => Set.Set n -> Set.Set Loc
  getAllIntLocs = Set.unions . map getIntLocs . map fromIntegral . Set.toList
  getIntLocs n = Set.fromList [Loc n 1, Loc n 2]
  getAllHostLocs :: Integral n => Set.Set n -> Set.Set Loc
  getAllHostLocs = Set.unions . map getHostLocs . map fromIntegral . Set.toList
  getHostLocs n = Set.fromList [Loc n 3, Loc n 4]