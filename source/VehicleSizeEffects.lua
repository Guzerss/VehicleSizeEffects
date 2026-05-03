script_author("Guzers")
script_description("cmd: /vehsize")

local imgui  = require 'mimgui'
local ffi    = require 'ffi'
local hook   = require 'monethook'
local cfg    = require 'jsoncfg'
local samem  = require 'SAMemory'
local gta    = ffi.load('GTASA')

samem.require('CVehicle')
samem.require('matrix')

ffi.cdef[[
    void _ZN8CVehicle6RenderEv(void* vehicle);
    void _Z16RwFrameTranslateP7RwFramePK5RwV3d15RwOpCombineType(void* frame, const RwV3D* translation, int combineOp);
    void _Z12RwFrameScaleP7RwFramePK5RwV3d15RwOpCombineType(void* frame, const RwV3D* scale, int combineOp);
    void _ZNK7CMatrix14CopyToRwMatrixEP11RwMatrixTag(const matrix* thiz, RwMatrix* rwMatrix);
    void _ZN7CEntity13UpdateRwFrameEv(void* entity);
]]

local presets = {
    { name = "Normal",      scale = {1.0,  1.0,  1.0},  zAdj =  0.0   },
    { name = "Tiny",        scale = {0.5,  0.5,  0.5},  zAdj = -0.3   },
    { name = "Super Tiny",  scale = {0.1,  0.1,  0.1},  zAdj = -0.65  },
    { name = "Large",       scale = {2.0,  2.0,  2.0},  zAdj =  0.3   },
    { name = "Wide",        scale = {2.0,  1.0,  1.0},  zAdj =  0.0   },
    { name = "Super Wide",  scale = {3.0,  1.0,  1.0},  zAdj =  0.0   },
    { name = "Tall",        scale = {1.0,  1.0,  2.0},  zAdj =  0.3   },
    { name = "Long",        scale = {1.0,  2.0,  1.0},  zAdj =  0.0   },
    { name = "Paper Thin",  scale = {0.01, 1.0,  1.0},  zAdj =  0.0   },
    { name = "Flat",        scale = {1.0,  1.0,  0.01}, zAdj =  0.0   },
}

local defaultConfig = {
    enabled   = false,
    presetIdx = 1,
}

local config    = cfg.load(defaultConfig, 'VehicleSizeEffects')
cfg.save(config, 'VehicleSizeEffects')

local SW, SH    = getScreenResolution()
local WinState  = imgui.new.bool(false)
local enabled   = imgui.new.bool(config.enabled)
local presetIdx = imgui.new.int(config.presetIdx - 1)
local scaleVec  = ffi.new('RwV3D')
local transVec  = ffi.new('RwV3D')

function saveConfig()
    config.enabled   = enabled[0]
    config.presetIdx = presetIdx[0] + 1
    cfg.save(config, 'VehicleSizeEffects')
end

function getObjectParent(rwObject)
    return ffi.cast('void**', ffi.cast('uintptr_t', rwObject) + 0x4)[0]
end

local vehicleRenderHook
vehicleRenderHook = hook.new(
    'void(*)(void*)',
    function(vehicle)
        if enabled[0] then
            local veh    = ffi.cast('CVehicle*', vehicle)
            local matrix = veh.pMatrix
            local rwObj  = veh.pRwClump
            local frame  = rwObj and getObjectParent(rwObj)
            if matrix and frame then
                local rwMat = ffi.cast('RwMatrix*', ffi.cast('uintptr_t', frame) + 0x10)
                gta._ZNK7CMatrix14CopyToRwMatrixEP11RwMatrixTag(ffi.cast('matrix*', matrix), rwMat)

                local preset = presets[presetIdx[0] + 1]
                transVec.x = 0.0
                transVec.y = 0.0
                transVec.z = preset.zAdj
                scaleVec.x = preset.scale[1]
                scaleVec.y = preset.scale[2]
                scaleVec.z = preset.scale[3]

                gta._Z16RwFrameTranslateP7RwFramePK5RwV3d15RwOpCombineType(frame, transVec, 1)
                gta._Z12RwFrameScaleP7RwFramePK5RwV3d15RwOpCombineType(frame, scaleVec, 1)
                gta._ZN7CEntity13UpdateRwFrameEv(vehicle)
            end
        end
        vehicleRenderHook(vehicle)
    end,
    ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN8CVehicle6RenderEv))
)

imgui.OnFrame(
    function() return WinState[0] end,
    function()
        imgui.SetNextWindowPos(imgui.ImVec2(SW / 2, SH / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.Begin('Vehicle Size Effects', WinState, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
        imgui.PushItemWidth(imgui.GetContentRegionAvail().x)
        if imgui.Checkbox('Enable', enabled) then saveConfig() end
        imgui.Separator()
        for i, p in ipairs(presets) do
           if imgui.RadioButtonIntPtr(p.name, presetIdx, i - 1) then saveConfig() end
        end
        imgui.PopItemWidth()
        imgui.End()
    end
)

function main()
    sampRegisterChatCommand('vehsize', function()
        WinState[0] = not WinState[0]
    end)
    wait(-1)
end

addEventHandler('onScriptTerminate', function(scr)
    if scr == script.this then vehicleRenderHook.stop() end
end)
