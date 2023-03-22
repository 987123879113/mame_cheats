-- license:BSD-3-Clause
-- copyright-holders:987123879113
local exports = {
	name = 'sys573_digital_audio_offset',
	version = '0.0.1',
	description = 'Sys573 digital audio offset plugin',
	license = 'BSD-3-Clause',
	author = { name = '987123879113' }
}

local sys573_digital_audio_offset = exports

function sys573_digital_audio_offset.startplugin()
    local function calculate_offset_from_milliseconds(milliseconds)
        return emu.attotime.from_msec(milliseconds):as_double() * 44100
    end

    local function get_processed_offset_value(val)
        match = string.match(val, "([%d]+[%.]?[%d]*)%s*[mM][sS]")
        if match ~= nil then
            return calculate_offset_from_milliseconds(tonumber(match))
        end

        return val
    end

    local function load_settings()
        local json = require('json')
        local filename = manager.machine.options.entries.pluginspath:value():match('([^;]+)') .. "/" .. exports['name'] .. "/settings.json"
        local file = io.open(filename, 'r')
        local default_offset = calculate_offset_from_milliseconds(28)

        local loaded_settings = {}
        if file then
            loaded_settings = json.parse(file:read('a'))
            file:close()
        else
            print("Couldn't open " .. filename)
        end

        if loaded_settings["default"] == nil then
            loaded_settings["default"] = default_offset
        end
        loaded_settings["default"] = get_processed_offset_value(loaded_settings["default"])

        if loaded_settings["overrides"] == nil then
            loaded_settings["overrides"] = {}
        end

        for k, v in pairs(loaded_settings["overrides"]) do
            loaded_settings["overrides"][k] = get_processed_offset_value(v)
        end

        return loaded_settings
    end

    local function init()
        if manager.machine.devices[":k573dio"] == nil then
            return
        end

        local settings = load_settings()
        local counter_offset = settings['default']
        local counter_current = 0
        local memory = nil

        local override_offset = settings['overrides'][manager.machine.system["name"]]
        if override_offset ~= nil then
            print("Audio offset override found! " .. counter_offset .. " -> " .. override_offset)
            counter_offset = override_offset
        end

        if counter_offset == 0 then
            -- Don't hook the code if no offset is specified
            return
        end

        local function get_offset_counter()
            rounded = math.floor((counter_current - counter_offset) + 0.5)
            return math.max(0, rounded)
        end

        local is_callback_read = false
        local function counter_callback(offset, data, mask)
            if offset == 0x1f6400c8 and mask == 0xffff0000 then
                if is_callback_read == true then
                    -- Hack because reading memory directly also calls the callback
                    return data
                end

                return get_offset_counter() & mask
            elseif offset == 0x1f6400cc and mask == 0x0000ffff then
                counter_current = data & mask
                is_callback_read = true
                counter_upper = memory:read_i16(0x1f6400ca)
                is_callback_read = false
                counter_current = counter_current | (counter_upper << 16)
                return get_offset_counter() & mask
            end

            return data
        end

        memory = manager.machine.devices[":maincpu"].spaces["program"]

        if passthrough_counter_high == nil then
            passthrough_counter_high = memory:install_read_tap(0x1f6400c8, 0x1f6400cb, "counter_high", counter_callback)
        else
            passthrough_counter_high:reinstall()
        end

        if passthrough_counter_low == nil then
            passthrough_counter_low =  memory:install_read_tap(0x1f6400cc, 0x1f6400cf, "counter_low",  counter_callback)
        else
            passthrough_counter_low:reinstall()
        end

        manager.machine:logerror("Sys573 audio counter is now being offset by " .. counter_offset .. " samples!")
    end

    local function deinit()
        passthrough_counter_high:remove()
        passthrough_counter_low:remove()
    end

    emu.register_start(init)
    emu.register_stop(deinit)
end

return exports
