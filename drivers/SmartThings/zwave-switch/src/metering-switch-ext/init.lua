-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=1 })
--- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({ version=3 })
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
local log = require "log"

local METERING_SWITCH_EXT_FINGERPRINTS = {
  {mfr = 0x0109, prod = 0x201A, model = 0x1AA4}  -- Monoprice 15903 Plug
}

local POWER_UNIT_WATT = "W"
local ENERGY_UNIT_KWH = "kWh"
local VOLTAGE_UNIT_V = "V"
local AMPERE_UNIT_A = "A"
local ENERGY_UNIT_KVAH = "kVAh"
local POWER_POWER_FACTOR = "pF"

local function can_handle_metering_switch_ext(opts, driver, device, ...)
  for _, fingerprint in ipairs(METERING_SWITCH_EXT_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
     return true
    end
  end
  return false
end

local function do_refresh(driver, device, command)
    local component = command and command.component and command.component or "main"
    
    device:send_to_component(Meter:Get({ scale = Meter.scale.electric_meter.WATTS }), component)
    device:send_to_component(Meter:Get({ scale = Meter.scale.electric_meter.KILOWATT_HOURS }), component)
    device:send_to_component(Meter:Get({ scale = Meter.scale.electric_meter.VOLTS }), component)
    device:send_to_component(Meter:Get({ scale = Meter.scale.electric_meter.AMPERES }), component)
    device:send_to_component(Meter:Get({ scale = Meter.scale.electric_meter.KILOVOLT_AMPERE_HOURS }), component)
    device:send_to_component(Meter:Get({ scale = Meter.scale.electric_meter.POWER_FACTOR }), component)
    device:send_to_component(Meter:Get({ scale = Meter.scale.electric_meter.PULSE_COUNT }), component)
end

function meter_report_handler(self, device, cmd)
  local event_arguments = nil
  local value
  local unit

  if cmd.args.scale == Meter.scale.electric_meter.KILOWATT_HOURS then
    event_arguments = {
      value = cmd.args.meter_value,
      unit = ENERGY_UNIT_KWH
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.energyMeter.energy(event_arguments)
    )
  elseif cmd.args.scale == Meter.scale.electric_meter.KILOVOLT_AMPERE_HOURS then
     local event_arguments = {
      value = cmd.args.meter_value,
      unit = ENERGY_UNIT_KVAH
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.energyMeter.energy(event_arguments)
    )
  elseif cmd.args.scale == Meter.scale.electric_meter.WATTS then
     local event_arguments = {
      value = cmd.args.meter_value,
      unit = POWER_UNIT_WATT
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.powerMeter.power(event_arguments)
    )
elseif cmd.args.scale == Meter.scale.electric_meter.AMPERES then
    local event_arguments = {
     value = cmd.args.meter_value,
     unit = AMPERE_UNIT_A
   }
   device:emit_event_for_endpoint(
     cmd.src_channel,
     capabilities.currentMeasurement.current(event_arguments)
   )
elseif cmd.args.scale == Meter.scale.electric_meter.POWER_FACTOR then
    local event_arguments = {
     value = cmd.args.meter_value,
     unit = POWER_POWER_FACTOR
   }
--    device:emit_event_for_endpoint(
--      cmd.src_channel,
--      capabilities.powerMeter.power(event_arguments)
--    )
elseif cmd.args.scale == Meter.scale.electric_meter.VOLTS then
     local event_arguments = {
      value = cmd.args.meter_value,
      unit = VOLTAGE_UNIT_V
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.voltageMeasurement.voltage(event_arguments)
    )
  end
end

local metering_switch_ext = {
  supported_capabilities = {
	capabilities.refresh
  },
  zwave_handlers = {
    [cc.METER] = {
      [Meter.REPORT] = meter_report_handler
    }
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    }
  },
  lifecycle_handlers = {
    doConfigure = do_configure,
	infoChanged = info_changed,
	init = device_init
  },
  NAME = "metering switch extended",
  can_handle = can_handle_metering_switch_ext
}

return metering_switch_ext
