-- triggertests.lua
local obs = obslua
local bit = require("bit")
local ffi = require("ffi")
local obs_window = 0
local screen_x = 0
local screen_y = 0
local screen_height = -80
local button_down = false
local triggerbot_key = 5
local mouse5_key = 6
local key_list = {{"Mouse Left", 1}, {"Mouse Right", 2}, {"Mouse Middle", 4}, {"Mouse 4", 5}, {"Mouse 5", 6}}

ffi.cdef[[
typedef int (__stdcall *WNDENUMPROC)(void *hwnd);
int EnumWindows(WNDENUMPROC address, intptr_t params);
int GetClientRect(void *hwnd, int *buffer);
int __stdcall GetWindowTextA(void *hWnd, char *lpString, int nMaxCount);
intptr_t strstr(char* _String, const char* _SubString);
int __stdcall SetWindowLongPtrA(void *hwnd, int nIndex, long long dwNewLong);
void *GetDC(void *window_handle);
unsigned short GetAsyncKeyState(int vKey);
unsigned int GetPixel(void *window, int x, int y);
int __stdcall PostMessageA(void *hWnd, int Msg, intptr_t wParam, intptr_t lParam);
void *__stdcall GetForegroundWindow();
void __stdcall mouse_event(unsigned long dwFlags, unsigned long dx, unsigned long dy, unsigned long dwData, unsigned long dwExtraInfo);
]]

function script_description()
    return "<b>ty chatgpt github x22 and my famous brain</b>"
end

function script_properties()
    local props = obs.obs_properties_create()

    local trigger_keys = obs.obs_properties_add_list(props, "triggerbot_key", "Button", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    for i = 1, #key_list do
        obs.obs_property_list_add_string(trigger_keys, key_list[i][1], key_list[i][1])
    end

    obs.obs_properties_add_int_slider(props, "screen_height", "Screen Height", -200, 200, 1)
    return props
end

local function get_key_from_list(name)
    for i = 1, #key_list do
        if key_list[i][1] == name then
            return key_list[i][2]
        end
    end
    return 0
end

function script_update(settings)
    triggerbot_key = get_key_from_list(obs.obs_data_get_string(settings, "triggerbot_key"))
    screen_height = obs.obs_data_get_int(settings, "screen_height")
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "triggerbot_key", key_list[triggerbot_key][1])
    obs.obs_data_set_default_int(settings, "screen_height", screen_height)
end

function initialize_window()
    if obs_window ~= 0 then
        return 1
    end

    local obs_handle = 0

    ffi.C.EnumWindows(function(hwnd)
        local buffer = ffi.new("char[260]", 0)
        ffi.C.GetWindowTextA(hwnd, buffer, 260)

        if ffi.C.strstr(buffer, "OBS ") > 0 then
            obs_handle = hwnd
            print("[+] OBS window was found")
            return false
        end
        return true
    end, 0)

    if obs_handle == 0 then
        return 0
    end

    ffi.C.SetWindowLongPtrA(obs_handle, -16, 0x14cc0000)
    obs_window = ffi.C.GetDC(obs_handle)

    local GameRect = ffi.new("int[4]", 0)
    ffi.C.GetClientRect(obs_handle, GameRect)

    screen_x = (GameRect[2] - GameRect[0]) / 2
    screen_y = (GameRect[3] - GameRect[1]) / 2

    return 1
end

function script_load()
end

local function is_color(red, green, blue)
    if green >= 170 then
        return false
    end

    if green >= 120 then
        return math.abs(red - blue) <= 8 and red - green >= 50 and blue - green >= 50 and red >= 105 and blue >= 105
    end

    return math.abs(red - blue) <= 13 and red - green >= 60 and blue - green >= 60 and red >= 110 and blue >= 100
end

local function GetRValue(c)
    return bit.band(c, 0xff)
end

local function GetGValue(c)
    return bit.band(bit.rshift(c, 8), 0xff)
end

local function GetBValue(c)
    return bit.band(bit.rshift(c, 16), 0xff)
end

function script_tick(seconds)
    if initialize_window() then
        if ffi.C.GetAsyncKeyState(triggerbot_key) < 0 then
            local found = false
            for y = -3, 4, 1 do
                for x = -1, 1, 1 do
                    local color = ffi.C.GetPixel(obs_window, screen_x + x, screen_y + y + screen_height)
                    if is_color(GetRValue(color), GetGValue(color), GetBValue(color)) then
                        found = true
                        break
                    end
                end
                if found then
                    break
                end
            end

            if found then
                if button_down == false then
                    ffi.C.PostMessageA(ffi.C.GetForegroundWindow(), 0x100, 1, 0)
                    button_down = true
                    print("Shot fired")
                    if ffi.C.GetAsyncKeyState(mouse5_key) < 0 then
                        local dx = 10 -- Adjust the desired mouse movement distance as needed
                        local dy = 10 -- Adjust the desired mouse movement distance as needed
                        ffi.C.mouse_event(0x0001, dx, dy, 0, 0) -- Mouse movement event
                    end
                end
            else
                if button_down == true then
                    ffi.C.PostMessageA(ffi.C.GetForegroundWindow(), 0x101, 1, 0)
                    button_down = false
                    print("Shot released")
                end
            end
        else
            if button_down == true then
                ffi.C.PostMessageA(ffi.C.GetForegroundWindow(), 0x101, 1, 0)
                button_down = false
                print("Shot released")
            end
        end
    end
end
