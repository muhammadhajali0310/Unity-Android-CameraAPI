function sendFilteredRGBCameraFeedToUnity()
    % 60fps RGB Camera with Orientation Filters to Unity
    % OPTIMIZED FOR LOW LATENCY - Enhanced with parameter selection window first!
    
    % First open parameter selection window
    if ~openParameterSelectionWindow()
        return; % User cancelled
    end
    
    % If we get here, user clicked "Start Streaming" - proceed with Unity connection
    startUnityStreaming();
end

function proceed = openParameterSelectionWindow()
    % Create parameter selection window
    paramFig = figure('Name', 'Filter Parameters - Configure Before Unity Streaming', ...
        'NumberTitle', 'off', 'Position', [200, 200, 400, 750], ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', ...
        'Color', [0.94, 0.94, 0.94]);
    
    % Initialize parameters with defaults
    params = struct('sigma', 19.9*(pi/180), 'filter_type', 2, 'enable_butterworth', 0, ...
                    'center_sf', 1, 'sf_low', 2/3, 'sf_high', 4, 'butterworth_order', 2, ...
                    'horizontal_angle', 0, 'vertical_angle', 90, 'oblique_angle', 45, ...
                    'serverIP', '127.0.0.1', 'serverPort', 8052, 'showPreview', false, ...
                    'dropOldFrames', true, 'maxBufferFrames', 1);
    
    proceed = false; % Will be set to true if user clicks "Start Streaming"
    
    % Title
    uicontrol(paramFig, 'Style', 'text', 'String', 'Configure Filter Parameters', ...
        'Position', [20, 700, 360, 30], 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    % Unity Connection Settings
    control_height = 650;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Unity Connection', ...
        'Position', [20, control_height, 360, 25], 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    uicontrol(paramFig, 'Style', 'text', 'String', 'Server IP:', ...
        'Position', [30, control_height-30, 80, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    ip_edit = uicontrol(paramFig, 'Style', 'edit', 'String', params.serverIP, ...
        'Position', [120, control_height-30, 100, 25], ...
        'Callback', @(src,~) setIP(src.String));
    
    uicontrol(paramFig, 'Style', 'text', 'String', 'Port:', ...
        'Position', [240, control_height-30, 40, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    port_edit = uicontrol(paramFig, 'Style', 'edit', 'String', num2str(params.serverPort), ...
        'Position', [280, control_height-30, 80, 25], ...
        'Callback', @(src,~) setPort(str2double(src.String)));
    
    % Performance Settings
    control_height = control_height - 80;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Performance Settings', ...
        'Position', [20, control_height, 360, 25], 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    preview_cb = uicontrol(paramFig, 'Style', 'checkbox', 'String', 'Show Video Preview (reduces performance)', ...
        'Position', [30, control_height-30, 300, 25], 'Value', params.showPreview, ...
        'Callback', @(src,~) setShowPreview(src.Value), 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    drop_frames_cb = uicontrol(paramFig, 'Style', 'checkbox', 'String', 'Drop old frames for low latency (recommended)', ...
        'Position', [30, control_height-55, 300, 25], 'Value', params.dropOldFrames, ...
        'Callback', @(src,~) setDropFrames(src.Value), 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    % Max buffer setting
    uicontrol(paramFig, 'Style', 'text', 'String', 'Max Buffer:', ...
        'Position', [30, control_height-85, 80, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    
    buffer_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [320, control_height-85, 60, 20], ...
        'String', num2str(params.maxBufferFrames), ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    buffer_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', 1, 'Max', 5, ...
        'Value', params.maxBufferFrames, 'Position', [110, control_height-85, 200, 20], ...
        'Callback', @(src,~) setMaxBuffer(round(src.Value)));
    
    % Filter Width Control
    control_height = control_height - 120;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Filter Width (σ)', ...
        'Position', [20, control_height, 360, 25], 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    sigma_value_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [300, control_height-30, 80, 20], ...
        'String', [num2str(round(params.sigma * (180/pi),1)) '°'], ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    sigma_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', 5, 'Max', 60, ...
        'Value', params.sigma * (180/pi), 'Position', [30, control_height-30, 260, 25], ...
        'Callback', @(src,~) setSigma(src.Value));
    
    % Filter Type Selection
    control_height = control_height - 70;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Filter Orientation', ...
        'Position', [20, control_height, 360, 25], 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    h_radio = uicontrol(paramFig, 'Style', 'radiobutton', 'String', 'Horizontal', ...
        'Position', [30, control_height-30, 80, 25], 'Value', params.filter_type == 1, ...
        'Callback', @(src,~) setFilterType(1), 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    v_radio = uicontrol(paramFig, 'Style', 'radiobutton', 'String', 'Vertical', ...
        'Position', [120, control_height-30, 80, 25], 'Value', params.filter_type == 2, ...
        'Callback', @(src,~) setFilterType(2), 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    o_radio = uicontrol(paramFig, 'Style', 'radiobutton', 'String', 'Oblique', ...
        'Position', [210, control_height-30, 80, 25], 'Value', params.filter_type == 3, ...
        'Callback', @(src,~) setFilterType(3), 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    % Butterworth Filter Controls
    control_height = control_height - 70;
    butterworth_cb = uicontrol(paramFig, 'Style', 'checkbox', 'String', 'Enable Spatial Frequency Filter', ...
        'Position', [20, control_height, 300, 25], 'Value', params.enable_butterworth, ...
        'Callback', @(src,~) enableButterworth(src.Value), 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    % Center Frequency
    control_height = control_height - 40;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Center Frequency:', ...
        'Position', [30, control_height, 120, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    
    center_sf_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [320, control_height, 60, 20], ...
        'String', num2str(params.center_sf), ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    center_sf_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', 0.1, 'Max', 10, ...
        'Value', params.center_sf, 'Position', [150, control_height, 160, 20], ...
        'Callback', @(src,~) setCenterSF(src.Value));
    
    % Bandwidth
    control_height = control_height - 40;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Bandwidth:', ...
        'Position', [30, control_height, 120, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    
    bandwidth_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [300, control_height, 80, 20], ...
        'String', [num2str(params.sf_low) '-' num2str(params.sf_high)], ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    bandwidth_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', 0.5, 'Max', 10, ...
        'Value', params.sf_high - params.sf_low, 'Position', [150, control_height, 160, 20], ...
        'Callback', @(src,~) setBandwidth(src.Value));
    
    % Filter Order
    control_height = control_height - 40;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Filter Order:', ...
        'Position', [30, control_height, 120, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    
    order_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [320, control_height, 60, 20], ...
        'String', num2str(params.butterworth_order), ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    order_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', 1, 'Max', 10, ...
        'Value', params.butterworth_order, 'Position', [150, control_height, 160, 20], ...
        'Callback', @(src,~) setOrder(src.Value));
    
    % Orientation Angles
    control_height = control_height - 60;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Orientation Angles', ...
        'Position', [20, control_height, 360, 25], 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    % Horizontal Angle
    control_height = control_height - 30;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Horizontal:', ...
        'Position', [30, control_height, 80, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    
    h_angle_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [320, control_height, 60, 20], ...
        'String', [num2str(params.horizontal_angle) '°'], ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    h_angle_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', -90, 'Max', 90, ...
        'Value', params.horizontal_angle, 'Position', [110, control_height, 200, 20], ...
        'Callback', @(src,~) setHorizontalAngle(src.Value));
    
    % Vertical Angle
    control_height = control_height - 30;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Vertical:', ...
        'Position', [30, control_height, 80, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    
    v_angle_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [320, control_height, 60, 20], ...
        'String', [num2str(params.vertical_angle) '°'], ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    v_angle_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', 0, 'Max', 180, ...
        'Value', params.vertical_angle, 'Position', [110, control_height, 200, 20], ...
        'Callback', @(src,~) setVerticalAngle(src.Value));
    
    % Oblique Angle
    control_height = control_height - 30;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Oblique:', ...
        'Position', [30, control_height, 80, 20], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.94, 0.94, 0.94]);
    
    o_angle_text = uicontrol(paramFig, 'Style', 'text', ...
        'Position', [320, control_height, 60, 20], ...
        'String', [num2str(params.oblique_angle) '°'], ...
        'HorizontalAlignment', 'right', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    o_angle_slider = uicontrol(paramFig, 'Style', 'slider', 'Min', 0, 'Max', 180, ...
        'Value', params.oblique_angle, 'Position', [110, control_height, 200, 20], ...
        'Callback', @(src,~) setObliqueAngle(src.Value));
    
    % Control visibility function
    function updateControlsVisibility()
        enableState = 'off';
        if params.enable_butterworth
            enableState = 'on';
        end
        set([center_sf_slider, center_sf_text, bandwidth_slider, bandwidth_text, order_slider, order_text], ...
            'Enable', enableState);
    end
    
    % Action Buttons
    control_height = control_height - 80;
    uicontrol(paramFig, 'Style', 'pushbutton', 'String', 'Start Streaming to Unity', ...
    'Position', [50, 50, 150, 40], 'FontSize', 12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.4, 0.8, 0.4], 'ForegroundColor', 'white', ...
    'Callback', @(~,~) startStreaming());
    
    uicontrol(paramFig, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Position', [220, control_height, 100, 40], 'FontSize', 12, ...
        'BackgroundColor', [0.8, 0.4, 0.4], 'ForegroundColor', 'white', ...
        'Callback', @(~,~) cancelSetup());
    
    % Preset Buttons
    control_height = control_height - 60;
    uicontrol(paramFig, 'Style', 'text', 'String', 'Quick Presets:', ...
        'Position', [20, control_height+20, 120, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.94, 0.94, 0.94]);
    
    uicontrol(paramFig, 'Style', 'pushbutton', 'String', 'H-Edge', ...
        'Position', [20, control_height, 60, 25], ...
        'Callback', @(~,~) setPreset('h_edge'));
    
    uicontrol(paramFig, 'Style', 'pushbutton', 'String', 'V-Edge', ...
        'Position', [85, control_height, 60, 25], ...
        'Callback', @(~,~) setPreset('v_edge'));
    
    uicontrol(paramFig, 'Style', 'pushbutton', 'String', 'O-Edge', ...
        'Position', [150, control_height, 60, 25], ...
        'Callback', @(~,~) setPreset('o_edge'));
    
    uicontrol(paramFig, 'Style', 'pushbutton', 'String', 'Lowpass', ...
        'Position', [215, control_height, 60, 25], ...
        'Callback', @(~,~) setPreset('lowpass'));
    
    uicontrol(paramFig, 'Style', 'pushbutton', 'String', 'Highpass', ...
        'Position', [280, control_height, 60, 25], ...
        'Callback', @(~,~) setPreset('highpass'));
    
    % Initialize visibility
    updateControlsVisibility();
    
    % Callback functions
    function setIP(ip_str)
        params.serverIP = ip_str;
    end
    
    function setPort(port_val)
        if ~isnan(port_val) && port_val > 0 && port_val < 65536
            params.serverPort = port_val;
        end
    end
    
    function setShowPreview(val)
        params.showPreview = val;
    end
    
    function setDropFrames(val)
        params.dropOldFrames = val;
    end
    
    function setMaxBuffer(val)
        params.maxBufferFrames = val;
        set(buffer_text, 'String', num2str(val));
    end
    
    function setSigma(val)
        val = round(val * 10) / 10;
        params.sigma = val * (pi/180);
        set(sigma_value_text, 'String', [num2str(val) '°']);
    end
    
    function setFilterType(type)
        params.filter_type = type;
        set(h_radio, 'Value', type == 1);
        set(v_radio, 'Value', type == 2);
        set(o_radio, 'Value', type == 3);
    end
    
    function enableButterworth(val)
        params.enable_butterworth = val;
        updateControlsVisibility();
    end
    
    function setCenterSF(val)
        params.center_sf = val;
        set(center_sf_text, 'String', num2str(round(val*10)/10));
    end
    
    function setBandwidth(val)
        params.sf_low = max(0.1, params.center_sf - val/2);
        params.sf_high = params.center_sf + val/2;
        set(bandwidth_text, 'String', [num2str(round(params.sf_low*10)/10) '-' num2str(round(params.sf_high*10)/10)]);
    end
    
    function setOrder(val)
        params.butterworth_order = round(val);
        set(order_text, 'String', num2str(params.butterworth_order));
    end
    
    function setHorizontalAngle(val)
        params.horizontal_angle = round(val);
        set(h_angle_text, 'String', [num2str(params.horizontal_angle) '°']);
    end
    
    function setVerticalAngle(val)
        params.vertical_angle = round(val);
        set(v_angle_text, 'String', [num2str(params.vertical_angle) '°']);
    end
    
    function setObliqueAngle(val)
        params.oblique_angle = round(val);
        set(o_angle_text, 'String', [num2str(params.oblique_angle) '°']);
    end
    
    function setPreset(preset_name)
        switch preset_name
            case 'h_edge'
                setFilterType(1); setSigma(15); enableButterworth(1);
                setCenterSF(3); setBandwidth(5); setOrder(2);
            case 'v_edge'
                setFilterType(2); setSigma(15); enableButterworth(1);
                setCenterSF(3); setBandwidth(5); setOrder(2);
            case 'o_edge'
                setFilterType(3); setSigma(15); enableButterworth(1);
                setCenterSF(3); setBandwidth(5); setOrder(2);
            case 'lowpass'
                setFilterType(1); setSigma(60); enableButterworth(1);
                setCenterSF(1); setBandwidth(2); setOrder(2);
            case 'highpass'
                setFilterType(1); setSigma(60); enableButterworth(1);
                setCenterSF(5); setBandwidth(8); setOrder(2);
        end
    end
    
    function startStreaming()
        proceed = true;
        % Store params in base workspace for access by main function
        assignin('base', 'unityStreamParams', params);
        delete(paramFig);
    end
    
    function cancelSetup()
        proceed = false;
        delete(paramFig);
    end
    
    % Wait for user decision
    uiwait(paramFig);
end

function startUnityStreaming()
    % Get parameters from base workspace
    if ~evalin('base', 'exist(''unityStreamParams'', ''var'')')
        error('Parameters not found. Please run parameter setup first.');
    end
    params = evalin('base', 'unityStreamParams');
    
    % Camera setup - VERIFIED 60FPS CONFIGURATION
    imaqreset;
    vid = videoinput('winvideo', 1, 'MJPG_960x540');
    src = getselectedsource(vid);
    
    % Set to your camera's 60fps mode
    set(src, 'FrameRate', '60.0002');
    fprintf('Camera set to: %s fps\n', get(src, 'FrameRate'));
    
    % Image dimensions (fixed for this configuration)
    
    width = 960;
    height = 540;
    channels = 3;
    
    fprintf('Camera: %s\nResolution: %dx%d\nChannels: %d\n', ...
        vid.Name, width, height, channels);
    
    % GPU Setup
    try
        gpu = gpuDevice();
        useGPU = true;
        fprintf('Using GPU: %s\n', gpu.Name);
    catch
        error('No compatible GPU found.');
    end
    
    % Pre-compute frequency domain coordinates
    u = single(-floor(width/2):floor((width-1)/2));
    v = single(-floor(height/2):floor((height-1)/2));
    [U, V] = meshgrid(u, v);
    U = gpuArray(U);
    V = gpuArray(V);
    theta = atan2(V, U);
    
    % Conditional GUI Setup based on preview setting
    if params.showPreview
        f = figure('Name', '60fps RGB Filtered Camera to Unity - WITH PREVIEW', ...
            'NumberTitle', 'off', ...
            'Position', [100, 100, 1000, 600], ...
            'CloseRequestFcn', @(src, event) closeApp(), ...
            'Color', [0.94, 0.94, 0.94]);
        
        % Main display area
        displayPanel = uipanel(f, 'Position', [0.02, 0.02, 0.73, 0.96], ...
            'Title', 'Live RGB Filtered Feed', 'FontSize', 12, 'FontWeight', 'bold', ...
            'BackgroundColor', [0.98, 0.98, 0.98]);
        ax = axes('Parent', displayPanel, 'Position', [0.05, 0.05, 0.9, 0.85]);
        
        % Take initial snapshot for display
        preview(vid);
        img = getsnapshot(vid);
        stoppreview(vid);
        
        imgDisplay = imshow(img, 'Parent', ax);
        title(ax, sprintf('RGB Filtered Camera Feed (%dx%d @ 60fps)', width, height), ...
            'FontSize', 11, 'FontWeight', 'bold');
        
        % Control panel position
        controlPanel = uipanel(f, 'Position', [0.76, 0.02, 0.22, 0.96], ...
            'Title', 'Stream Status', 'FontSize', 12, 'FontWeight', 'bold', ...
            'BackgroundColor', [0.95, 0.95, 0.95]);
    else
        % Minimal headless window
        f = figure('Name', '60fps RGB Stream to Unity - HEADLESS MODE', ...
            'NumberTitle', 'off', ...
            'Position', [100, 100, 350, 400], ...
            'CloseRequestFcn', @(src, event) closeApp(), ...
            'Color', [0.94, 0.94, 0.94]);
        
        % Single control panel taking full space
        controlPanel = uipanel(f, 'Position', [0.05, 0.05, 0.9, 0.9], ...
            'Title', 'Headless Stream Status', 'FontSize', 12, 'FontWeight', 'bold', ...
            'BackgroundColor', [0.95, 0.95, 0.95]);
        
        % No image display needed
        imgDisplay = [];
        ax = [];
        
        % Add headless mode indicator
        uicontrol(controlPanel, 'Style', 'text', 'String', '🚀 HEADLESS MODE', ...
            'Position', [15, 320, 280, 30], 'HorizontalAlignment', 'center', ...
            'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', [0, 0.6, 0], ...
            'BackgroundColor', [0.95, 0.95, 0.95]);
        
        uicontrol(controlPanel, 'Style', 'text', 'String', 'No video preview - Maximum performance', ...
            'Position', [15, 300, 280, 20], 'HorizontalAlignment', 'center', ...
            'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    end
    
    % Display current parameters
    if params.showPreview
    control_y_start = 500;
else
    control_y_start = 250;
end
    
    uicontrol(controlPanel, 'Style', 'text', 'String', 'Active Parameters:', ...
        'Position', [15, control_y_start, 180, 25], 'HorizontalAlignment', 'left', ...
        'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    filter_types = {'Horizontal', 'Vertical', 'Oblique'};
    uicontrol(controlPanel, 'Style', 'text', ...
        'String', sprintf('Filter: %s', filter_types{params.filter_type}), ...
        'Position', [15, control_y_start-25, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    uicontrol(controlPanel, 'Style', 'text', ...
        'String', sprintf('Sigma: %.1f°', params.sigma * (180/pi)), ...
        'Position', [15, control_y_start-45, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    if params.enable_butterworth
        uicontrol(controlPanel, 'Style', 'text', ...
            'String', sprintf('SF Filter: %.1f (±%.1f)', params.center_sf, (params.sf_high-params.sf_low)/2), ...
            'Position', [15, control_y_start-65, 180, 20], 'HorizontalAlignment', 'left', ...
            'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    end
    
    % Connection info
    uicontrol(controlPanel, 'Style', 'text', ...
        'String', sprintf('Unity: %s:%d', params.serverIP, params.serverPort), ...
        'Position', [15, control_y_start-100, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    % Performance settings display
    dropFramesText = 'OFF';
    if params.dropOldFrames
        dropFramesText = 'ON';
    end
    
    uicontrol(controlPanel, 'Style', 'text', ...
        'String', sprintf('Drop Frames: %s', dropFramesText), ...
        'Position', [15, control_y_start-120, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    uicontrol(controlPanel, 'Style', 'text', ...
        'String', sprintf('Max Buffer: %d frames', params.maxBufferFrames), ...
        'Position', [15, control_y_start-140, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    % Performance metrics
    perf_y_start = control_y_start - 180;
    uicontrol(controlPanel, 'Style', 'text', 'String', 'Performance Metrics', ...
        'Position', [15, perf_y_start, 180, 25], 'HorizontalAlignment', 'left', ...
        'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    fps_text = uicontrol(controlPanel, 'Style', 'text', 'String', 'FPS: --', ...
        'Position', [15, perf_y_start-25, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    frame_text = uicontrol(controlPanel, 'Style', 'text', 'String', 'Frames: 0', ...
        'Position', [15, perf_y_start-45, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    dropped_text = uicontrol(controlPanel, 'Style', 'text', 'String', 'Dropped: 0', ...
        'Position', [15, perf_y_start-65, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    processing_text = uicontrol(controlPanel, 'Style', 'text', 'String', 'Processing: RGB+GPU', ...
        'Position', [15, perf_y_start-85, 180, 20], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'BackgroundColor', [0.95, 0.95, 0.95]);
    
    % Connection status
    status_text = uicontrol(controlPanel, 'Style', 'text', ...
        'String', 'Status: Starting...', ...
        'Position', [15, 50, 180, 30], 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [1, 0.8, 0.8], 'ForegroundColor', [0.8, 0, 0]);
    
    % Initialize variables
    H_orientation = [];
    frameCount = 0;
    droppedFrameCount = 0;
    tic; % Start timing for FPS calculation
    running = true;
    
    % Frame buffer for dropping old frames
    frameBuffer = [];
    maxBufferSize = params.maxBufferFrames;
    
    % Utility function
    function result = ternary(condition, true_val, false_val)
        if condition
            result = true_val;
        else
            result = false_val;
        end
    end
    
    % Update filter based on selected parameters
    function updateFilter()
    if params.filter_type == 1
        % Horizontal filter - removes horizontal orientations (keeps vertical)
        angle_rad = params.horizontal_angle * (pi/180);
        H_orientation = exp(-(cos(theta - angle_rad).^2) / (2 * params.sigma^2));
    elseif params.filter_type == 2
        % Vertical filter - removes vertical orientations (keeps horizontal)
        angle_rad = params.vertical_angle * (pi/180);
        H_orientation = exp(-(cos(theta - angle_rad).^2) / (2 * params.sigma^2));  % Changed from sin to cos
    else
        % Oblique filter
        angle_rad = params.oblique_angle * (pi/180);
        H_orientation = exp(-(cos(2*(theta - angle_rad)).^2) / (2 * params.sigma^2));
    end
        
        if params.enable_butterworth
            U_cpd = U / (width/30);  % Assuming 30 deg FOV
            V_cpd = V / (height/20); % Assuming 20 deg FOV  
            sf = sqrt(U_cpd.^2 + V_cpd.^2);
            sf_filter = 1 ./ (1 + ((sf - params.center_sf) ./ ((params.sf_high - params.sf_low)/2)).^(2*params.butterworth_order));
            H_orientation = H_orientation .* sf_filter;
        end
    end
    
    function closeApp()
        running = false;
        delete(f);
    end
    
    function updatePerformanceMetrics()
        elapsed = toc;
        if elapsed > 1 % Update every second
            fps = frameCount / elapsed;
            set(fps_text, 'String', sprintf('FPS: %.1f', fps));
            set(frame_text, 'String', sprintf('Sent: %d', frameCount));
            set(dropped_text, 'String', sprintf('Dropped: %d', droppedFrameCount));
            tic; % Reset timer
            frameCount = 0;
            droppedFrameCount = 0;
        end
    end
    
    % Initialize filter
    updateFilter();
    
    % OPTIMIZED Camera configuration for low latency
    set(vid, 'FramesPerTrigger', 1);  % Get one frame at a time (was Inf)
    set(vid, 'TriggerRepeat', Inf);
    
    % Set smaller buffer to reduce latency
    triggerconfig(vid, 'immediate');
    set(vid, 'TimerFcn', '');  % Remove any timer callbacks
    set(vid, 'TimerPeriod', 0.01);  % Minimal timer period
    
    start(vid);
    
    % Connection loop with LATENCY OPTIMIZATIONS
    while running
        try
            % Create TCP connection with optimized settings
            tcpClient = tcpclient(params.serverIP, params.serverPort, 'Timeout', 10);
            
            % Configure TCP for low latency
            configureCallback(tcpClient, 'off');  % Disable callbacks for speed
            
            set(status_text, 'String', 'Status: Connected', ...
                'BackgroundColor', [0.8, 1, 0.8], 'ForegroundColor', [0, 0.6, 0]);
            
            % Send metadata
            metadataBytes = [typecast(int32(width), 'uint8'), typecast(int32(height), 'uint8')];
            write(tcpClient, metadataBytes);

            frameCount = 0;
            lastDisplayUpdate = tic;

            while running && ishandle(f)
                % OPTIMIZED frame acquisition - check if new data available
                if isrunning(vid) && vid.FramesAvailable > 0
                    % Get the most recent frame and discard older ones if buffer enabled
                    if params.dropOldFrames && vid.FramesAvailable > maxBufferSize
                        % Drop old frames by getting all available and keeping only the latest
                        oldFrames = getdata(vid, vid.FramesAvailable);
                        if size(oldFrames, 4) > 0
                            img = oldFrames(:,:,:,end);  % Keep only the most recent
                            droppedFrameCount = droppedFrameCount + size(oldFrames, 4) - 1;
                        else
                            img = oldFrames;
                        end
                    else
                        % Get single frame normally
                        img = getdata(vid, 1);
                        if size(img, 4) > 0
                            img = img(:,:,:,end);
                        end
                    end
                    
                    frameCount = frameCount + 1;

                    % GPU-accelerated RGB processing (keep all 3 channels)
                    imgGPU = gpuArray(single(img) / 255);

                    % Apply orientation filter to each RGB channel separately
                    filtered_img = applyOrientationFilterRGB(imgGPU, H_orientation);
                    
                    % Update display only occasionally and only if preview enabled
                    if params.showPreview && toc(lastDisplayUpdate) > 0.033  % ~30fps for display
                        display_img = gather(filtered_img);
                        set(imgDisplay, 'CData', display_img);
                        lastDisplayUpdate = tic;
                    end

                    % Prepare and send RGB data to Unity immediately
                    rawBytes = prepareRGBForUnity(filtered_img);
                    dataSize = length(rawBytes);
                    
                    % Send data immediately without buffering
                    write(tcpClient, typecast(int32(dataSize), 'uint8'));
                    write(tcpClient, rawBytes);
                    
                    % Update performance metrics less frequently
                    if mod(frameCount, 30) == 0
                        updatePerformanceMetrics();
                    end
                else
                    % No new frame available, yield briefly to prevent busy waiting
                    pause(0.001);
                end
            end
        catch exception
            if ~running || ~ishandle(f), break; end
            set(status_text, 'String', ['Error: ', exception.message], ...
                'BackgroundColor', [1, 0.8, 0.8], 'ForegroundColor', [0.8, 0, 0]);
            pause(1);
        end
        clear tcpClient;
    end

    % Cleanup
    if exist('vid', 'var') && isvalid(vid)
        if isrunning(vid)
            stop(vid);
        end
        delete(vid);
    end
    gpuDevice([]);
    
    % Clean up base workspace
    evalin('base', 'clear unityStreamParams');
end

function filtered_img = applyOrientationFilterRGB(imgRGB, H_orientation)
    % Apply orientation filter to each RGB channel separately
    % Input: imgRGB is HxWx3 on GPU
    % Output: filtered_img is HxWx3 on GPU
    
    % Pre-allocate output
    filtered_img = zeros(size(imgRGB), 'single', 'gpuArray');
    
    % Process each channel independently
    for channel = 1:3
        % Extract single channel
        single_channel = imgRGB(:,:,channel);
        
        % Apply frequency domain filtering
        F = fft2(single_channel);
        F_shifted = fftshift(F);
        F_filtered = F_shifted .* H_orientation;
        filtered_channel = real(ifft2(ifftshift(F_filtered)));
        
        % Normalize each channel independently
        ch_min = min(filtered_channel(:));
        ch_max = max(filtered_channel(:));
        filtered_channel = (filtered_channel - ch_min) / (ch_max - ch_min + eps('single'));
        
        % Store in output
        filtered_img(:,:,channel) = filtered_channel;
    end
end

function rawBytes = prepareRGBForUnity(imgRGB)
    % Prepare RGB data for Unity (no conversion needed, already RGB)
    % Input: imgRGB is HxWx3 on GPU (values 0-1)
    % Output: rawBytes ready for Unity
    
    % Transfer to CPU and convert to uint8
    imgRGB_cpu = gather(imgRGB);
    rgbData = uint8(imgRGB_cpu * 255);
    
    % Reshape for Unity: [R,G,B,R,G,B,...] format
    % Unity expects data in column-major order with RGB interleaved
    rawBytes = reshape(permute(rgbData, [3, 2, 1]), [], 1);
end