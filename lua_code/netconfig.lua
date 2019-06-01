--File name: netconfig.lua
--Author: songdaw
--Limitations: No commercial use
--Function: webserver to config wifi, default ip:192.168.4.1

------Net config-------
wifi.setmode(wifi.STATIONAP)
ap_cfg={}
ap_cfg.ssid = "ESP_mytest"
ap_cfg.auth = wifi.OPEN
wifi.ap.config(ap_cfg)

httpserver = nil

httpserver = net.createServer(net.TCP)
httpserver:listen(80, function(conn)
    conn:on("receive", receiver)
  end)

web_html = 
  [[
  <!DOCTYPE html>
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Config</title>
  </head>
  <body style="text-align:center;background:#f8fffbb2;">
      <h1>Config page</h1>
      <form action="/config" method="post">
          <label>WiFi</label>
          <input type="text" name="ssid" />
          <br />
          <label>password</label>
          <input type="password" name="pwd" />
          <br />
          <input type="submit" value="ok" style="background:#678df9;height:40px;width:60px;border-radius:5px;border:none;outline:none;"/>
      </form>
  </body>
  </html>
  ]]

web_wifi_ok_html = [[
    <!DOCTYPE html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Wifi</title>
    </head>
    <body style="text-align:center;background:#f8fffbb2;">
        <h1>WIFI OK</h1>
    </body>
    </html>
]]

web_wifi_error_html = [[
    <!DOCTYPE html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Wifi</title>
    </head>
    <body style="text-align:center;background:#f8fffbb2;">
        <h1>WIFI ERROR</h1>
    </body>
    </html>
]]


itor = {
    current = 0,
    str = nil,
}

function sendres(localsck, status, body)
    local header = "HTTP/1.1 "..status.."\r\n"
                .."Content-Type: text/html".."\r\n"
                .. "Content-Length: "..string.len(body).."\r\n"
                .."\r\n"
    local buffer = header..body

    local function send(insck)
        if buffer == "" then
            --print("already sent")
            insck:close()
        else
            if string.len(buffer) > 512 then
                insck:send(string.sub(buffer, 1, 512))
                buffer = string.sub(buffer, 513)
            else
                insck:send(buffer)
                buffer = ""
            end
        end
    end

    localsck:on("sent", send)
    send(localsck)
end


function handle_index(localsck, req)
    sendres(localsck, "200 OK", web_html)
end


function handle_config(localsck, req)
    --print("handle config")

    local _, _, ssid_data, pwd_data = string.find(req.body, 'ssid=(.+)&pwd=(.+)')
    local sta_cfg={}  
    sta_cfg.ssid=ssid_data
    sta_cfg.pwd=pwd_data
    wifi.sta.config(sta_cfg)
    wifi.sta.connect()

    wifi_check_cnt = 0
    network_connect_flag = 0
    wifi_tmr:register(1000, tmr.ALARM_AUTO, function() 
            wifi_check_cnt = wifi_check_cnt + 1
            if wifi_check_cnt > 20 then
                sendres(localsck, "200 OK", web_wifi_error_html)
                wifi_tmr:stop()
                wifi_tmr:unregister()
            end

            if network_connect_flag == 1 then
                sendres(localsck, "200 OK", web_wifi_ok_html)
                wifi_tmr:stop()
                wifi_tmr:unregister()
            end
        end)
    wifi_tmr:start()
end


function handle_get(localsck, req)
    local handled = 0

    for i=1,#req.get_handlers do
        if req.path == req.get_handlers[i].str then
            req.get_handlers[i].handler(localsck, req)
            handled = 1
            break
        end
    end

    return handled
end


function handle_post(localsck, req)
    print("handle post")
    local handled = 0

    for i=1,#req.post_handlers do
        if req.path == req.post_handlers[i].str then
            req.post_handlers[i].handler(localsck, req)
            handled = 1
            break
        end
    end

    return handled
end


reqhandle = {
    type = nil,
    path = nil,
    body = nil,

    req_handlers = {
        {
            str = "GET",
            handler = handle_get,
        },
        {
            str = "POST",
            handler = handle_post,
        }
    },

    get_handlers = {
        {
            str = "/",
            handler = handle_index,
        }
    },

    post_handlers = {
        {
            str = "/config",
            handler = handle_config,
        }
    },
}

function reqhandle:parsehead(head)
    print("head"..head)

    local _, _, type, path = string.find(head, '([A-Z]+) (.+) HTTP')

    self.type = type
    self.path = path
end

function reqhandle:parsebody(body)
    print("body"..body)

    self.body = body
end

function reqhandle:process(localsck)
    --print("process")
    local processed = 0

    for i=1,#self.req_handlers do
        if self.type == self.req_handlers[i].str then
            processed = self.req_handlers[i].handler(localsck, self)
            break
        end
    end

    if processed == 0 then
        print("not processed")
        sendres(localsck, "404 Not Found", "")
    end
end


function receiver(sck, data)
    itor:set(data)

    local step = 0
    local lines = itor:lines()
    while (lines ~= nil)
    do
        if step == 0 then               --HEAD
            reqhandle:parsehead(lines)
            step = 1
        elseif step == 1 then           --CTRL
            --do nothing
            if string.len(lines) == 0 then
                step = 2
            end
        elseif step == 2 then           --BODY
            reqhandle:parsebody(lines)
            step = 3
        end

        lines = itor:lines()
    end
    reqhandle:process(sck)

    collectgarbage()
end


function itor:set(str_s)
    self.str = str_s
    self.current = 0
end


function itor:lines()
    local sub_st
    local st, _ = string.find(self.str, '\r\n', self.current)
    if st == nil then
        if self.current >= string.len(self.str) then
            return nil
        else
            sub_st = self.current
            self.current = string.len(self.str)
            return string.sub(self.str, sub_st)
        end
    else
        sub_st = self.current
        self.current = st + 2
        return string.sub(self.str, sub_st, st-1)
    end
end


--------


