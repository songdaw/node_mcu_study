-----Network-----
print("network start")

network_connect_flag = 0
wifi_check_cnt = 0

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
    print("Connected, IP is "..wifi.sta.getip())
    network_connect_flag = 1
end)

wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(T)
    print("wifi disconnect")
    network_connect_flag = 0
end)

----[wifi connect]---------------
wifi.setmode(wifi.STATION)

def_sta_config=wifi.sta.getdefaultconfig(true)
if string.len(def_sta_config.ssid) ~= 0 then
    wifi.sta.connect()
end

wifi_tmr = tmr.create()
wifi_tmr:register(1000, tmr.ALARM_AUTO, function() 
        wifi_check_cnt = wifi_check_cnt + 1
        if wifi_check_cnt > 20 then
            print("start net config")
            wifi_tmr:stop()
            wifi_tmr:unregister()

            dofile("netconfig.lua")
        end

        if network_connect_flag == 1 then
            wifi_tmr:stop()
            wifi_tmr:unregister()
        end
    end)
wifi_tmr:start()


