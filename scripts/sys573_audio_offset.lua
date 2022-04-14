-- Instructions:
-- Launch MAME using "-autoboot_script scripts\sys573_audio_offset.lua" to load this script.
-- Modify counter_offset value below to change your offset.
-- Add an override value for a specific ROM using the counter_offset_presets table.

function calculate_offset_from_milliseconds(milliseconds)
    return emu.attotime.from_msec(milliseconds):as_double() * 44100
end

-- Set this value to change the offset of the audio counter register for System 573 digital I/O games
-- This value is the number of samples to offset the counter by.
-- You can optionally use the helper function calculate_offset_from_milliseconds to calculate the sample offset using the desired millisecond offset.
counter_offset = calculate_offset_from_milliseconds(28)

-- The presets map can be used to set a default override offset for a specific game.
-- The presets map's override offset will overwrite the default configured offset if an override exists.
counter_offset_presets = {
    -- Examples:
    -- ["ddrmax2"] = 1234, -- Sample-based override offset
    -- ["ddrextrm"] = calculate_offset_from_milliseconds(28), -- Millisecond-based override offset
}

override_offset = counter_offset_presets[manager.machine.system["name"]]
if override_offset ~= nil then
    print("Audio offset override found! " .. counter_offset .. " -> " .. override_offset)
    counter_offset = override_offset
end

counter_current = 0
function get_offset_counter()
    rounded = math.floor((counter_current - counter_offset) + 0.5)
    return math.max(0, rounded)
end

memory = manager.machine.devices[":maincpu"].spaces["program"]

is_callback_read = false
function counter_callback(offset, data, mask)
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

if manager.machine.devices[":k573dio"] ~= nil then
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

    emu.register_stop(function()
        passthrough_counter_high:remove()
        passthrough_counter_low:remove()
    end)

    print("Sys573 audio counter is now being offset by " .. counter_offset .. " samples!")
    manager.machine:logerror("Sys573 audio counter is now being offset by " .. counter_offset .. " samples!")
    manager.machine:popmessage("Sys573 audio counter is now being offset by " .. counter_offset .. " samples!")
else
    print("This audio offset script only works for System 573 Digital I/O games!")
    manager.machine:logerror("This audio offset script only works for System 573 Digital I/O games!")
    manager.machine:popmessage("This audio offset script only works for System 573 Digital I/O games!")
end