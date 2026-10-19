import Foundation

/// The weekly walk-round, in the order somebody actually walks a generator room: the fuel end,
/// then the engine, then the electrical end, then the room itself, and finally the controller.
///
/// The controller item is last on purpose. It is the one that makes every other record on this
/// page meaningless if it is wrong, so it is the answer the technician leaves with rather than
/// the one they skip past on the way in.
///
/// These are field prompts written for someone standing at the set. NFPA 110 Chapter 8 is the
/// authority; this list is not a reprint of it.
enum WeeklyItem: String, CaseIterable, Identifiable {
    // Fuel
    case fuelLevel, fuelSystem
    // Engine
    case lubeOilLevel, coolantLevel, blockHeater, beltsAndHoses, noLeaks
    // Electrical
    case batteryCondition, batteryCharger, batteryElectrolyte
    // The room
    case louvresAndVentilation, exhaustSystem, accessAndHousekeeping
    // The controller
    case controllerAlarms, controllerInAuto

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fuelLevel: return "Fuel level"
        case .fuelSystem: return "Fuel system and day tank"
        case .lubeOilLevel: return "Lube oil level"
        case .coolantLevel: return "Coolant level"
        case .blockHeater: return "Block heater"
        case .beltsAndHoses: return "Belts and hoses"
        case .noLeaks: return "No leaks under the set"
        case .batteryCondition: return "Battery terminals and condition"
        case .batteryCharger: return "Battery charger operating"
        case .batteryElectrolyte: return "Battery electrolyte and specific gravity"
        case .louvresAndVentilation: return "Louvres and ventilation"
        case .exhaustSystem: return "Exhaust system"
        case .accessAndHousekeeping: return "Access and housekeeping"
        case .controllerAlarms: return "Controller free of alarms"
        case .controllerInAuto: return "Controller in AUTO"
        }
    }

    var hint: String {
        switch self {
        case .fuelLevel: return "Main tank and day tank, against the hours your Class calls for. Note the reading, not just that you looked."
        case .fuelSystem: return "Lines, filters, the day tank float and the fuel solenoid. Water in the bottom of a diesel tank is the quiet one."
        case .lubeOilLevel: return "On the dipstick, cold, with the set level."
        case .coolantLevel: return "In the expansion tank, and the concentration if you have a refractometer to hand."
        case .blockHeater: return "Energised and the jacket warm to the touch. A cold block is the reason a set fails to take load in ten seconds."
        case .beltsAndHoses: return "Tension, cracking, chafing, and the hose clamps."
        case .noLeaks: return "Oil, fuel and coolant under the set and around the skid. A drip pan with fresh liquid in it is a finding."
        case .batteryCondition: return "Terminals clean and tight, case not swollen, cables not chafed."
        case .batteryCharger: return "Charger energised, on float, and the ammeter where you expect it."
        case .batteryElectrolyte: return "Level over the plates and specific gravity, where the battery type allows it."
        case .louvresAndVentilation: return "Intake and discharge louvres free to move, dampers operating, nothing stacked against them."
        case .exhaustSystem: return "Supports, insulation, no soot tracks at the joints, condensate trap drained."
        case .accessAndHousekeeping: return "Nothing stored in the room that does not belong there and nothing blocking the way to the set."
        case .controllerAlarms: return "No alarms or warnings standing on the controller, and the display readable."
        case .controllerInAuto: return "The selector in AUTO, not OFF and not MANUAL. A set left in either after a test will not start when the power fails."
        }
    }

    /// The group heading on the weekly screen, which is how the walk actually goes.
    var section: WeeklySection {
        switch self {
        case .fuelLevel, .fuelSystem: return .fuel
        case .lubeOilLevel, .coolantLevel, .blockHeater, .beltsAndHoses, .noLeaks: return .engine
        case .batteryCondition, .batteryCharger, .batteryElectrolyte: return .electrical
        case .louvresAndVentilation, .exhaustSystem, .accessAndHousekeeping: return .room
        case .controllerAlarms, .controllerInAuto: return .controller
        }
    }

    /// Items that do not apply to a set fed from a gas main.
    func applies(to fuel: FuelType) -> Bool {
        switch self {
        case .fuelLevel: return fuel.isStored
        default: return true
        }
    }

    static func items(for fuel: FuelType) -> [WeeklyItem] {
        allCases.filter { $0.applies(to: fuel) }
    }

    static func items(in section: WeeklySection, for fuel: FuelType) -> [WeeklyItem] {
        items(for: fuel).filter { $0.section == section }
    }
}

enum WeeklySection: String, CaseIterable, Identifiable {
    case fuel, engine, electrical, room, controller

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fuel: return "Fuel"
        case .engine: return "Engine"
        case .electrical: return "Batteries and charger"
        case .room: return "Room and exhaust"
        case .controller: return "Controller"
        }
    }

    var symbol: String {
        switch self {
        case .fuel: return "fuelpump"
        case .engine: return "engine.combustion"
        case .electrical: return "minus.plus.batteryblock"
        case .room: return "wind"
        case .controller: return "switch.2"
        }
    }
}
