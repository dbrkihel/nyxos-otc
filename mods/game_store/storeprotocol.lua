-- Thin SENDER layer for the crystalserver (Canary-style) GameStore.
--
-- RECEIVE side: there is intentionally NO Lua receive machinery here (no
-- ProtocolGame.registerOpcode, no parseCatalog/parseHistory/showOffers caches).
-- Incoming store packets must reach the native C++ parsers, which were ported
-- byte-for-byte from the crystalserver gamestore module
-- (data/modules/scripts/gamestore/init.lua, read-only on WSL):
--   0xFB S_OpenStore               -> parseStore (categories -> onStoreCategories)
--   0xFC S_StoreOffers             -> parseStoreOffers (-> onStoreOffers)
--   0xFD S_OpenTransactionHistory  -> parseStoreTransactionHistory
--                                     (-> onStoreTransactionHistory(currentPage,
--                                      pageCount numeric, offers) — store.lua:309
--                                      already consumes exactly this signature)
--   0xEA sendOfferDescription      -> parseStoreOfferDescription
--   0xE0 S_StoreError              -> parseStoreError, 0xDF S_CoinBalance, etc.
-- A Lua handler registered on any of these would run BEFORE the C++ switch and
-- shadow/desync the native parse.
--
-- SEND side: the native C++ senders are used wherever their wire layout matches
-- the server (see initStoreProtocol below). Only the senders whose native
-- implementation diverges from the crystalserver parsers are overridden here.

local StoreProtocol = {}

-- crystalserver gamestore RecivedPackets (data/modules/scripts/gamestore/init.lua:202)
local OPCODE_REQUEST_STORE_OFFERS = 0xFB -- C_RequestStoreOffers (modules.xml recvbyte 251)
local OPCODE_BUY_STORE_OFFER = 0xFC -- C_BuyStoreOffer       (modules.xml recvbyte 252)
local OPCODE_TRANSFER_COINS = 0xEF -- C_TransferCoins      (modules.xml recvbyte 239)

local function sendStoreMessage(msg)
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:send(msg)
  end
end

-- C_RequestStoreOffers: [0xFB][action U8][payload]
-- Server parseRequestStoreOffers (gamestore/init.lua:353) reads, per action
-- (GameStore.ActionType, init.lua:77):
--   OPEN_HOME          = 0 -> no payload
--   OPEN_PREMIUM_BOOST = 1 -> U8 subAction   (client global OPEN_REDIRECT)
--   OPEN_CATEGORY      = 2 -> string categoryName
--   OPEN_USEFUL_THINGS = 3 -> U8 subAction
--   OPEN_OFFER         = 4 -> U32 offerId
--   OPEN_SEARCH        = 5 -> string searchText
-- The native sendRequestStoreOffers always writes [U8][string] and therefore
-- mis-encodes the numeric payloads (OPEN_OFFER needs a U32), hence this override.
-- Caller convention across the codebase is (action number, stringValue, numberValue),
-- e.g. Categories.lua (OPEN_CATEGORY, name, 0), store.lua (OPEN_SEARCH, text, 0),
-- Home.lua (SERVICE_OFFER_ID=4, "", offer.id), hunting.lua (3, "", offerType).
function StoreProtocol.requestStoreOffers(actionOrCategory, stringParam, numberParam)
  -- Remember the current view so a purchase can force a fresh re-fetch (server
  -- recomputes owned/disabled state and combo "All ..." prices per request).
  -- Categories:onSelectCategory short-circuits when the category is already
  -- selected, so the post-purchase refresh has to replay the raw request itself.
  Store.lastOffersRequest = { actionOrCategory, stringParam, numberParam }

  local msg = OutputMessage.create()
  msg:addU8(OPCODE_REQUEST_STORE_OFFERS)

  if type(actionOrCategory) ~= 'number' then
    -- legacy convention: first arg is the category name itself
    msg:addU8(OPEN_CATEGORY)
    msg:addString(tostring(actionOrCategory or ''))
  elseif actionOrCategory == OPEN_CATEGORY then
    msg:addU8(OPEN_CATEGORY)
    msg:addString(tostring(stringParam or ''))
  elseif actionOrCategory == OPEN_SEARCH then
    msg:addU8(OPEN_SEARCH)
    msg:addString(tostring(stringParam or ''))
  elseif actionOrCategory == OPEN_OFFER then -- == SERVICE_OFFER_ID (4)
    msg:addU8(OPEN_OFFER)
    msg:addU32(tonumber(numberParam) or 0)
  elseif actionOrCategory == OPEN_REDIRECT or actionOrCategory == OPEN_USEFUL_THINGS then
    -- server OPEN_PREMIUM_BOOST (1) / OPEN_USEFUL_THINGS (3): one U8 subAction
    msg:addU8(actionOrCategory)
    msg:addU8(math.max(0, math.min(255, tonumber(numberParam) or 0)))
  else
    -- OPEN_HOME and anything unknown: request the home page (no payload)
    msg:addU8(OPEN_HOME)
  end

  sendStoreMessage(msg)
