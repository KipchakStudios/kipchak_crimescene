Config = {}

Config.Framework = 'auto'
Config.Locale = 'en'

Config.AllowedJobs = {
    police = 0,
    sheriff = 0
}

Config.RequireOnDuty = true

Config.Permissions = {
    RemoveOthersGrade = 2,
    ClearSceneGrade = 3,
    MaxClearRadius = 150.0,
    InteractDistance = 10.0,
    AdminAce = 'kipchak_crimescene.admin'
}

Config.Commands = {
    Menu = { Enabled = true, Name = 'scene' },
    ClearScene = { Enabled = true, Name = 'clearscene' }
}

Config.Keybind = {
    Enabled = true,
    Key = ''
}

Config.Menu = {
    Marker = true,
    Tape = true,
    Props = true,
    Remove = true,
    Clear = true
}

Config.Target = {
    Enabled = true,
    System = 'auto',
    Distance = 2.5,
    Remove = true,
    Note = true,
    Info = true
}

Config.Placement = {
    MaxDistance = 8.0,
    RayDistance = 15.0,
    ChainPlacement = true,
    MaxSlope = 40.0,
    RotateSpeed = 90.0,
    WheelStep = 10.0,
    FineMultiplier = 0.15,
    GhostAlpha = 170,
    InvalidAlpha = 90,
    ValidColor = { 80, 220, 120 },
    InvalidColor = { 235, 60, 60 },
    TextUIPosition = 'right-center',
    Controls = {
        Confirm = { 24, 191 },
        Cancel = { 25, 194 },
        RotateLeft = { 44 },
        RotateRight = { 38 },
        WheelLeft = { 15 },
        WheelRight = { 14 },
        Fine = { 21 },
        TapeFinish = { 47 },
        TapeClose = { 74 },
        EditNote = { 47 }
    },
    KeyLabels = {
        Confirm = 'LMB / ENTER',
        Cancel = 'RMB / BACKSPACE',
        Rotate = 'Q / E / WHEEL',
        Fine = 'SHIFT',
        TapeFinish = 'G',
        TapeClose = 'H',
        EditNote = 'G'
    }
}

Config.Markers = {
    Enabled = true,
    -- Default: ch_prop_ch_fib_01a, the small yellow base game evidence marker (needs game build 2060+).
    -- Other base game candidates: 'prop_roadcone02c' (small cone), 'prop_mp_cone_04' (small race cone), 'prop_air_conelight' (small airport cone light).
    -- Your own streamed marker works too, see "Using your own props" in the README.
    Model = 'ch_prop_ch_fib_01a',
    Models = {},
    FallbackModel = 'prop_roadcone02c',
    -- 'auto' draws the number just above the top of the model, a number sets the height above the ground in meters.
    TextOffset = 'auto',
    TextDistance = 12.0,
    TextScale = 0.42,
    TextColor = { 255, 214, 0, 255 },
    Notes = {
        Enabled = true,
        AskOnPlace = false,
        MaxLength = 50,
        Distance = 5.0,
        Color = { 240, 240, 240, 230 }
    },
    Info = {
        Enabled = true,
        Distance = 2.5,
        Color = { 170, 200, 255, 230 }
    }
}

Config.Sanitize3DText = true

Config.Scene = {
    Radius = 60.0,
    ExpireMinutes = 60
}

Config.Tape = {
    Enabled = true,
    PoleModel = 'prop_roadcone02a',
    Height = 'auto',
    Thickness = 0.12,
    TextureRatio = 16.0,
    DrawDistance = 60.0,
    MaxSegment = 15.0,
    MaxPolesPerTape = 30,
    PreviewAlpha = 140,
    DefaultStyle = 'police',
    Styles = {
        police = { label = 'POLICE LINE - DO NOT CROSS', texture = 'tape_police', color = { 255, 255, 255 }, alpha = 255 },
        crime_scene = { label = 'CRIME SCENE - DO NOT CROSS', texture = 'tape_crime_scene', color = { 255, 255, 255 }, alpha = 255 },
        polis_tr = { label = 'POLİS - GİRMEYİNİZ', texture = 'tape_polis_tr', color = { 255, 255, 255 }, alpha = 255 }
    }
}

Config.Props = {
    { label = 'Traffic Cone', model = 'prop_roadcone02a', icon = 'triangle-exclamation' },
    { label = 'Road Barrier', model = 'prop_barrier_work06a', icon = 'road-barrier' },
    { label = 'Work Barrier', model = 'prop_barrier_work05', icon = 'road-barrier' },
    { label = 'Work Light', model = 'prop_worklight_03b', icon = 'lightbulb' },
    { label = 'Road Sign', model = 'prop_snow_sign_road_06g', icon = 'sign-hanging' },
    { label = 'Gazebo', model = 'prop_gazebo_03', icon = 'tent' }
}

Config.Streaming = {
    Distance = 80.0,
    Interval = 1000
}

Config.Limits = {
    MaxPerPlayer = 60,
    MaxMarkersPerScene = 40,
    MaxTotal = 600,
    PlaceCooldown = 300,
    RateLimit = { Count = 20, Window = 10 }
}

Config.Persistence = false

Config.Logs = {
    Enabled = false,
    Place = true,
    Remove = true,
    Clear = true
}
