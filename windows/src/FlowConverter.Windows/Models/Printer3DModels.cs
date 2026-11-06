// FlowConverter - Clean-Room 100% MIT Open Source
// Models/Printer3DModels.cs - 3D Printer Profiles, 84-Model Catalog, and .3MF Metadata Models
#nullable enable

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Models;

/// <summary>
/// Represents a 3D printer hardware model and bed configuration.
/// </summary>
public class Printer3DModel
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Brand { get; set; } = "Anycubic";
    public string Name { get; set; } = "Anycubic Kobra X";
    public string ShortWheelName { get; set; } = "Kobra X";
    public int BedWidthMM { get; set; } = 256;
    public int BedDepthMM { get; set; } = 256;
    public int BedHeightMM { get; set; } = 256;
    public double NozzleDiameterMM { get; set; } = 0.4;
    public string GcodeFlavor { get; set; } = "marlin"; // "marlin", "klipper", "reprapfirmware"
    public string PrinterSettingsID { get; set; } = "";
    public bool ShowInWheel { get; set; } = true;
    public bool IsCustom { get; set; } = false;

    public Printer3DModel() { }

    public Printer3DModel(
        string? id = null,
        string brand = "Anycubic",
        string name = "Anycubic Kobra X",
        string shortWheelName = "Kobra X",
        int bedWidthMM = 256,
        int bedDepthMM = 256,
        int bedHeightMM = 256,
        double nozzleDiameterMM = 0.4,
        string gcodeFlavor = "marlin",
        string? printerSettingsID = null,
        bool showInWheel = true,
        bool isCustom = false)
    {
        Id = id ?? Guid.NewGuid().ToString();
        Brand = brand;
        Name = name;
        ShortWheelName = shortWheelName;
        BedWidthMM = bedWidthMM;
        BedDepthMM = bedDepthMM;
        BedHeightMM = bedHeightMM;
        NozzleDiameterMM = nozzleDiameterMM;
        GcodeFlavor = gcodeFlavor;
        PrinterSettingsID = printerSettingsID ?? $"{name} {nozzleDiameterMM:0.1} nozzle";
        ShowInWheel = showInWheel;
        IsCustom = isCustom;
    }

    public string BedSizeLabel => $"{BedWidthMM:0}×{BedDepthMM:0}×{BedHeightMM:0} mm";

    public string DimensionsSummary => $"{BedWidthMM}×{BedDepthMM}×{BedHeightMM} mm · {NozzleDiameterMM:0.1}mm";

    public string SanitizedFileSuffix
    {
        get
        {
            string baseName = string.IsNullOrWhiteSpace(ShortWheelName) ? Name : ShortWheelName;
            string cleaned = Regex.Replace(baseName, @"[^A-Za-z0-9_-]+", "_").Trim('_');
            return string.IsNullOrEmpty(cleaned) ? "Printer" : cleaned;
        }
    }

    public static readonly List<string> ManufacturerList = new()
    {
        "Anycubic",
        "Bambu Lab",
        "Creality",
        "Flashforge",
        "Elegoo",
        "Prusa",
        "Qidi Tech",
        "Sovol",
        "Artillery",
        "Flsun",
        "Voron",
        "Two Trees",
        "Personalizada"
    };

    public static List<Printer3DModel> ModelsForBrand(string brand) =>
        AllPresetModels.Where(p => string.Equals(p.Brand, brand, StringComparison.OrdinalIgnoreCase)).ToList();

    public static readonly List<Printer3DModel> AllPresetModels = new()
    {
        // MARK: Anycubic (24 models)
        new Printer3DModel("anycubic-kobra-x", "Anycubic", "Anycubic Kobra X", "Kobra X", 260, 260, 260, 0.4, "klipper", "Anycubic Kobra X 0.4 nozzle", true),
        new Printer3DModel("anycubic-kobra-4", "Anycubic", "Anycubic Kobra 4", "Kobra 4", 260, 260, 260, 0.4, "klipper", "Anycubic Kobra 4 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-3", "Anycubic", "Anycubic Kobra 3", "Kobra 3", 250, 250, 260, 0.4, "klipper", "Anycubic Kobra 3 0.4 nozzle", true),
        new Printer3DModel("anycubic-kobra-3-v2", "Anycubic", "Anycubic Kobra 3 V2", "Kobra 3 V2", 250, 250, 260, 0.4, "klipper", "Anycubic Kobra 3 V2 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-3-combo", "Anycubic", "Anycubic Kobra 3 Combo", "Kobra 3 Combo", 250, 250, 260, 0.4, "klipper", "Anycubic Kobra 3 Combo 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-3-max", "Anycubic", "Anycubic Kobra 3 Max", "Kobra 3 Max", 420, 420, 500, 0.4, "klipper", "Anycubic Kobra 3 Max 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-3-max-v2", "Anycubic", "Anycubic Kobra 3 Max V2", "Kobra 3M V2", 420, 420, 500, 0.4, "klipper", "Anycubic Kobra 3 Max V2 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-s1", "Anycubic", "Anycubic Kobra S1", "Kobra S1", 250, 250, 250, 0.4, "klipper", "Anycubic Kobra S1 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-s1-max", "Anycubic", "Anycubic Kobra S1 Max", "Kobra S1 Max", 300, 300, 300, 0.4, "klipper", "Anycubic Kobra S1 Max 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-s1-combo", "Anycubic", "Anycubic Kobra S1 Combo", "Kobra S1C", 250, 250, 250, 0.4, "klipper", "Anycubic Kobra S1 Combo 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-2-pro", "Anycubic", "Anycubic Kobra 2 Pro", "Kobra 2 Pro", 220, 220, 250, 0.4, "klipper", "Anycubic Kobra 2 Pro 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-2-plus", "Anycubic", "Anycubic Kobra 2 Plus", "Kobra 2+", 320, 320, 400, 0.4, "klipper", "Anycubic Kobra 2 Plus 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-2-max", "Anycubic", "Anycubic Kobra 2 Max", "Kobra 2 Max", 420, 420, 500, 0.4, "klipper", "Anycubic Kobra 2 Max 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-2", "Anycubic", "Anycubic Kobra 2", "Kobra 2", 220, 220, 250, 0.4, "marlin", "Anycubic Kobra 2 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-2-neo", "Anycubic", "Anycubic Kobra 2 Neo", "Kobra 2 Neo", 220, 220, 250, 0.4, "marlin", "Anycubic Kobra 2 Neo 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra", "Anycubic", "Anycubic Kobra", "Kobra", 220, 220, 250, 0.4, "marlin", "Anycubic Kobra 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-neo", "Anycubic", "Anycubic Kobra Neo", "Kobra Neo", 220, 220, 250, 0.4, "marlin", "Anycubic Kobra Neo 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-go", "Anycubic", "Anycubic Kobra Go", "Kobra Go", 220, 220, 250, 0.4, "marlin", "Anycubic Kobra Go 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-plus", "Anycubic", "Anycubic Kobra Plus", "Kobra Plus", 300, 300, 350, 0.4, "marlin", "Anycubic Kobra Plus 0.4 nozzle", false),
        new Printer3DModel("anycubic-kobra-max", "Anycubic", "Anycubic Kobra Max", "Kobra Max", 400, 400, 450, 0.4, "marlin", "Anycubic Kobra Max 0.4 nozzle", false),
        new Printer3DModel("anycubic-vyper", "Anycubic", "Anycubic Vyper", "Vyper", 245, 245, 260, 0.4, "marlin", "Anycubic Vyper 0.4 nozzle", false),
        new Printer3DModel("anycubic-chiron", "Anycubic", "Anycubic Chiron", "Chiron", 400, 400, 450, 0.4, "marlin", "Anycubic Chiron 0.4 nozzle", false),
        new Printer3DModel("anycubic-mega-s", "Anycubic", "Anycubic i3 Mega S", "Mega S", 210, 210, 205, 0.4, "marlin", "Anycubic i3 Mega S 0.4 nozzle", false),
        new Printer3DModel("anycubic-mega-x", "Anycubic", "Anycubic Mega X", "Mega X", 300, 300, 305, 0.4, "marlin", "Anycubic Mega X 0.4 nozzle", false),

        // MARK: Bambu Lab (8 models)
        new Printer3DModel("bambu-a1-mini", "Bambu Lab", "Bambu Lab A1 mini", "A1 mini", 180, 180, 180, 0.4, "marlin", "Bambu Lab A1 mini 0.4 nozzle", true),
        new Printer3DModel("bambu-a1", "Bambu Lab", "Bambu Lab A1", "Bambu A1", 256, 256, 256, 0.4, "marlin", "Bambu Lab A1 0.4 nozzle", true),
        new Printer3DModel("bambu-p1s", "Bambu Lab", "Bambu Lab P1S", "Bambu P1S", 256, 256, 256, 0.4, "marlin", "Bambu Lab P1S 0.4 nozzle", true),
        new Printer3DModel("bambu-p1p", "Bambu Lab", "Bambu Lab P1P", "Bambu P1P", 256, 256, 256, 0.4, "marlin", "Bambu Lab P1P 0.4 nozzle", false),
        new Printer3DModel("bambu-x1c", "Bambu Lab", "Bambu Lab X1 Carbon", "X1 Carbon", 256, 256, 256, 0.4, "marlin", "Bambu Lab X1 Carbon 0.4 nozzle", true),
        new Printer3DModel("bambu-x1e", "Bambu Lab", "Bambu Lab X1E", "Bambu X1E", 256, 256, 256, 0.4, "marlin", "Bambu Lab X1E 0.4 nozzle", false),
        new Printer3DModel("bambu-x1", "Bambu Lab", "Bambu Lab X1", "Bambu X1", 256, 256, 256, 0.4, "marlin", "Bambu Lab X1 0.4 nozzle", false),
        new Printer3DModel("bambu-h2d", "Bambu Lab", "Bambu Lab H2D", "Bambu H2D", 350, 320, 325, 0.4, "marlin", "Bambu Lab H2D 0.4 nozzle", false),

        // MARK: Creality (19 models)
        new Printer3DModel("creality-k1", "Creality", "Creality K1", "Creality K1", 220, 220, 250, 0.4, "klipper", "Creality K1 0.4 nozzle", true),
        new Printer3DModel("creality-k1c", "Creality", "Creality K1C", "Creality K1C", 220, 220, 250, 0.4, "klipper", "Creality K1C 0.4 nozzle", false),
        new Printer3DModel("creality-k1-se", "Creality", "Creality K1 SE", "K1 SE", 220, 220, 250, 0.4, "klipper", "Creality K1 SE 0.4 nozzle", false),
        new Printer3DModel("creality-k1-max", "Creality", "Creality K1 Max", "K1 Max", 300, 300, 300, 0.4, "klipper", "Creality K1 Max 0.4 nozzle", true),
        new Printer3DModel("creality-k2-plus", "Creality", "Creality K2 Plus", "K2 Plus", 350, 350, 350, 0.4, "klipper", "Creality K2 Plus 0.4 nozzle", false),
        new Printer3DModel("creality-hi", "Creality", "Creality Hi", "Creality Hi", 260, 260, 300, 0.4, "klipper", "Creality Hi 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-v3", "Creality", "Creality Ender-3 V3", "Ender-3 V3", 220, 220, 250, 0.4, "klipper", "Creality Ender-3 V3 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-v3-ke", "Creality", "Creality Ender-3 V3 KE", "Ender-3 KE", 220, 220, 240, 0.4, "klipper", "Creality Ender-3 V3 KE 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-v3-se", "Creality", "Creality Ender-3 V3 SE", "Ender-3 SE", 220, 220, 250, 0.4, "marlin", "Creality Ender-3 V3 SE 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-v3-plus", "Creality", "Creality Ender-3 V3 Plus", "Ender-3 V3+", 300, 300, 330, 0.4, "klipper", "Creality Ender-3 V3 Plus 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-s1-pro", "Creality", "Creality Ender-3 S1 Pro", "Ender-3 S1P", 220, 220, 270, 0.4, "marlin", "Creality Ender-3 S1 Pro 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-s1", "Creality", "Creality Ender-3 S1", "Ender-3 S1", 220, 220, 270, 0.4, "marlin", "Creality Ender-3 S1 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-s1-plus", "Creality", "Creality Ender-3 S1 Plus", "Ender-3 S1+", 300, 300, 300, 0.4, "marlin", "Creality Ender-3 S1 Plus 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-v2", "Creality", "Creality Ender-3 V2", "Ender-3 V2", 220, 220, 250, 0.4, "marlin", "Creality Ender-3 V2 0.4 nozzle", false),
        new Printer3DModel("creality-ender3", "Creality", "Creality Ender-3", "Ender-3", 220, 220, 250, 0.4, "marlin", "Creality Ender-3 0.4 nozzle", false),
        new Printer3DModel("creality-ender5-s1", "Creality", "Creality Ender-5 S1", "Ender-5 S1", 220, 220, 280, 0.4, "marlin", "Creality Ender-5 S1 0.4 nozzle", false),
        new Printer3DModel("creality-ender5-max", "Creality", "Creality Ender-5 Max", "Ender-5 Max", 400, 400, 400, 0.4, "klipper", "Creality Ender-5 Max 0.4 nozzle", false),
        new Printer3DModel("creality-cr10-se", "Creality", "Creality CR-10 SE", "CR-10 SE", 220, 220, 265, 0.4, "klipper", "Creality CR-10 SE 0.4 nozzle", false),
        new Printer3DModel("creality-cr10-smart-pro", "Creality", "Creality CR-10 Smart Pro", "CR-10 Smart", 300, 300, 400, 0.4, "marlin", "Creality CR-10 Smart Pro 0.4 nozzle", false),

        // MARK: Flashforge (5 models)
        new Printer3DModel("flashforge-adv5m-pro", "Flashforge", "Flashforge Adventurer 5M Pro", "Adv 5M Pro", 220, 220, 220, 0.4, "klipper", "Flashforge Adventurer 5M Pro 0.4 nozzle", true),
        new Printer3DModel("flashforge-adv5m", "Flashforge", "Flashforge Adventurer 5M", "Adv 5M", 220, 220, 220, 0.4, "klipper", "Flashforge Adventurer 5M 0.4 nozzle", false),
        new Printer3DModel("flashforge-ad5x", "Flashforge", "Flashforge AD5X", "AD5X", 220, 220, 220, 0.4, "klipper", "Flashforge AD5X 0.4 nozzle", false),
        new Printer3DModel("flashforge-guider3-ultra", "Flashforge", "Flashforge Guider 3 Ultra", "Guider 3U", 330, 330, 600, 0.4, "klipper", "Flashforge Guider 3 Ultra 0.4 nozzle", false),
        new Printer3DModel("flashforge-adv4-pro", "Flashforge", "Flashforge Adventurer 4 Pro", "Adv 4 Pro", 220, 200, 250, 0.4, "marlin", "Flashforge Adventurer 4 Pro 0.4 nozzle", false),

        // MARK: Elegoo (8 models)
        new Printer3DModel("elegoo-neptune4-pro", "Elegoo", "Elegoo Neptune 4 Pro", "Neptune 4P", 225, 225, 265, 0.4, "klipper", "Elegoo Neptune 4 Pro 0.4 nozzle", false),
        new Printer3DModel("elegoo-neptune4", "Elegoo", "Elegoo Neptune 4", "Neptune 4", 225, 225, 265, 0.4, "klipper", "Elegoo Neptune 4 0.4 nozzle", false),
        new Printer3DModel("elegoo-neptune4-plus", "Elegoo", "Elegoo Neptune 4 Plus", "Neptune 4+", 320, 320, 385, 0.4, "klipper", "Elegoo Neptune 4 Plus 0.4 nozzle", false),
        new Printer3DModel("elegoo-neptune4-max", "Elegoo", "Elegoo Neptune 4 Max", "Neptune 4M", 420, 420, 480, 0.4, "klipper", "Elegoo Neptune 4 Max 0.4 nozzle", false),
        new Printer3DModel("elegoo-neptune3-pro", "Elegoo", "Elegoo Neptune 3 Pro", "Neptune 3P", 225, 225, 280, 0.4, "marlin", "Elegoo Neptune 3 Pro 0.4 nozzle", false),
        new Printer3DModel("elegoo-neptune3-plus", "Elegoo", "Elegoo Neptune 3 Plus", "Neptune 3+", 320, 320, 400, 0.4, "marlin", "Elegoo Neptune 3 Plus 0.4 nozzle", false),
        new Printer3DModel("elegoo-neptune3-max", "Elegoo", "Elegoo Neptune 3 Max", "Neptune 3M", 420, 420, 500, 0.4, "marlin", "Elegoo Neptune 3 Max 0.4 nozzle", false),
        new Printer3DModel("elegoo-centauri-carbon", "Elegoo", "Elegoo Centauri Carbon", "Centauri C", 256, 256, 256, 0.4, "klipper", "Elegoo Centauri Carbon 0.4 nozzle", false),

        // MARK: Prusa (6 models)
        new Printer3DModel("prusa-mk4", "Prusa", "Original Prusa MK4", "Prusa MK4", 250, 210, 220, 0.4, "marlin", "Original Prusa MK4 Input Shaper 0.4 nozzle", false),
        new Printer3DModel("prusa-mk4s", "Prusa", "Original Prusa MK4S", "Prusa MK4S", 250, 210, 220, 0.4, "marlin", "Original Prusa MK4S 0.4 nozzle", false),
        new Printer3DModel("prusa-core-one", "Prusa", "Original Prusa CORE One", "CORE One", 250, 220, 270, 0.4, "marlin", "Original Prusa CORE One 0.4 nozzle", false),
        new Printer3DModel("prusa-mk3s", "Prusa", "Original Prusa i3 MK3S+", "Prusa MK3S+", 250, 210, 210, 0.4, "marlin", "Original Prusa i3 MK3S+ 0.4 nozzle", false),
        new Printer3DModel("prusa-mini", "Prusa", "Original Prusa MINI+", "Prusa MINI+", 180, 180, 180, 0.4, "marlin", "Original Prusa MINI+ 0.4 nozzle", false),
        new Printer3DModel("prusa-xl", "Prusa", "Original Prusa XL", "Prusa XL", 360, 360, 360, 0.4, "marlin", "Original Prusa XL 0.4 nozzle", false),

        // MARK: Qidi Tech (5 models)
        new Printer3DModel("qidi-plus-4", "Qidi Tech", "Qidi Plus 4", "Qidi Plus 4", 305, 305, 280, 0.4, "klipper", "Qidi Plus 4 0.4 nozzle", false),
        new Printer3DModel("qidi-q1-pro", "Qidi Tech", "Qidi Q1 Pro", "Qidi Q1 Pro", 245, 245, 240, 0.4, "klipper", "Qidi Q1 Pro 0.4 nozzle", false),
        new Printer3DModel("qidi-x-max-3", "Qidi Tech", "Qidi X-Max 3", "Qidi X-Max3", 325, 325, 315, 0.4, "klipper", "Qidi X-Max 3 0.4 nozzle", false),
        new Printer3DModel("qidi-x-plus-3", "Qidi Tech", "Qidi X-Plus 3", "Qidi X-Plus3", 280, 280, 270, 0.4, "klipper", "Qidi X-Plus 3 0.4 nozzle", false),
        new Printer3DModel("qidi-x-smart-3", "Qidi Tech", "Qidi X-Smart 3", "X-Smart 3", 175, 180, 170, 0.4, "klipper", "Qidi X-Smart 3 0.4 nozzle", false),

        // MARK: Sovol (6 models)
        new Printer3DModel("sovol-sv08", "Sovol", "Sovol SV08", "Sovol SV08", 350, 350, 345, 0.4, "klipper", "Sovol SV08 0.4 nozzle", false),
        new Printer3DModel("sovol-sv06-ace", "Sovol", "Sovol SV06 ACE", "SV06 ACE", 220, 220, 250, 0.4, "klipper", "Sovol SV06 ACE 0.4 nozzle", false),
        new Printer3DModel("sovol-sv06", "Sovol", "Sovol SV06", "Sovol SV06", 220, 220, 250, 0.4, "marlin", "Sovol SV06 0.4 nozzle", false),
        new Printer3DModel("sovol-sv06-plus", "Sovol", "Sovol SV06 Plus", "SV06 Plus", 300, 300, 340, 0.4, "marlin", "Sovol SV06 Plus 0.4 nozzle", false),
        new Printer3DModel("sovol-sv07", "Sovol", "Sovol SV07", "Sovol SV07", 220, 220, 250, 0.4, "klipper", "Sovol SV07 0.4 nozzle", false),
        new Printer3DModel("sovol-sv07-plus", "Sovol", "Sovol SV07 Plus", "SV07 Plus", 300, 300, 350, 0.4, "klipper", "Sovol SV07 Plus 0.4 nozzle", false),

        // MARK: Artillery (4 models)
        new Printer3DModel("artillery-sw-x4-pro", "Artillery", "Artillery Sidewinder X4 Pro", "SW X4 Pro", 240, 240, 260, 0.4, "klipper", "Artillery Sidewinder X4 Pro 0.4 nozzle", false),
        new Printer3DModel("artillery-sw-x4-plus", "Artillery", "Artillery Sidewinder X4 Plus", "SW X4 Plus", 300, 300, 400, 0.4, "klipper", "Artillery Sidewinder X4 Plus 0.4 nozzle", false),
        new Printer3DModel("artillery-sw-x2", "Artillery", "Artillery Sidewinder X2", "SW X2", 300, 300, 400, 0.4, "marlin", "Artillery Sidewinder X2 0.4 nozzle", false),
        new Printer3DModel("artillery-genius-pro", "Artillery", "Artillery Genius Pro", "Genius Pro", 220, 220, 250, 0.4, "marlin", "Artillery Genius Pro 0.4 nozzle", false),

        // MARK: Flsun (4 models)
        new Printer3DModel("flsun-s1", "Flsun", "Flsun S1", "Flsun S1", 320, 320, 430, 0.4, "klipper", "Flsun S1 0.4 nozzle", false),
        new Printer3DModel("flsun-t1", "Flsun", "Flsun T1", "Flsun T1", 260, 260, 330, 0.4, "klipper", "Flsun T1 0.4 nozzle", false),
        new Printer3DModel("flsun-v400", "Flsun", "Flsun V400", "Flsun V400", 300, 300, 410, 0.4, "klipper", "Flsun V400 0.4 nozzle", false),
        new Printer3DModel("flsun-sr", "Flsun", "Flsun Super Racer", "Flsun SR", 260, 260, 330, 0.4, "marlin", "Flsun Super Racer 0.4 nozzle", false),

        // MARK: Voron (4 models)
        new Printer3DModel("voron-24-350", "Voron", "Voron 2.4 350mm", "Voron 350", 350, 350, 330, 0.4, "klipper", "Voron 2.4 350mm 0.4 nozzle", false),
        new Printer3DModel("voron-24-300", "Voron", "Voron 2.4 300mm", "Voron 300", 300, 300, 280, 0.4, "klipper", "Voron 2.4 300mm 0.4 nozzle", false),
        new Printer3DModel("voron-trident-300", "Voron", "Voron Trident 300mm", "Trident 300", 300, 300, 250, 0.4, "klipper", "Voron Trident 300mm 0.4 nozzle", false),
        new Printer3DModel("voron-02", "Voron", "Voron 0.2 120mm", "Voron 0.2", 120, 120, 120, 0.4, "klipper", "Voron 0.2 120mm 0.4 nozzle", false),

        // MARK: Two Trees (2 models)
        new Printer3DModel("twotrees-sk1", "Two Trees", "Two Trees SK1", "TwoTrees SK1", 256, 256, 256, 0.4, "klipper", "Two Trees SK1 0.4 nozzle", false),
        new Printer3DModel("twotrees-sp5", "Two Trees", "Two Trees Sapphire Plus", "Sapphire+", 300, 300, 350, 0.4, "marlin", "Two Trees Sapphire Plus 0.4 nozzle", false)
    };

    public static List<Printer3DModel> DefaultCatalog() => new()
    {
        new Printer3DModel("anycubic-kobra-x", "Anycubic", "Anycubic Kobra X", "Kobra X", 260, 260, 260, 0.4, "klipper", "Anycubic Kobra X 0.4 nozzle", true),
        new Printer3DModel("anycubic-kobra-3", "Anycubic", "Anycubic Kobra 3", "Kobra 3", 250, 250, 260, 0.4, "klipper", "Anycubic Kobra 3 0.4 nozzle", true),
        new Printer3DModel("bambu-a1-mini", "Bambu Lab", "Bambu Lab A1 mini", "A1 mini", 180, 180, 180, 0.4, "marlin", "Bambu Lab A1 mini 0.4 nozzle", true),
        new Printer3DModel("bambu-a1", "Bambu Lab", "Bambu Lab A1", "Bambu A1", 256, 256, 256, 0.4, "marlin", "Bambu Lab A1 0.4 nozzle", true),
        new Printer3DModel("bambu-p1s", "Bambu Lab", "Bambu Lab P1S", "Bambu P1S", 256, 256, 256, 0.4, "marlin", "Bambu Lab P1S 0.4 nozzle", true),
        new Printer3DModel("bambu-x1c", "Bambu Lab", "Bambu Lab X1 Carbon", "X1 Carbon", 256, 256, 256, 0.4, "marlin", "Bambu Lab X1 Carbon 0.4 nozzle", true),
        new Printer3DModel("creality-k1", "Creality", "Creality K1", "Creality K1", 220, 220, 250, 0.4, "klipper", "Creality K1 0.4 nozzle", true),
        new Printer3DModel("creality-k1-max", "Creality", "Creality K1 Max", "K1 Max", 300, 300, 300, 0.4, "klipper", "Creality K1 Max 0.4 nozzle", true),
        new Printer3DModel("flashforge-adv5m-pro", "Flashforge", "Flashforge Adventurer 5M Pro", "Adv 5M Pro", 220, 220, 220, 0.4, "klipper", "Flashforge Adventurer 5M Pro 0.4 nozzle", true),
        new Printer3DModel("bambu-p1p", "Bambu Lab", "Bambu Lab P1P", "Bambu P1P", 256, 256, 256, 0.4, "marlin", "Bambu Lab P1P 0.4 nozzle", false),
        new Printer3DModel("creality-k2-plus", "Creality", "Creality K2 Plus", "K2 Plus", 350, 350, 350, 0.4, "klipper", "Creality K2 Plus 0.4 nozzle", false),
        new Printer3DModel("creality-ender3-v3", "Creality", "Creality Ender-3 V3", "Ender-3 V3", 220, 220, 250, 0.4, "klipper", "Creality Ender-3 V3 0.4 nozzle", false),
        new Printer3DModel("flashforge-adv5m", "Flashforge", "Flashforge Adventurer 5M", "Adv 5M", 220, 220, 220, 0.4, "klipper", "Flashforge Adventurer 5M 0.4 nozzle", false),
        new Printer3DModel("elegoo-neptune4-pro", "Elegoo", "Elegoo Neptune 4 Pro", "Neptune 4", 225, 225, 265, 0.4, "klipper", "Elegoo Neptune 4 Pro 0.4 nozzle", false),
        new Printer3DModel("prusa-mk4", "Prusa", "Original Prusa MK4", "Prusa MK4", 250, 210, 220, 0.4, "marlin", "Original Prusa MK4 Input Shaper 0.4 nozzle", false)
    };
}

