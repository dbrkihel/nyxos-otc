if not Proxy then
    Proxy = {
        host = "",
        port = 0,
        priority = 0,
    }
end

function Proxy:new(data)
    local instance = setmetatable({}, { __index = self })
    instance.host = data.host or self.host
    instance.port = data.port or self.port
    instance.priority = data.priority or self.priority
    return instance
end

function Proxy:getPort()
    return self.port
end

function Proxy:getHost()
    return self.host
end
function Proxy:getPriority()
    return self.priority
end

function Proxy:setPort(port)
    self.port = port
end

if not Proxies then
    Proxies = {
        currentPort = 0,
        proxyList = {}
    }
end

function Proxies:loadProxyConfig(playerData)
    g_proxy.clear()
    self.currentPort = 0
    self.proxyList = {}
    if not playerData or not playerData["proxies"] then
        return
    end

    for _, proxyData in pairs(playerData["proxies"]) do
        local proxy = Proxy:new(proxyData)
        self.proxyList[proxy.host] = proxy
        self.currentPort = proxy.port

        g_proxy.addProxy(proxy:getHost(), proxy:getPort(), proxy:getPriority())
    end
end

function Proxies:changePort(port)
    g_proxy.clear()
    for _, proxy in pairs(self.proxyList) do
        if type(proxy) == "table" and proxy:getPort() > 0 then
            proxy:setPort(port)
            g_proxy.addProxy(proxy:getHost(), proxy:getPort(), proxy:getPriority())
        end
    end
end

