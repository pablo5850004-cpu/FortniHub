-- ===== EXPOSE GLOBALS для two.lua =====
getgenv().FH = {
    Options = Options, Window = Window, Tabs = Tabs,
    Notify = Notify, GetRole = GetRole, GetRoleColor = GetRoleColor,
    GetHRP = GetHRP, GetHum = GetHum, L = L,
    AddConnection = AddConnection, Connections = Connections,
    LocalPlayer = LocalPlayer, Players = Players,
    RunService = RunService, UserInputService = UserInputService,
    ReplicatedStorage = ReplicatedStorage, VirtualUser = VirtualUser,
    Workspace = Workspace, CoreGui = CoreGui, Camera = Camera,
    THEME = THEME, VERSION = VERSION,
    ModuleNameToTitle = ModuleNameToTitle,
    logInfo = logInfo, logWarn = logWarn, logErr = logErr,
    safeHttpGet = safeHttpGet, safeLoadstring = safeLoadstring, safeRun = safeRun,
    MobileUI = MobileUI, Lighting = Lighting,
}
logInfo("Глобалы экспортированы для two.lua")
logInfo("Скрипт полностью загружен")