/// <summary>
/// Preset profile optimization strategies for cross-printer conversions.
/// </summary>
public enum ThreeMFOptimizationPreset
{
    KeepOriginal,
    StandardQuality,
    DetailedFigure,
    FastEconomic,
    StrongMechanical
}

public static class ThreeMFOptimizationPresetExtensions
{
    public static string DisplayName(this ThreeMFOptimizationPreset preset) => preset switch
    {
        ThreeMFOptimizationPreset.KeepOriginal => UiText.Get("Keep original project settings"),
        ThreeMFOptimizationPreset.StandardQuality => UiText.Get("Balanced (0.20 mm · 2 walls · 15%)"),
        ThreeMFOptimizationPreset.DetailedFigure => UiText.Get("Figurine / High quality (0.12 mm · 3 walls)"),
        ThreeMFOptimizationPreset.FastEconomic => UiText.Get("Fast and economical (0.24 mm · 2 walls · 10%)"),
        ThreeMFOptimizationPreset.StrongMechanical => UiText.Get("Mechanical part / Strong (0.20 mm · 4 walls · 35% gyroid)"),
        _ => preset.ToString()
    };

    public static string Description(this ThreeMFOptimizationPreset preset) => preset switch
    {
        ThreeMFOptimizationPreset.KeepOriginal => UiText.Get("Preserves slicing process overrides, infill, and perimeter counts exactly as authored in the source project file."),
        ThreeMFOptimizationPreset.StandardQuality => UiText.Get("Applies a balanced 0.20mm layer height with 2 walls and 15% grid/crosshatch infill for general-purpose printing."),
        ThreeMFOptimizationPreset.DetailedFigure => UiText.Get("Applies fine 0.12mm layers with 3 walls and adaptive variable layer height for figurines and high-detail models."),
        ThreeMFOptimizationPreset.FastEconomic => UiText.Get("Applies fast 0.24mm draft layers with 2 walls and 10% lightning/sparse infill to minimize material and print duration."),
        ThreeMFOptimizationPreset.StrongMechanical => UiText.Get("Applies robust 0.20mm layers with 4 reinforced walls and 35% gyroid infill for mechanical, functional parts."),
        _ => ""
    };
}