end

-- Intentional NO-OP. The crystalserver has no "request offer description"
-- opcode: descriptions are PUSHED by the server via 0xEA sendOfferDescription
-- (gamestore/init.lua:736, emitted from sendShowStoreOffers init.lua:1121) and
-- consumed by native parseStoreOfferDescription -> g_game.onStoreDescription ->
-- Offers:cacheDescription. Offers.lua calldescription() now renders from that
-- cache instead of hitting the wire, so this sender is no longer called; the
-- stub is kept only so the g_game.requestOfferDescription binding stays valid.
function StoreProtocol.requestOfferDescription(offerId)
  -- no wire traffic on purpose
end

-- C_BuyStoreOffer: [0xFC][offerId U32][productType U8][optional payload].
-- Server parseBuyStoreOffer (gamestore/init.lua:451) reads U32 id + U8
-- productType, then per offer.type:
--   OFFER_TYPE_NAMECHANGE / HIRELING_NAMECHANGE -> string newName
--   OFFER_TYPE_HIRELING                         -> string name + U8 sex
--     (HIRELING_SEX: MALE = 1, FEMALE = 2 — data/libs/systems/hireling.lua)
-- The NATIVE sendBuyStoreOffer cannot be used: it appends the name only for
-- Otc::ProductTypeNameChange (1) and never writes the hireling sex byte, so the
-- second phase of a hireling purchase (store.lua onClickNameChange, productType
-- OFFER_BUY_TYPE_HIRELING = 3) would reach the server without name/sex.
-- Note: the hireling purchase is two-phase. Phase 1 (plain buy click) sends no
-- name; the server answers with 0xE1 S_RequestPurchaseData (offerId U32 +
-- productType U8), which triggers g_game.onRequestPurchaseData (emitted by the
-- native parseRequestPurchaseData, protocolgameparse.cpp) -> hireling window ->
-- phase 2 with name+sex.
function StoreProtocol.buyStoreOffer(offerId, productType, name, sex, offerName)
  local msg = OutputMessage.create()
  msg:addU8(OPCODE_BUY_STORE_OFFER)
  msg:addU32(tonumber(offerId) or 0)
  msg:addU8(productType or 0)
  if name and name ~= '' then
    msg:addString(name)
    if productType == OFFER_BUY_TYPE_HIRELING then
      msg:addU8(sex or 1)
    end
  elseif offerName and offerName ~= '' then
    -- Home.lua "buy now" path (productType 10/11): trailing string is unread by
    -- the server for non-name offer types (one opcode per message), harmless.
    msg:addString(offerName)
  end
  sendStoreMessage(msg)
end

-- C_TransferCoins: [0xEF][recipient string][amount U32].
-- Server parseTransferableCoins (gamestore/init.lua:305) reads getString() +
-- getU32(). The NATIVE sendTransferCoins writes the amount as U16
-- (protocolgamesend.cpp:1224) — wrong width, would desync the server read —
-- hence this override.
function StoreProtocol.transferCoins(recipient, amount)
  amount = tonumber(amount)
  if not recipient or recipient == '' or not amount or amount <= 0 then
    return
  end
  local msg = OutputMessage.create()
  msg:addU8(OPCODE_TRANSFER_COINS)
  msg:addString(recipient)
  msg:addU32(amount)
  sendStoreMessage(msg)
end

function initStoreProtocol()
  -- Native C++ senders verified byte-for-byte against the crystalserver
  -- gamestore parsers and used as-is (NOT overridden):
  --   g_game.openStore                -> [0xFA][U8 serviceType]; server
  --     parseOpenStore reads no payload, the trailing byte is unread (one
  --     opcode per message) — categories come back via 0xFB.
  --   g_game.openTransactionHistory   -> [0xFD][U8 entriesPerPage] matches
  --     parseOpenTransactionHistory (init.lua:642).
  --   g_game.requestTransactionHistory-> [0xFE][U32 page][U8 entriesPerPage];
  --     parseRequestTransactionHistory (init.lua:655) reads the U32 page
  --     (0-based, server does page+1); the trailing U8 is unread, harmless.
  g_game.requestStoreOffers = StoreProtocol.requestStoreOffers
  g_game.requestOfferDescription = StoreProtocol.requestOfferDescription
  g_game.buyStoreOffer = StoreProtocol.buyStoreOffer
  g_game.transferCoins = StoreProtocol.transferCoins
end

function terminateStoreProtocol()
  -- The g_game sender overrides are left installed (same lifetime behavior as
  -- before): they are stateless wrappers and are re-assigned on module reload.
end
