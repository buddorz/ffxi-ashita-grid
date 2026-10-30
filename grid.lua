addon.name      = 'grid';
addon.author    = 'budd';
addon.version   = '1.0';
addon.desc      = 'Displays a dynamic grid to align Ashita addon elements.';
addon.link      = 'https://github.com/buddorz/ffxi-ashita-grid';

local chat     = require('chat');
local imgui    = require('imgui');
local settings = require('settings');

-- Default Configuration Settings
local default_settings = T{
    visible         = false,
    grid_size       = 25,                       -- Target grid cell size in pixels
    major_every     = 5,                        -- Highlight every Nth line from center
    thickness       = 1.5,                      -- Line thickness in pixels
    color_minor     = T{ 1.0, 1.0, 1.0, 0.2 },  -- Light translucent white
    color_major     = T{ 1.0, 0.8, 0.0, 0.5 },  -- Translucent gold
    color_center    = T{ 1.0, 0.0, 0.0, 0.8 },  -- Red for screen center axes
};

local gSettings   = settings.load(default_settings);
local show_config = { false };

-- Register settings update event handler
settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        gSettings = s;
    end
    settings.save();
end);

-- Output formatting helpers
local function print_error(msg)
    print(chat.header('grid'):append(chat.message(string.format('%s', msg))));
end

local function print_help()
    -- Print the help header..
    if (isError) then
        print(chat.header(addon.name):append(chat.error('Invalid command syntax for command: ')):append(chat.success('/' .. addon.name)));
    else
        print(chat.header(addon.name):append(chat.message('Available commands:')));
    end

    local cmds = T{
        { '/grid', 'Toggles grid overlay on/off.' },
        { '/grid config', 'Open/close the settings window.' },
        { '/grid show | hide' , 'Explicitly enable/disable grid.' },
        { '/grid size <10-200>', 'Set target cell size in pixels.' },
        { '/grid major <1-20>', 'Set major line interval.' },
        { '/grid thickness <0.5-5.0>', 'Set line thickness in pixels.' },
        { '/grid help', 'Displays this help menu.' },
    };
	
    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);

end

-- Helper function to parse command arguments cleanly
local function parse_args(cmd)
    local args = {};
    for word in cmd:gmatch("%S+") do
        table.insert(args, word);
    end
    return args;
end

-- Render ImGui Settings Dialog
local function render_ui()
    if not show_config[1] then return end

    if imgui.Begin('Grid Configuration', show_config, ImGuiWindowFlags_AlwaysAutoResize) then
        -- Overlay Toggle
        local vis = { gSettings.visible };
        if imgui.Checkbox('Enable Grid Overlay', vis) then
            gSettings.visible = vis[1];
            settings.save();
        end

        imgui.Separator();

        -- Cell Size
        local g_size = { gSettings.grid_size };
        if imgui.SliderInt('Grid Size (px)', g_size, 10, 200) then
            gSettings.grid_size = g_size[1];
            settings.save();
        end

        -- Major Line Frequency
        local major = { gSettings.major_every };
        if imgui.SliderInt('Major Line Interval', major, 1, 20) then
            gSettings.major_every = major[1];
            settings.save();
        end

        -- Line Thickness
        local thick = { gSettings.thickness };
        if imgui.SliderFloat('Line Thickness', thick, 0.5, 5.0, '%.1f') then
            gSettings.thickness = thick[1];
            settings.save();
        end

        imgui.Separator();

        -- Color Pickers
        local color_minor_picker = { gSettings.color_minor[1], gSettings.color_minor[2], gSettings.color_minor[3], gSettings.color_minor[4] };
        if imgui.ColorEdit4('Minor Lines Color', color_minor_picker) then
            gSettings.color_minor = T{ color_minor_picker[1], color_minor_picker[2], color_minor_picker[3], color_minor_picker[4] };
            settings.save();
        end

        local color_major_picker = { gSettings.color_major[1], gSettings.color_major[2], gSettings.color_major[3], gSettings.color_major[4] };
        if imgui.ColorEdit4('Major Lines Color', color_major_picker) then
            gSettings.color_major = T{ color_major_picker[1], color_major_picker[2], color_major_picker[3], color_major_picker[4] };
            settings.save();
        end

        local color_center_picker = { gSettings.color_center[1], gSettings.color_center[2], gSettings.color_center[3], gSettings.color_center[4] };
        if imgui.ColorEdit4('Center Axes Color', color_center_picker) then
            gSettings.color_center = T{ color_center_picker[1], color_center_picker[2], color_center_picker[3], color_center_picker[4] };
            settings.save();
        end
    end
    imgui.End();
end