/// <summary>
/// Filament spool slot definition within a multi-material .3MF project.
/// </summary>
public class ThreeMFFilamentSlot
{
    public int SlotIndex { get; set; } = 1;
    public string FilamentType { get; set; } = "PLA";
    public string ColorHex { get; set; } = "#FFFFFF";
    public double? UsedGrams { get; set; }
    public double? UsedMeters { get; set; }

    public ThreeMFFilamentSlot() { }

    public ThreeMFFilamentSlot(int slotIndex, string filamentType, string colorHex, double? usedGrams = null, double? usedMeters = null)
    {
        SlotIndex = slotIndex;
        FilamentType = filamentType;
        ColorHex = colorHex;
        UsedGrams = usedGrams;
        UsedMeters = usedMeters;
    }
}

/// <summary>
/// Detailed summary of a .3MF 3D printing project.
/// </summary>
public class ThreeMFProjectSummary
{
    public string FilePath { get; set; } = "";
    public string FileName { get; set; } = "";
    public string OriginalPrinterName { get; set; } = "Não identificada";
    public string SlicerApplication { get; set; } = "";
    public double BedWidthMM { get; set; } = 256;
    public double BedDepthMM { get; set; } = 256;
    public double BedHeightMM { get; set; } = 256;
    public double NozzleDiameterMM { get; set; } = 0.4;
    public double LayerHeightMM { get; set; } = 0.20;
    public string InfillDensity { get; set; } = "15%";
    public int WallLoops { get; set; } = 2;
    public bool SupportEnabled { get; set; } = false;
    public int PlateCount { get; set; } = 1;
    public int ObjectCount { get; set; } = 1;
    public List<string> ObjectNames { get; set; } = new();
    public int EstimatedTimeSeconds { get; set; } = 0;
    public double TotalWeightGrams { get; set; } = 0;
    public List<ThreeMFFilamentSlot> Filaments { get; set; } = new();
    public List<string> ModifiedProcessKeys { get; set; } = new();
    public byte[]? ThumbnailBytes { get; set; }

    public string FormattedPrintTime
    {
        get
        {
            if (EstimatedTimeSeconds <= 0)
                return "--";

            var ts = TimeSpan.FromSeconds(EstimatedTimeSeconds);
            if (ts.TotalHours >= 1)
                return $"{(int)ts.TotalHours}h {ts.Minutes:D2}m";

            return $"{ts.Minutes}m {ts.Seconds:D2}s";
        }
    }

    public string FormattedWeight => TotalWeightGrams > 0 ? $"{TotalWeightGrams:0.#} g" : "--";
}
