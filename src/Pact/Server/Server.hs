{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}


-- |
-- Module      :  Pact.Server.Server
-- Copyright   :  (C) 2016 Stuart Popejoy
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Stuart Popejoy <stuart@kadena.io>
--
-- Launch pact dev server.
--

module Pact.Server.Server
  (serve
  )where

import Control.Monad
import Control.Monad.State
import Control.Concurrent
import Data.Word (Word16)

import Pact.Server.PactService
import Pact.Server.ApiServer
import Pact.Types.Runtime
import Pact.Types.Server
import Pact.Types.Command

serve :: Word16 -> IO ()
serve port' = do
  (inC,outC) <- initChans
  let debugFn = putStrLn
  let serverPort = fromIntegral port'
  let cmdConfig = CommandConfig Nothing debugFn "entity"
  _ <- forkIO $ startCmdThread cmdConfig inC outC
  runApiServer inC outC debugFn serverPort

startCmdThread :: CommandConfig -> InboundPactChan -> OutboundPactChan -> IO ()
startCmdThread cmdConfig inChan outChan = do
  CommandExecInterface {..} <- initPactService cmdConfig
  void $ (`runStateT` (0 :: TxId)) $ forever $ do
    cmds <- liftIO $ readInbound inChan
    resps <- forM cmds $ \cmd -> do
      txid <- state (\i -> (i,succ i))
      liftIO $ _ceiApplyCmd (Transactional txid) cmd
    liftIO $ writeOutbound outChan resps
