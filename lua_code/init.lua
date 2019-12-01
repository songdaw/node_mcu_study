--File name: init.lua
--Author: songdaw
--Limitations: No commercial use
--Function: init flow and user app

tmr.delay(1000000)
print("nodemcu start 0.1")
tmr.delay(1000000)

----start-----
dofile("network.lua")

----mqtt-----
dofile("mqtt.lua")

----user app-----
function topic_handler(data)
    print("user topic handler")
    if data ~= nil then
        print(data)
    end
end
mqtt_subscibe_callback(topic_user_data, topic_user_data_qos, topic_handler)

humi = 0
onoff = 0
user_tmr = tmr.create()
user_tmr:register(5000, tmr.ALARM_AUTO, function()
        mqtt_publish_property(topic_event_post, "pc_control", {["hum"]=humi, ["Status"]=onoff})

        onoff = (onoff+1)%2

        humi = humi + 1
        if humi >= 100 then
            humi = 0
        end
    end)
user_tmr:start()


