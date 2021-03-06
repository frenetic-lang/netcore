module Frenetic.Slices.Sat
  ( compiledCorrectly
  , separate
  , breaksObserves
  , breaksForwards
  , breaksForwards2
  , multipleVlanEdge
  , unconfinedDomain
  , unconfinedRange
  , sharedIO
  , sharedInput
  , sharedOutput
  ) where

import qualified Data.Map as Map
import qualified Data.Set as Set
import Nettle.OpenFlow.Match (ofpVlanNone)
import Frenetic.NetCore.Short
import Frenetic.NetCore.Types
import Frenetic.Sat
import Frenetic.Slices.Slice
import Frenetic.Topo
import Frenetic.Z3

noVlan :: Z3Packet -> BoolExp
noVlan p = Equals (vlan p) (Primitive ofpVlanNone)

p   = Z3Packet "p"
p'  = Z3Packet "pp"
p'' = Z3Packet "ppp"
q   = Z3Packet "q"
q'  = Z3Packet "qq"
q'' = Z3Packet "qqq"
r   = Z3Packet "r"
r'  = Z3Packet "rr"

v   = Z3Int "v"
v'  = Z3Int "vv"
v'' = Z3Int "vvv"

qid = Z3Int "qid"


doCheck consts assertions = check $ Input setUp consts assertions
getConsts packets ints = map (\pkt -> DeclConst (ConstPacket pkt)) packets ++
                         map (\int -> DeclConst (ConstInt int)) ints

-- | Verify that source has compiled correctly to target under topo and slice.
compiledCorrectly :: Graph -> Slice -> Policy -> Policy -> IO Bool
compiledCorrectly topo slice source target = do
  fmap not failure where
  slice' = realSlice slice
  cases =  [ unconfinedDomain topo  slice' target
           , unconfinedRange topo slice' target
           , multipleVlanEdge topo target
           -- Note that in these cases we need to include information about the
           -- slice when we test that the target simulates the source so that in
           -- those cases we can excuse the target from simulating on packets
           -- that aren't in the slice.
           , breaksObserves  topo (Just slice) source target
           , breaksObserves  topo Nothing target source
           , breaksForwards  topo (Just slice) source target
           , breaksForwards  topo Nothing target source
           , breaksForwards2 topo (Just slice) source target
           , breaksForwards2 topo Nothing target source
           ]
  failure = fmap or . mapM checkBool $ cases

-- |Verify that the two policies are separated from each other.
separate :: Graph -> Policy -> Policy -> IO Bool
separate topo p1 p2 = do
  fmap not failure where
  cases = [ sharedIO topo p1 p2
          , sharedIO topo p2 p1
          , sharedInput p1 p2
          , sharedInput p2 p1
          , sharedOutput p1 p2
          , sharedOutput p2 p1
          ]
  failure = fmap or . mapM checkBool $ cases

unsharedPortals :: Graph -> Policy -> Policy -> IO Bool
unsharedPortals topo p1 p2 = fmap not failure where
  cases = [ sharedTransit topo p1 p2 ]
  failure = fmap or . mapM checkBool $ cases

-- | helper function for debugging compiledCorrectly.  Use this when you want to
-- figure out which of the internal functions is breaking.
diagnose :: [IO (Maybe String)] -> IO ()
diagnose cases = mapM_ printResult cases

printResult :: IO (Maybe String) -> IO ()
printResult i = do
  ms <- i
  case ms of Just s -> putStrLn s
             Nothing -> putStrLn "Nothing"

-- | produce the slice that also expresses the constraint on ingress and egress
-- that vlan is unset
realSlice :: Slice -> Slice
realSlice (Slice int ing egr) = Slice int ing' egr' where
  ing' = Map.map (\pred -> pred <&&> DlVlan Nothing) ing
  egr' = Map.map (\pred -> pred <&&> DlVlan Nothing) egr

