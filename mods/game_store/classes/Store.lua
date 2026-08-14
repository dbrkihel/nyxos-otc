if not Store then
	Store = {}
	Store.__index = Store
end

Store.url = ""
Store.coinsPacketSize = 25
Store.coins = 0
Store.transferableCoins = 0
Store.tournamentCoins = 0
Store.displayDescription = 100
Store.requestPerPage = 32
Store.imageRequests = {}
Store.currentRequest = 0

OPEN_HOME = 0
OPEN_REDIRECT = 1
OPEN_CATEGORY = 2
OPEN_USEFUL_THINGS = 3
OPEN_OFFER = 4
OPEN_SEARCH = 5

OFFER_BUY_TYPE_OTHERS = 0
OFFER_BUY_TYPE_NAMECHANGE = 1
OFFER_BUY_TYPE_TRANSFER = 2
OFFER_BUY_TYPE_HIRELING = 3

SERVICE_HOME = 0
SERVICE_CATEGORY_TYPE = 1
SERVICE_CATEGORY_NAME = 2
SERVICE_OFFER_TYPE = 3
SERVICE_OFFER_ID = 4
SERVICE_OFFER_NAME = 5

-- NOTE: a legacy compatibility wrapper around g_game.requestStoreOffers used to
-- live here. It is gone on purpose: storeprotocol.lua (initStoreProtocol)
-- installs the real C_RequestStoreOffers sender, which understands the
-- (action number, stringValue, numberValue) convention used by every caller.
-- The wrapper would shadow it and collapse every action type to OPEN_HOME.

CATEGORY_NONE = 0
CATEGORY_MOUNT = 1
CATEGORY_OUTFIT = 2
CATEGORY_ITEM = 3
CATEGORY_HIRELING = 4
CATEGORY_HIRELING_OUTFIT = 6

OFFER_STATE_NONE = 0
OFFER_STATE_NEW = 1
OFFER_STATE_SALE = 2
OFFER_STATE_TIMED = 3

COIN_TYPE_DEFAULT = 0
COIN_TYPE_TRANSFERABLE = 1
COIN_TYPE_TOURNAMENT = 2
COIN_TYPE_RESERVED = 3

function Store:downloadImage(requestId, image, disabled)
	HTTP.downloadImage(Store.url .. image, function(path, err)
		if err then
			if DEVELOPERMODE then
				g_logger.warning("HTTP error: " .. err .. " - ".. Store.url .. image)
			end
			return
		end
		local widget = Store.imageRequests[requestId]
		if widget then
			widget:setImageSource(path, false)
			widget.imagePath = path
			if disabled then
				widget.disabled:setVisible(true)
			end
		end
	end)
end

function Store:openHome()
	scheduleEvent(function()
		g_game.doThing(false)
		g_game.requestStoreOffers(OPEN_HOME, "", 0);
		g_game.doThing(true)
	end, 100)
end

-- Re-issue the request for the view the player is currently looking at. Used
-- after a purchase so owned/disabled state and combo "All ..." prices refresh
-- without the player having to close and reopen the store.
function Store:reloadOffers()
	local r = Store.lastOffersRequest
	if not r then
		return Store:openHome()
	end
	g_game.doThing(false)
	g_game.requestStoreOffers(r[1], r[2], r[3])
	g_game.doThing(true)
end

function Store:getDescription(requestId, offerId, description)
	local data = {
		["description"] = "<b>"..description.."</b>",
		["fontcolor"] = "#f4f4f4",
		["fontsize"] = "11.1px",
		["font"] = "Verdana",
		["id"] = offerId
	}
	-- Offer artwork is fetched from an external widget host; point this at yours.
	HTTP.downloadConditionalImage("http://127.0.0.1/widget/"..offerId, data, function(path, err)
		if err then
			return
		end
		local widget = Store.imageRequests[requestId]
		if widget then
			widget:setImageSource(path, false)
		end
	end)
end
