--File name: display.lua
--Author: songdaw
--Limitations: No commercial use
--Function: 0.96 oled display

id  = 0
sda = 2 -- GPIO4
scl = 1 -- GPIO5
sla = 0x3c

function init_display()
    i2c.setup(id, sda, scl, i2c.FAST)
    disp = u8g2.ssd1306_i2c_128x64_noname(id, sla)
    disp:setFont(u8g2.font_6x10_tf)
    disp:setFontPosTop()
    disp:clearBuffer()
end


function print_str(x, y, str)
    disp:drawStr(x, y, str)
end

function print_frame(x, y, w, h)
    disp:drawFrame(x, y, w, h)
end

function refresh()
    disp:sendBuffer();
end

function clear_box()
    disp:clearBuffer()
    print_str(0, 0, "Receive message:")
    print_frame(0, 12, 128, 52)
end

-----------------External function----------------
max_line = 6
address = {0, 10, 20, 30, 40, 50}
lines = {"", "", "", "", "", ""}
current_line = 1
need_scroll = 0
----max 20 bytes
function display_log(str)
    lines[current_line] = str   --save to buffer
    if(need_scroll == 0) then
        print_str(0, address[current_line], str)
        current_line = current_line + 1
        if(current_line > max_line) then
            need_scroll = 1
            current_line = 1
        end
    else
        disp:clearBuffer()
        j = 1

        if current_line < max_line then
            for i=current_line+1, max_line do   --draw from next index
                print_str(0, address[j], lines[i])
                j = j + 1
            end
        end

        for i=1,current_line do                 ----draw from index 1
            print_str(0, address[j], lines[i])
            j = j + 1
        end

        current_line = current_line + 1
        if(current_line > max_line) then
            current_line = 1
        end
    end

    refresh()
end

--diaplay message, max 80 bytes
function display_message(str)
    clear_box()

    message_len = string.len(str)
    if (message_len == 0) then
        refresh()
        return
    end

    line_number = 0
    line_byte = 20
    tmp_len = 0
    while (message_len > 0) do
        if(message_len >= line_byte) then
            tmp_len = line_byte
        else
            tmp_len = message_len
        end

        t = string.sub(str, 20*line_number + 1, 20*line_number + tmp_len)

        if(line_number == 0) then
            print_str(4, 15, t)
        elseif(line_number == 1) then
            print_str(4, 27, t)
        elseif(line_number == 2) then
            print_str(4, 39, t)
        elseif(line_number == 3) then
            print_str(4, 51, t)
        end

        message_len = message_len - tmp_len
        line_number = line_number + 1
    end

    refresh()
end

init_display()

