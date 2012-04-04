--------------------------------------------------------------------------------
-- The Frenetic Project                                                       --
-- frenetic@frenetic-lang.org                                                 --
--------------------------------------------------------------------------------
-- Licensed to the Frenetic Project by one or more contributors. See the      --
-- NOTICE file distributed with this work for additional information          --
-- regarding copyright and ownership. The Frenetic Project licenses this      --
-- file to you under the following license.                                   --
--                                                                            --
-- Redistribution and use in source and binary forms, with or without         --
-- modification, are permitted provided the following conditions are met:     --
-- * Redistributions of source code must retain the above copyright           --
--   notice, this list of conditions and the following disclaimer.            --
-- * Redistributions of binaries must reproduce the above copyright           --
--   notice, this list of conditions and the following disclaimer in          --
--   the documentation or other materials provided with the distribution.     --
-- * The names of the copyright holds and contributors may not be used to     --
--   endorse or promote products derived from this work without specific      --
--   prior written permission.                                                --
--                                                                            --
-- Unless required by applicable law or agreed to in writing, software        --
-- distributed under the License is distributed on an "AS IS" BASIS, WITHOUT  --
-- WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the   --
-- LICENSE file distributed with this work for specific language governing    --
-- permissions and limitations under the License.                             --
--------------------------------------------------------------------------------
-- /testsuite/Frenetic/TestCompat                                             --
--                                                                            --
-- $Id$ --
--------------------------------------------------------------------------------

{-# LANGUAGE
    TemplateHaskell
 #-}

import Data.Word
import Test.Framework
import Test.Framework.TH
import Test.Framework.Providers.QuickCheck2

import Frenetic.Compat
import Tests.Frenetic.ArbitraryCompat

main = $(defaultMainGenerator)

prop_reflWord48 :: Word48 -> Bool
prop_reflWord48 i = i == i

prop_reflPacket :: Packet -> Bool
prop_reflPacket i = i == i

prop_reflPattern :: Pattern -> Bool
prop_reflPattern i = i == i

prop_reflActions :: Actions -> Bool
prop_reflActions i = i == i
