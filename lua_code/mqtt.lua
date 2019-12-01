--File name: mqtt.lua
--Author: songdaw
--Limitations: No commercial use
--Function: mqtt clent, default connect to Aliyun IOT, provide external function for user app
--[[
-----[Aili MQTT]---------
----------------------------
ProductKey = "阿里云设备三元组ProductKey"
DeviceName = "阿里云设备三元组DeviceName"
DeviceSecret = "阿里云设备三元组DeviceSecret"

ClientId = wifi.sta.getmac()
RegionId = "cn-shanghai"

myMQTThost = ProductKey..".iot-as-mqtt."..RegionId..".aliyuncs.com"   --host
myMQTTport = 1883
myMQTTusername = DeviceName.."&"..ProductKey          --username

topic_event_post = "/sys/"..ProductKey.."/"..DeviceName.."/thing/event/property/post"
topic_service_set = "/sys/"..ProductKey.."/"..DeviceName.."/thing/service/property/set"
topic_user_data = "/"..ProductKey.."/"..DeviceName.."/user/mydata"
topic_event_post_qos = 0
topic_service_set_qos = 0
topic_user_data_qos = 0

--------MQTT------------------
hmacdata="clientId"..ClientId.."deviceName"..DeviceName.."productKey"..ProductKey
myMQTTpassword=crypto.toHex(crypto.hmac("sha1",hmacdata,DeviceSecret))
myMQTTClientId=ClientId.."|securemode=3,signmethod=hmacsha1|"
]]


----[[
-----[Tencent MQTT]---------
function str2hex(str)
    if (type(str)~="string") then
	    return nil,"str2hex invalid input type"
    end
    if(str:len()%2~=0) then
	    return nil,"str2hex invalid input lenth"
	end
    
    local index=1
    local ret=""
    for index=1,str:len(),2 do
        ret=ret..string.char(tonumber(str:sub(index,index+1),16))
    end

    return ret
end
----------------------------
ProductID = "腾讯云设备三元组ProductID"
DeviceName = "腾讯云设备三元组DeviceName"
DeviceSecret = str2hex("腾讯云设备三元组DeviceSecret")    --decode from base64

myMQTThost = ProductID..".iotcloud.tencentdevices.com"    --host
myMQTTport = 1883

topic_event_post = ProductID.."/"..DeviceName.."/event"
topic_user_data = ProductID.."/"..DeviceName.."/user/mydata"
topic_event_post_qos = 0
topic_service_set_qos = 0
topic_user_data_qos = 0

connid = wifi.sta.getmac()
--------MQTT------------------
myMQTTClientId = ProductID..DeviceName
myMQTTusername = ProductID..DeviceName..";12010126;"..connid..";1599406399"
myMQTTpassword=crypto.toHex(crypto.hmac("sha1",myMQTTusername,DeviceSecret))..";hmacsha1"
--]]

----mqtt client------
myMQTT = nil
myMQTT=mqtt.Client(myMQTTClientId, 120, myMQTTusername, myMQTTpassword) 

----mqtt connect------
mqtt_subscribe_table = {}
MQTTconnectFlag=0

mqtt_tmr = tmr.create()
mqtt_tmr:register(5000, tmr.ALARM_AUTO, function() 
        if myMQTT~=nil and network_connect_flag==1 and MQTTconnectFlag == 0 then
            print("Attempting client connect...")
            myMQTT:connect(myMQTThost, myMQTTport, 0, MQTTSuccess, MQTTFailed)
        end
    end)
mqtt_tmr:start()

function MQTTSuccess(client)
    print("MQTT connected")
    
    if #mqtt_subscribe_table > 0 then
        local subscribe_table = {}

        for i=1,#mqtt_subscribe_table do
            subscribe_table[mqtt_subscribe_table[i].str] = mqtt_subscribe_table[i].qos
        end 

        client:subscribe(subscribe_table, 
                function(conn)
                    print("subscribe success") 
                end
        )
    end

	myMQTT=client
	MQTTconnectFlag=1
	mqtt_tmr:stop()
end

function MQTTFailed(client, reson)
	print("Fail reson:"..reson)
	MQTTconnectFlag=0
	mqtt_tmr:start()
end

myMQTT:on("offline", function(client) 
    print ("offline")
    MQTTconnectFlag=0
    mqtt_tmr:start()
end)

myMQTT:on("connect", function(client) 
    print ("connect")
end)

myMQTT:on("message", function(client, topic, data) 
    print(topic ..":") 
    if data ~= nil then
        print(data)

        for i=1,#mqtt_subscribe_table do
            if topic == mqtt_subscribe_table[i].str then
                mqtt_subscribe_table[i].handler(data)
                break
            end
        end
    end
end)

----external functions----
function mqtt_publish_property(topic, target_device, pdata)
    local ret

    if MQTTconnectFlag == 0 or myMQTT==nil then
        print("mqtt error")
        return -1
    end

    local payload = {}
    
    payload["id"] = "123"
    payload["version"] = "1.0.0"
    payload["params"] = pdata
    payload["method"] = "thing.event.property.post"
    payload["device"] = target_device

    ok, json = pcall(sjson.encode, payload)
    if ok then
        print(json)
    else
        print("failed to encode!")
        return -1
    end

    ret = myMQTT:publish(topic, json, 0, 0, 
                        function(client)
                            print("publish ok")
                        end)
    if ret then
        return 0
    else
        return -1
    end
end


function mqtt_subscibe_callback(topic, sub_qos,  handler)
    local ret

    for i=1,#mqtt_subscribe_table do
        if topic == mqtt_subscribe_table[i].str then
            print("already subscribed")
            return 0
        end
    end 

    if MQTTconnectFlag == 0 or myMQTT==nil then
        print("add to table first")
        local sub = {
            str = topic,
            qos = sub_qos,
            handler = handler,
        }
        table.insert(mqtt_subscribe_table, sub)
        return 0
    end

    ret = myMQTT:subscribe(topic, 0, 
            function(conn)
                print("register subcribe success")
                local subs = {
                    str = topic,
                    qos = sub_qos,
                    handler = handler,
                }
                table.insert(mqtt_subscribe_table, subs)
            end)
    if ret then
        return 0
    else
        return -1
    end
end


----TODO:add config file----



--------