-- Render Hook
ashita.events.register('d3d_present', 'grid_d3d_present_cb', function ()
    render_ui();

    if not gSettings.visible then return end

    local display_size = imgui.GetIO().DisplaySize;
    local screen_w = display_size.x;
    local screen_h = display_size.y;

    if screen_w <= 0 or screen_h <= 0 then return end

    -- Calculate even cell counts per axis based on window dimensions
    local half_cols = math.max(1, math.floor((screen_w / 2) / gSettings.grid_size + 0.5));
    local half_rows = math.max(1, math.floor((screen_h / 2) / gSettings.grid_size + 0.5));

    local total_cols = half_cols * 2;
    local total_rows = half_rows * 2;

    local step_x = screen_w / total_cols;
    local step_y = screen_h / total_rows;

    local draw_list = imgui.GetForegroundDrawList();
    local color_minor_u32  = imgui.GetColorU32(gSettings.color_minor);
    local color_major_u32  = imgui.GetColorU32(gSettings.color_major);
    local color_center_u32 = imgui.GetColorU32(gSettings.color_center);

    -- Draw Vertical Lines
    for i = 0, total_cols do
        local x = i * step_x;
        local line_color = color_minor_u32;

        if i == half_cols then
            line_color = color_center_u32; -- Exact horizontal center line
        elseif math.abs(i - half_cols) % gSettings.major_every == 0 then
            line_color = color_major_u32;
        end

        draw_list:AddLine({ x, 0 }, { x, screen_h }, line_color, gSettings.thickness);
    end

    -- Draw Horizontal Lines
    for i = 0, total_rows do
        local y = i * step_y;
        local line_color = color_minor_u32;

        if i == half_rows then
            line_color = color_center_u32; -- Exact vertical center line
        elseif math.abs(i - half_rows) % gSettings.major_every == 0 then
            line_color = color_major_u32;
        end

        draw_list:AddLine({ 0, y }, { screen_w, y }, line_color, gSettings.thickness);
    end
end);

-- Command Hook
ashita.events.register('command', 'grid_command_cb', function (e)
    local args = parse_args(e.command);
    if #args == 0 or args[1]:lower() ~= '/grid' then return end

    e.blocked = true;

    -- Toggle Grid Visibility: /grid
    if #args == 1 then
        gSettings.visible = not gSettings.visible;
        settings.save();
		print(chat.header('grid'):append(chat.message('Overlay is ')):append(chat.message(string.format('%s.', gSettings.visible and 'enabled' or 'disabled'))));
		return;
    end

    local sub = args[2]:lower();

    -- Help Output
    if sub == 'help' or sub == '?' then
        print_help();
        return;
    end

    -- Open Config UI: /grid config
    if sub == 'config' then
        show_config[1] = not show_config[1];
        return;
    end

    -- Explicit Show / Hide
    if sub == 'show' or sub == 'on' then
        gSettings.visible = true;
        settings.save();
   		print(chat.header('grid'):append(chat.message('Overlay is ')):append(chat.message(string.format('%s.', gSettings.visible and 'enabled' or 'disabled'))));

		return;
    elseif sub == 'hide' or sub == 'off' then
        gSettings.visible = false;
        settings.save();
		print(chat.header('grid'):append(chat.message('Overlay is ')):append(chat.message(string.format('%s.', gSettings.visible and 'enabled' or 'disabled'))));
        return;
    end

    -- Change Target Grid Size: /grid size <pixels>
    if sub == 'size' then
        if not args[3] then
            print_error('Missing parameter. Usage: /grid size <10-200>');
            return;
        end
        local val = tonumber(args[3]);
        if val and val >= 10 and val <= 200 then
            gSettings.grid_size = val;
            settings.save();
       		print(chat.header('grid'):append(chat.message('Target grid size set to ')):append(chat.message(string.format('%d px.', val))));

		else
            print_error('Invalid size parameter. Must be an integer between 10 and 200.');
        end
        return;
    end

    -- Change Major Line Interval: /grid major <interval>
    if sub == 'major' then
        if not args[3] then
            print_error('Missing parameter. Usage: /grid major <1-20>');
            return;
        end
        local val = tonumber(args[3]);
        if val and val >= 1 and val <= 20 then
            gSettings.major_every = val;
            settings.save();
       		print(chat.header('grid'):append(chat.message('Major line interval set to ')):append(chat.message(string.format('%d.', val))));

        else
            print_error('Invalid major line parameter. Must be an integer between 1 and 20.');
        end
        return;
    end

    -- Change Line Thickness: /grid thickness <pixels>
    if sub == 'thickness' or sub == 'thick' then
        if not args[3] then
            print_error('Missing parameter. Usage: /grid thickness <0.5-5.0>');
            return;
        end
        local val = tonumber(args[3]);
        if val and val >= 0.5 and val <= 5.0 then
            gSettings.thickness = val;
            settings.save();
       		print(chat.header('grid'):append(chat.message('Line thickness set to ')):append(chat.message(string.format('%.1f px.', val))));

        else
            print_error('Invalid thickness parameter. Must be a number between 0.5 and 5.0.');
        end
        return;
    end

    -- Unhandled: Print help information..
    print_help(true);
end);