-- | Try to find some packets outside the interior or ingress of the slice that
-- the policy forwards or observes.
unconfinedDomain :: Graph -> Slice -> Policy -> IO (Maybe String)
unconfinedDomain topo slice policy = doCheck consts assertions where
  consts = getConsts [p, p'] []
  assertions = [ onTopo topo p, onTopo topo p'
               , ZNot (sInput slice p) , forwards policy p p' ]

-- | Try to find some packets outside the interior or egress of the slice that
-- the policy produces
unconfinedRange :: Graph -> Slice -> Policy -> IO (Maybe String)
unconfinedRange topo slice policy = doCheck consts assertions where
  consts = getConsts [p, p'] []
  assertions = [ onTopo topo p, onTopo topo p'
               , forwards policy p p', ZNot (sOutput slice p') ]

-- | Try to find some forwarding path over an edge that the policy receives
-- packets on (either forwarding or observing), and another packet
-- produced over the same edge (in the same direction) that uses a different
-- VLAN
multipleVlanEdge :: Graph -> Policy -> IO (Maybe String)
multipleVlanEdge topo policy = doCheck consts assertions  where
  consts = getConsts [p, p', q, q', r, r'] []

  -- Here, we care about finding some p' and q' that are produced by their
  -- respective policies, and are identical up to vlans.  We also require that
  -- p' is used by its policy in some way after a topology transfer (the
  -- business with r), since if it's not, then there's no problem.
  assertions = [ forwards policy p p'
               , transfer topo p' r
               , input policy r r'
               , forwards policy q q'
               , Equals (switch p') (switch q')
               , Equals (port p') (port q')
               , ZNot (Equals (vlan p') (vlan q'))
               ]

-- |Try to find a packet that produces an observation for which no equivalent
-- packet prodcues an observation in the other policy.
breaksObserves :: Graph -> Maybe Slice -> Policy -> Policy -> IO (Maybe String)
breaksObserves topo mSlice a b = doCheck consts assertions where
  consts = getConsts [p] [v, qid]

  locationAssertions = case mSlice of
                         Just slice -> [ sInput slice p ]
                         Nothing -> [ onTopo topo p ]
  assertions = locationAssertions ++
               [ queries a p qid
               , ForAll [ConstInt v] (ZNot (queriesWith b (p, Just v) qid))
               ]

-- | Try to find a pair of packets that a forwards for which there are no two
-- VLAN-equivalent packets that b also forwards.  If we can't, this is one-hop
-- simulation.  Maybe only consider packets within a slice.
breaksForwards :: Graph -> Maybe Slice -> Policy -> Policy -> IO (Maybe String)
breaksForwards topo mSlice a b = doCheck consts assertions where
  consts = getConsts [p, p'] [v, v']

  -- We don't need to test for vlan equivalence because sInput predicates do not
  -- consider vlans
  locationAssertions = case mSlice of
                         Just slice -> [ sInput slice p , sOutput slice p']
                         Nothing -> [ onTopo topo p , onTopo topo p']

  assertions = locationAssertions ++
               [ forwards a p p'
               , ForAll [ConstInt v, ConstInt v']
                        (ZNot (forwardsWith b (p, Just v) (p', Just v')))
               ]

-- | Try to find a two-hop forwarding path in a for which there isn't a
-- vlan-equivalent path in b.  If we can't, this is two-hop simulation.
breaksForwards2 :: Graph -> Maybe Slice -> Policy -> Policy -> IO (Maybe String)
breaksForwards2 topo mSlice a b = doCheck consts assertions where
  consts = getConsts [p, p', q, q'] [v, v', v'']

  -- We don't need to test for vlan equivalence because input predicates do not
  -- consider vlans
  locationAssertions = case mSlice of
                         Just slice -> [ sInput slice p, sOutput slice p'
                                       , sInput slice q, sOutput slice q' ]
                         Nothing -> [ onTopo topo p, onTopo topo p'
                                    , onTopo topo q, onTopo topo q' ]

  assertions = locationAssertions ++
               [ -- path p --1-> p' --T-- q --2-> q' in a
                 forwards a p p' , transfer topo p' q , forwards a q q'
                 -- Find a similar path for some vlans.  We don't need to test
                 -- topology transfer because it's insensitive to vlans.
               , ForAll [ConstInt v, ConstInt v', ConstInt v'']
                        (ZNot (ZAnd (forwardsWith b (p, Just v)  (p', Just v'))
                                    (forwardsWith b (q, Just v') (q', Just v''))))
               ]

-- | Try to find a packet that p1 produces that p2 does something with
sharedIO :: Graph -> Policy -> Policy -> IO (Maybe String)
sharedIO topo p1 p2 = doCheck consts assertions where
  consts = getConsts [p, p', q, q'] []

  assertions = [ onTopo topo p, onTopo topo q' -- transfer takes care of p', q
               , output p1 p p'
               , transfer topo p' q
               , input p2 q q'
               ]

-- |Try to find a packet p1 uses that is in the ingress set of p2
sharedInput :: Policy -> Policy -> IO (Maybe String)
sharedInput p1 p2 = doCheck consts assertions where
  consts = getConsts [p, p', p''] []

  assertions = [input p1 p p', pIngress p2 p p'']

-- |Try to find a packet p1 emits that is in the egress set of p2
sharedOutput :: Policy -> Policy -> IO (Maybe String)
sharedOutput p1 p2 = doCheck consts assertions where
  consts = getConsts [p, p', p''] []

  assertions = [output p1 p p'', pEgress p2 p' p'']

-- | Try to find a packet at the edge of both policies
sharedTransit :: Graph -> Policy -> Policy -> IO (Maybe String)
sharedTransit topo p1 p2 = doCheck consts assertions where
  consts = getConsts [p, p', p'', q', q''] []

  -- We try to find a packet p
  assertions = [ ZOr (pIngress p1 p p')
                     (ZAnd (pEgress p1 p' p'') (transfer topo p'' p))
               , ZOr (pIngress p2 p q')
                     (ZAnd (pEgress p2 q' q'') (transfer topo q'' p))
               ]

-- | Is the packet coming into the compiled slice?
pIngress policy p p' = ZAnd (input policy p p') (noVlan p)
-- | Is the packet leaving the compiled slice?
pEgress policy p p' = ZAnd (output policy p p') (noVlan p')

-- | Does policy use p to produce any packets or observations?
input :: Policy -> Z3Packet -> Z3Packet -> BoolExp
input policy p p' = ZOr (forwards policy p p')
                        (observes policy p)

-- | Can p' be produced by policy?
output :: Policy -> Z3Packet -> Z3Packet -> BoolExp
output policy p p' = forwards policy p p'

-- | Is the packet in the slice's interior or ingress?
sInput :: Slice -> Z3Packet -> BoolExp
sInput = inOutput ingress

-- | Is the packet in the slice's interior or egress?
sOutput :: Slice -> Z3Packet -> BoolExp
sOutput = inOutput egress

inOutput :: (Slice -> Map.Map Loc Predicate) -> Slice -> Z3Packet -> BoolExp
inOutput gress slice pkt = nOr (onInternal ++ onGress) where
  onInternal = map (\l -> atLoc l pkt) (Set.toList (internal slice))
  onGress = map (\(l, pred) -> ZAnd (atLoc l pkt) (match pred pkt))
                 (Map.toList (gress slice))
