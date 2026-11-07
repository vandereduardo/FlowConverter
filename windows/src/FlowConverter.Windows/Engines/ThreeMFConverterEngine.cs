using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Xml.Linq;
using System.Xml.XPath;
using FlowConverter.Windows.Models;

namespace FlowConverter.Windows.Engines;

public static class ThreeMFConverterEngine
{
    private static readonly HashSet<string> PreservedScalarIntentKeys = new(StringComparer.Ordinal)
    {
        "layer_height", "initial_layer_print_height",
        "wall_loops", "top_shell_layers", "bottom_shell_layers",
        "top_shell_thickness", "bottom_shell_thickness",
        "sparse_infill_density", "sparse_infill_pattern",
        "top_surface_pattern", "bottom_surface_pattern", "internal_solid_infill_pattern",
        "infill_direction", "infill_wall_overlap", "infill_combination",
        "minimum_sparse_infill_area", "reduce_infill_retraction",
        "inner_wall_speed", "outer_wall_speed", "sparse_infill_speed", "internal_solid_infill_speed",
        "top_surface_speed", "initial_layer_speed", "initial_layer_infill_speed",
        "bridge_speed", "gap_infill_speed", "support_speed", "support_interface_speed",
        "small_perimeter_speed", "overhang_1_4_speed", "overhang_2_4_speed", "overhang_3_4_speed", "overhang_4_4_speed",
        "outer_wall_line_width", "inner_wall_line_width", "sparse_infill_line_width",
        "initial_layer_line_width", "top_surface_line_width", "internal_solid_infill_line_width", "line_width",
        "enable_support", "support_type", "support_style",
        "support_on_build_plate_only", "support_threshold_angle", "support_remove_small_overhang",
        "support_critical_regions_only", "support_angle", "support_base_pattern", "support_base_pattern_spacing",
        "support_interface_top_layers", "support_interface_bottom_layers",
        "support_interface_pattern", "support_interface_spacing", "support_bottom_interface_spacing",
        "support_top_z_distance", "support_bottom_z_distance", "support_object_xy_distance",
        "tree_support_branch_angle", "tree_support_branch_diameter", "tree_support_branch_distance",
        "tree_support_brim_width", "tree_support_wall_count",
        "brim_type", "brim_width", "brim_object_gap", "skirt_loops", "skirt_distance", "skirt_height", "raft_layers",
        "seam_position", "seam_gap", "detect_thin_wall", "wall_generator", "wall_sequence", "spiral_mode",
        "elefant_foot_compensation", "xy_contour_compensation", "xy_hole_compensation",
        "fuzzy_skin", "fuzzy_skin_thickness", "fuzzy_skin_point_distance",
        "ironing_type", "ironing_flow", "ironing_speed", "ironing_spacing",
        "enable_prime_tower", "prime_tower_width", "prime_tower_brim_width", "prime_volume",
        "wipe_tower_no_sparse_layers", "flush_into_infill", "flush_into_objects", "flush_into_support",
        "only_one_wall_top", "only_one_wall_first_layer", "avoid_crossing_wall", "reduce_crossing_wall",
        "bridge_no_support", "bridge_density", "bridge_flow", "thick_bridges",
        "extra_perimeters_on_overhangs", "detect_overhang_wall", "precise_outer_wall", "precise_z_height",
        "slicing_mode", "print_sequence", "independent_support_layer_height", "enforce_support_layers",
        "ensure_vertical_shell_thickness"
    };

    private static readonly HashSet<string> CorePresetGeometryKeys = new(StringComparer.Ordinal)
    {
        "layer_height", "initial_layer_print_height",
        "wall_loops", "top_shell_layers", "bottom_shell_layers",
        "sparse_infill_density", "sparse_infill_pattern",
        "enable_support", "support_type",
        "brim_type", "brim_width",
        "spiral_mode", "fuzzy_skin"
    };

    private static readonly HashSet<string> ExcludedProcessMetaKeys = new(StringComparer.Ordinal)
    {
        "name", "from", "type", "inherits", "setting_id", "instantiation", "version",
        "compatible_printers", "compatible_printers_condition", "print_settings_id",
        "default_print_profile", "filename_format"
    };

    private static readonly HashSet<string> SafeFilamentOverrideKeys = new(StringComparer.Ordinal)
    {
        "nozzle_temperature", "nozzle_temperature_initial_layer",
        "hot_plate_temp", "hot_plate_temp_initial_layer",
        "textured_plate_temp", "textured_plate_temp_initial_layer",
        "cool_plate_temp", "cool_plate_temp_initial_layer",
        "filament_flow_ratio", "filament_max_volumetric_speed",
        "enable_pressure_advance", "pressure_advance",
        "fan_max_speed", "fan_min_speed", "overhang_fan_speed",
        "slow_down_for_layer_cooling", "slow_down_layer_time", "slow_down_min_speed"
    };

    private static readonly HashSet<string> ScalarSlicerKeys = new(StringComparer.Ordinal)
    {
        "enable_overhang_speed",
        "ensure_vertical_shell_thickness",
        "nozzle_type",
        "nozzle_volume",
        "nozzle_height",
        "nozzle_hrc",
        "overhang_speed_classic",
        "bridge_speed",
        "internal_bridge_speed",
        "default_acceleration",
        "gap_infill_speed",
        "initial_layer_acceleration",
        "initial_layer_infill_speed",
        "initial_layer_speed",
        "initial_layer_travel_speed",
        "inner_wall_acceleration",
        "inner_wall_speed",
        "internal_solid_infill_acceleration",
        "internal_solid_infill_speed",
        "outer_wall_acceleration",
        "outer_wall_speed",
        "overhang_1_4_speed",
        "overhang_2_4_speed",
        "overhang_3_4_speed",
        "overhang_4_4_speed",
        "overhang_totally_speed",
        "small_perimeter_speed",
        "small_perimeter_threshold",
        "sparse_infill_acceleration",
        "sparse_infill_speed",
        "support_interface_speed",
        "support_speed",
        "top_surface_acceleration",
        "top_surface_speed",
        "travel_acceleration",
        "travel_speed",
        "travel_speed_z",
        "layer_height",
        "initial_layer_print_height",
        "wall_loops",
        "top_shell_layers",
        "bottom_shell_layers",
        "top_shell_thickness",
        "bottom_shell_thickness",
        "sparse_infill_density",
        "sparse_infill_pattern",
        "top_surface_pattern",
        "bottom_surface_pattern",
        "internal_solid_infill_pattern",
        "enable_support",
        "support_type",
        "support_style",
        "support_on_build_plate_only",
        "support_threshold_angle",
        "support_remove_small_overhang",
        "brim_type",
        "brim_width",
        "skirt_loops",
        "seam_position",
        "detect_thin_wall",
        "wall_generator",
        "spiral_mode",
        "fuzzy_skin",
        "fuzzy_skin_thickness",
        "fuzzy_skin_point_distance",
        "ironing_type",
        "enable_prime_tower",
        "prime_tower_width",
        "prime_tower_brim_width",
        "wipe_tower_no_sparse_layers",
        "printer_model",
        "printer_settings_id",
        "print_settings_id",
        "default_print_profile",
        "printer_variant",
        "printable_height",
        "gcode_flavor",
        "single_extruder_multi_material",
        "auxiliary_fan"
    };

    public static ThreeMFProjectSummary Inspect(string filePath)
    {
        var info = new ThreeMFProjectSummary
        {
            FilePath = filePath,
            FileName = Path.GetFileName(filePath),
            OriginalPrinterName = "Não identificada",
            SlicerApplication = "3MF Project",
            BedWidthMM = 256,
            BedDepthMM = 256,
            BedHeightMM = 256,
            NozzleDiameterMM = 0.4,
            LayerHeightMM = 0.20,
            InfillDensity = "15%",
            WallLoops = 2,
            PlateCount = 1,
            ObjectCount = 1
        };

        string tempDir = Path.Combine(Path.GetTempPath(), $"flowconverter-3mf-inspect-{Guid.NewGuid():N}");
        try
        {
            Directory.CreateDirectory(tempDir);
            ZipFile.ExtractToDirectory(filePath, tempDir, overwriteFiles: true);

            // 1. Parse Metadata/project_settings.config (JSON)
            string projectSettingsPath = Path.Combine(tempDir, "Metadata", "project_settings.config");
            var filamentTypes = new List<string>();
            var filamentColors = new List<string>();

            if (File.Exists(projectSettingsPath))
            {
                var dict = ParseJsonDictionary(File.ReadAllText(projectSettingsPath, Encoding.UTF8));
                if (dict != null)
                {
                    string? pm = GetStringValue(dict, "printer_model");
                    string? ps = GetStringValue(dict, "printer_settings_id");
                    if (!string.IsNullOrWhiteSpace(pm))
                        info.OriginalPrinterName = pm;
                    else if (!string.IsNullOrWhiteSpace(ps))
                        info.OriginalPrinterName = ps;

                    string? nozzle = GetFirstStringValue(dict, "nozzle_diameter") ?? GetStringValue(dict, "printer_variant");
                    if (double.TryParse(nozzle, NumberStyles.Float, CultureInfo.InvariantCulture, out double nzVal) && nzVal > 0)
                        info.NozzleDiameterMM = nzVal;

                    string? lh = GetFirstStringValue(dict, "layer_height");
                    if (double.TryParse(lh, NumberStyles.Float, CultureInfo.InvariantCulture, out double lhVal) && lhVal > 0)
                        info.LayerHeightMM = lhVal;

                    string? infill = GetFirstStringValue(dict, "sparse_infill_density");
                    if (!string.IsNullOrWhiteSpace(infill))
                        info.InfillDensity = infill.EndsWith('%') ? infill : $"{infill}%";

                    string? walls = GetFirstStringValue(dict, "wall_loops");
                    if (int.TryParse(walls, NumberStyles.Integer, CultureInfo.InvariantCulture, out int wallVal) && wallVal > 0)
                        info.WallLoops = wallVal;

                    string? sup = GetFirstStringValue(dict, "enable_support");
                    if (sup != null)
                        info.SupportEnabled = sup == "1" || sup.Equals("true", StringComparison.OrdinalIgnoreCase);

                    string? heightStr = GetFirstStringValue(dict, "printable_height");
                    if (double.TryParse(heightStr, NumberStyles.Float, CultureInfo.InvariantCulture, out double hVal) && hVal > 0)
                        info.BedHeightMM = hVal;

                    var area = GetStringList(dict, "printable_area");
                    if (area.Count > 0)
                    {
                        var (w, d) = ParsePrintableArea(area);
                        if (w > 0 && d > 0)
                        {
                            info.BedWidthMM = w;
                            info.BedDepthMM = d;
                        }
                    }

                    var diffs = GetStringList(dict, "different_settings_to_system");
                    if (diffs.Count > 0 && !string.IsNullOrWhiteSpace(diffs[0]))
                    {
                        info.ModifiedProcessKeys = diffs[0]
                            .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                            .ToList();
                    }

                    filamentTypes = GetStringList(dict, "filament_type");
                    filamentColors = GetStringList(dict, "filament_colour");
                }
            }

            // 2. Parse Metadata/slice_info.config (XML)
            string sliceInfoPath = Path.Combine(tempDir, "Metadata", "slice_info.config");
            var sliceFilaments = new List<ThreeMFFilamentSlot>();
            if (File.Exists(sliceInfoPath))
            {
                try
                {
                    XDocument xmlDoc = XDocument.Load(sliceInfoPath);
                    var plates = xmlDoc.XPathSelectElements("//plate").ToList();
                    if (plates.Count > 0)
                        info.PlateCount = plates.Count;

                    if (info.OriginalPrinterName == "Não identificada")
                    {
                        var pmAttr = xmlDoc.XPathSelectElement("//metadata[@key='printer_model_id']")?.Attribute("value")?.Value;
                        if (!string.IsNullOrWhiteSpace(pmAttr))
                            info.OriginalPrinterName = pmAttr;
                    }

                    double totalSec = 0;
                    foreach (var pred in xmlDoc.XPathSelectElements("//metadata[@key='prediction']"))
                    {
                        if (double.TryParse(pred.Attribute("value")?.Value, NumberStyles.Float, CultureInfo.InvariantCulture, out double sec))
                            totalSec += sec;
                    }
                    info.EstimatedTimeSeconds = (int)Math.Round(totalSec);

                    double totalWeight = 0;
                    foreach (var wNode in xmlDoc.XPathSelectElements("//metadata[@key='weight']"))
                    {
                        if (double.TryParse(wNode.Attribute("value")?.Value, NumberStyles.Float, CultureInfo.InvariantCulture, out double wg))
                            totalWeight += wg;
                    }
                    info.TotalWeightGrams = totalWeight;

                    int idx = 0;
                    foreach (var fil in xmlDoc.XPathSelectElements("//filament"))
                    {
                        int id = int.TryParse(fil.Attribute("id")?.Value, out int parsedId) ? parsedId : (idx + 1);
                        string type = fil.Attribute("type")?.Value ?? (idx < filamentTypes.Count ? filamentTypes[idx] : "PLA");
                        string color = NormalizeHexColor(fil.Attribute("color")?.Value ?? (idx < filamentColors.Count ? filamentColors[idx] : "#00E5FF"));
                        double.TryParse(fil.Attribute("used_g")?.Value, NumberStyles.Float, CultureInfo.InvariantCulture, out double usedG);
                        double.TryParse(fil.Attribute("used_m")?.Value, NumberStyles.Float, CultureInfo.InvariantCulture, out double usedM);
                        sliceFilaments.Add(new ThreeMFFilamentSlot
                        {
                            SlotIndex = id,
                            FilamentType = type,
                            ColorHex = color,
                            UsedGrams = usedG,
                            UsedMeters = usedM
                        });
                        idx++;
                    }

                    var objNames = xmlDoc.XPathSelectElements("//object")
                        .Select(x => x.Attribute("name")?.Value?.Trim())
                        .Where(s => !string.IsNullOrWhiteSpace(s))
                        .Cast<string>()
                        .Distinct()
                        .ToList();
                    if (objNames.Count > 0)
                    {
                        info.ObjectNames = objNames;
                        info.ObjectCount = objNames.Count;
                    }
                }
                catch
                {
                    // Ignore malformed slice_info.config
                }
            }

            if (sliceFilaments.Count > 0)
            {
                info.Filaments = sliceFilaments;
            }
            else
            {
                int count = Math.Max(filamentTypes.Count, filamentColors.Count);
                for (int i = 0; i < count; i++)
                {
                    info.Filaments.Add(new ThreeMFFilamentSlot
                    {
                        SlotIndex = i + 1,
                        FilamentType = i < filamentTypes.Count ? filamentTypes[i] : "PLA",
                        ColorHex = NormalizeHexColor(i < filamentColors.Count ? filamentColors[i] : "#00E5FF")
                    });
                }
            }

            // 3. Parse Metadata/model_settings.config (XML)
            string modelSettingsPath = Path.Combine(tempDir, "Metadata", "model_settings.config");
            if (File.Exists(modelSettingsPath))
            {
                try
                {
                    XDocument xmlDoc = XDocument.Load(modelSettingsPath);
                    int plateCount = xmlDoc.XPathSelectElements("//plate").Count();
                    info.PlateCount = Math.Max(info.PlateCount, plateCount);
                    if (info.ObjectNames.Count == 0)
                    {
                        var names = xmlDoc.XPathSelectElements("/config/object/metadata[@key='name']")
                            .Select(e => e.Attribute("value")?.Value?.Trim())
                            .Where(s => !string.IsNullOrWhiteSpace(s))
                            .Cast<string>()
                            .ToList();
                        if (names.Count > 0)
                        {
                            info.ObjectNames = names;
                            info.ObjectCount = names.Count;
                        }
                    }
                }
                catch { }
            }

            // 4. Parse 3D/3dmodel.model (XML)
            string model3DPath = Path.Combine(tempDir, "3D", "3dmodel.model");
            if (File.Exists(model3DPath))
            {
                try
                {
                    XDocument xmlDoc = XDocument.Load(model3DPath);
                    var appMeta = xmlDoc.Descendants().FirstOrDefault(e =>
                        e.Name.LocalName == "metadata" &&
                        string.Equals(e.Attribute("name")?.Value, "Application", StringComparison.OrdinalIgnoreCase));
                    if (!string.IsNullOrWhiteSpace(appMeta?.Value))
                    {
                        info.SlicerApplication = appMeta.Value.Trim();
                    }

                    int itemCount = xmlDoc.Descendants()
                        .Where(e => e.Name.LocalName == "build")
                        .Elements()
                        .Count(e => e.Name.LocalName == "item");
                    if (itemCount > 0)
                    {
                        info.ObjectCount = Math.Max(info.ObjectCount, itemCount);
                    }
                }
                catch { }
            }

            // 5. Load Plate Thumbnail if present
            string[] thumbCandidates =
            {
                Path.Combine("Metadata", "plate_1.png"),
                Path.Combine("Metadata", "plate_1_small.png"),
                Path.Combine("Metadata", "top_1.png"),
                Path.Combine("Metadata", "thumbnail.png"),
                Path.Combine("Metadata", "model_thumbnail.png")
            };
            foreach (string rel in thumbCandidates)
            {
                string p = Path.Combine(tempDir, rel);
                if (File.Exists(p))
                {
                    info.ThumbnailBytes = File.ReadAllBytes(p);
                    break;
                }
            }
        }
        catch
        {
            // Return best-effort summary
        }
        finally
        {
            try { Directory.Delete(tempDir, recursive: true); } catch { }
        }

        return info;
    }

    public static string Convert(
        string srcFilePath,
        Printer3DModel targetPrinter,
        ThreeMFOptimizationPreset preset = ThreeMFOptimizationPreset.KeepOriginal,
        bool recenterOnBed = true,
        bool preserveFilaments = true)
    {
        string tempDir = Path.Combine(Path.GetTempPath(), $"flowconverter-3mf-convert-{Guid.NewGuid():N}");
        try
        {
            Directory.CreateDirectory(tempDir);
            ZipFile.ExtractToDirectory(srcFilePath, tempDir, overwriteFiles: true);

            string metadataDir = Path.Combine(tempDir, "Metadata");
            Directory.CreateDirectory(metadataDir);

            string projectSettingsPath = Path.Combine(metadataDir, "project_settings.config");
            var settingsDict = new Dictionary<string, object?>(StringComparer.Ordinal);
            int oldBedW = 256;
            int oldBedD = 256;

            if (File.Exists(projectSettingsPath))
            {
                var parsed = ParseJsonDictionary(File.ReadAllText(projectSettingsPath, Encoding.UTF8));
                if (parsed != null)
                {
                    settingsDict = parsed;
                    var area = GetStringList(parsed, "printable_area");
                    if (area.Count > 0)
                    {
                        var (w, d) = ParsePrintableArea(area);
                        if (w > 0 && d > 0)
                        {
                            oldBedW = w;
                            oldBedD = d;
                        }
                    }
                }
            }

            string nozzleStr = targetPrinter.NozzleDiameterMM.ToString("0.0", CultureInfo.InvariantCulture);
            var origTypes = GetStringList(settingsDict, "filament_type");
            var origColors = GetStringList(settingsDict, "filament_colour");
            int filamentCount = preserveFilaments ? Math.Max(Math.Max(origTypes.Count, origColors.Count), 1) : 1;

            var resolvedTypes = new List<string>();
            var resolvedColors = new List<string>();
            if (preserveFilaments)
            {
                for (int i = 0; i < filamentCount; i++)
                {
                    string t = (i < origTypes.Count && !string.IsNullOrWhiteSpace(origTypes[i]))
                        ? origTypes[i]
                        : (origTypes.FirstOrDefault() ?? "PLA");
                    string c = (i < origColors.Count && !string.IsNullOrWhiteSpace(origColors[i]))
                        ? NormalizeHexColor(origColors[i])
                        : NormalizeHexColor(origColors.FirstOrDefault() ?? "#00E5FF");
                    resolvedTypes.Add(t);
                    resolvedColors.Add(c);
                }
            }
            else
            {
                resolvedTypes.Add("PLA");
                resolvedColors.Add("#00E5FF");
            }

            var origSettingsDict = new Dictionary<string, object?>(settingsDict, StringComparer.Ordinal);
            var origDiffs = GetStringList(origSettingsDict, "different_settings_to_system");
            var origModifiedProcessKeys = (origDiffs.FirstOrDefault() ?? "")
                .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .ToHashSet(StringComparer.Ordinal);

            var origModifiedFilamentKeysPerSlot = new List<List<string>>();
            if (origDiffs.Count > 2)
            {
                for (int i = 2; i < origDiffs.Count; i++)
                {
                    var fKeys = origDiffs[i]
                        .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                        .ToList();
                    origModifiedFilamentKeysPerSlot.Add(fKeys);
                }
            }

            HashSet<string> allCandidateProcessKeys = origModifiedProcessKeys.Count == 0
                ? new HashSet<string>(PreservedScalarIntentKeys, StringComparer.Ordinal)
                : new HashSet<string>(origModifiedProcessKeys.Union(CorePresetGeometryKeys), StringComparer.Ordinal);

            bool isAnycubicTarget = targetPrinter.Brand.Contains("anycubic", StringComparison.OrdinalIgnoreCase) ||
                                    targetPrinter.Name.Contains("anycubic", StringComparison.OrdinalIgnoreCase);

            var targetProcessDefaults = new Dictionary<string, object?>(StringComparer.Ordinal);
            var targetFilamentKeys = new HashSet<string>(StringComparer.Ordinal);

            var officialResult = BuildOfficialPrinterSettings(targetPrinter, nozzleStr, resolvedTypes, resolvedColors);
            if (officialResult != null)
            {
                settingsDict = officialResult.Value.Combined;
                targetProcessDefaults = officialResult.Value.ProcessProfile;
                targetFilamentKeys = officialResult.Value.FilamentKeys;
            }

            var modifiedProcessKeySet = new HashSet<string>(StringComparer.Ordinal);
            if (preset == ThreeMFOptimizationPreset.KeepOriginal)
            {
                foreach (string k in allCandidateProcessKeys)
                {
                    if (ExcludedProcessMetaKeys.Contains(k)) continue;
                    if (targetProcessDefaults.Count > 0 && !targetProcessDefaults.ContainsKey(k)) continue;
                    if (!origSettingsDict.TryGetValue(k, out object? rawOrigVal) || rawOrigVal == null) continue;

                    bool wasExplicitlyModifiedInOrig = origModifiedProcessKeys.Contains(k);

                    if (targetProcessDefaults.TryGetValue(k, out object? targetDefault) && targetDefault is List<string>)
                    {
                        var arr = ValueToStringList(rawOrigVal);
                        if (arr.Count > 0)
                        {
                            settingsDict[k] = arr;
                            var defArr = ValueToStringList(targetDefault);
                            if (wasExplicitlyModifiedInOrig || !arr.SequenceEqual(defArr))
                            {
                                modifiedProcessKeySet.Add(k);
                            }
                        }
                    }
                    else
                    {
                        string? strVal = FirstStringFromObject(rawOrigVal);
                        if (!string.IsNullOrWhiteSpace(strVal))
                        {
                            string sanitized = SanitizeScalarValue(k, strVal, isAnycubicTarget);
                            string defaultStr = FirstStringFromObject(targetProcessDefaults.GetValueOrDefault(k)) ?? "";
                            bool isSpeedOrAccel = k.EndsWith("_speed", StringComparison.Ordinal) ||
                                                  k.EndsWith("_acceleration", StringComparison.Ordinal) ||
                                                  k.EndsWith("_jerk", StringComparison.Ordinal);
                            if (isSpeedOrAccel && !wasExplicitlyModifiedInOrig)
                            {
                                continue;
                            }
                            settingsDict[k] = sanitized;
                            if (wasExplicitlyModifiedInOrig || (!string.IsNullOrEmpty(defaultStr) && sanitized != defaultStr))
                            {
                                modifiedProcessKeySet.Add(k);
                            }
                        }
                    }
                }
            }

            string[] preservedArrayKeys = { "flush_volumes_matrix", "flush_volumes_vector", "wiping_volumes_extruders" };
            if (preserveFilaments)
            {
                foreach (string k in preservedArrayKeys)
                {
                    var arr = GetStringList(origSettingsDict, k);
                    if (arr.Count > 0)
                    {
                        settingsDict[k] = arr;
                    }
                }
            }

            var modifiedFilamentDiffs = Enumerable.Repeat("", filamentCount).ToList();
            if (preserveFilaments && origModifiedFilamentKeysPerSlot.Count > 0)
            {
                int limit = Math.Min(filamentCount, origModifiedFilamentKeysPerSlot.Count);
                for (int slotIdx = 0; slotIdx < limit; slotIdx++)
                {
                    var slotAppliedKeys = new List<string>();
                    foreach (string fk in origModifiedFilamentKeysPerSlot[slotIdx])
                    {
                        if (!SafeFilamentOverrideKeys.Contains(fk)) continue;
                        if (targetFilamentKeys.Count > 0 && !targetFilamentKeys.Contains(fk)) continue;
                        var origArr = GetStringList(origSettingsDict, fk);
                        if (slotIdx >= origArr.Count) continue;
                        var currentArr = GetStringList(settingsDict, fk);
                        if (currentArr.Count == filamentCount)
                        {
                            currentArr[slotIdx] = origArr[slotIdx];
                            settingsDict[fk] = currentArr;
                            slotAppliedKeys.Add(fk);
                        }
                    }
                    slotAppliedKeys.Sort(StringComparer.Ordinal);
                    modifiedFilamentDiffs[slotIdx] = string.Join(";", slotAppliedKeys);
                }
            }

            int bedW = (int)targetPrinter.BedWidthMM;
            int bedD = (int)targetPrinter.BedDepthMM;
            int bedH = (int)targetPrinter.BedHeightMM;

            string cleanModelName = CanonicalPrinterModelName(targetPrinter);
            string resolvedMachineId = GetStringValue(settingsDict, "printer_settings_id");
            if (string.IsNullOrWhiteSpace(resolvedMachineId))
            {
                resolvedMachineId = targetPrinter.PrinterSettingsID;
            }

            settingsDict["printer_model"] = cleanModelName;
            settingsDict["printer_settings_id"] = resolvedMachineId;
            settingsDict["printer_variant"] = nozzleStr;
            settingsDict["nozzle_diameter"] = new List<string> { nozzleStr };
            settingsDict["printable_area"] = new List<string>
            {
                "0x0",
                $"{bedW}x0",
                $"{bedW}x{bedD}",
                $"0x{bedD}"
            };
            settingsDict["printable_height"] = bedH.ToString(CultureInfo.InvariantCulture);
            settingsDict["bed_exclude_area"] = new List<string>();
            settingsDict["gcode_flavor"] = targetPrinter.GcodeFlavor;
            settingsDict["compatible_printers"] = new List<string> { resolvedMachineId };
            settingsDict["compatible_printers_condition"] = "";
            settingsDict["inherits"] = "";
            settingsDict["from"] = "project";
            settingsDict["name"] = "project_settings";
            settingsDict["filament_type"] = resolvedTypes;
            settingsDict["filament_colour"] = resolvedColors;

            switch (preset)
            {
                case ThreeMFOptimizationPreset.KeepOriginal:
                    break;
                case ThreeMFOptimizationPreset.StandardQuality:
                    settingsDict["layer_height"] = "0.2";
                    settingsDict["initial_layer_print_height"] = "0.2";
                    settingsDict["wall_loops"] = "2";
                    settingsDict["sparse_infill_density"] = "15%";
                    settingsDict["sparse_infill_pattern"] = "grid";
                    modifiedProcessKeySet.UnionWith(new[] { "layer_height", "initial_layer_print_height", "wall_loops", "sparse_infill_density", "sparse_infill_pattern" });
                    break;
                case ThreeMFOptimizationPreset.DetailedFigure:
                    settingsDict["layer_height"] = "0.12";
                    settingsDict["initial_layer_print_height"] = "0.2";
                    settingsDict["wall_loops"] = "3";
                    settingsDict["sparse_infill_density"] = "18%";
                    settingsDict["sparse_infill_pattern"] = "gyroid";
                    settingsDict["enable_support"] = "1";
                    settingsDict["support_type"] = "tree(auto)";
                    modifiedProcessKeySet.UnionWith(new[] { "layer_height", "initial_layer_print_height", "wall_loops", "sparse_infill_density", "sparse_infill_pattern", "enable_support", "support_type" });
                    break;
                case ThreeMFOptimizationPreset.FastEconomic:
                    settingsDict["layer_height"] = "0.24";
                    settingsDict["initial_layer_print_height"] = "0.24";
                    settingsDict["wall_loops"] = "2";
                    settingsDict["sparse_infill_density"] = "10%";
                    settingsDict["sparse_infill_pattern"] = "lightning";
                    modifiedProcessKeySet.UnionWith(new[] { "layer_height", "initial_layer_print_height", "wall_loops", "sparse_infill_density", "sparse_infill_pattern" });
                    break;
                case ThreeMFOptimizationPreset.StrongMechanical:
                    settingsDict["layer_height"] = "0.2";
                    settingsDict["initial_layer_print_height"] = "0.2";
                    settingsDict["wall_loops"] = "4";
                    settingsDict["top_shell_layers"] = "5";
                    settingsDict["bottom_shell_layers"] = "5";
                    settingsDict["sparse_infill_density"] = "35%";
                    settingsDict["sparse_infill_pattern"] = "gyroid";
                    modifiedProcessKeySet.UnionWith(new[] { "layer_height", "initial_layer_print_height", "wall_loops", "top_shell_layers", "bottom_shell_layers", "sparse_infill_density", "sparse_infill_pattern" });
                    break;
            }

            SanitizeCrossSlicerSettings(settingsDict, targetPrinter);

            var sortedModProcess = modifiedProcessKeySet.OrderBy(x => x, StringComparer.Ordinal).ToList();
            var diffToSystem = new List<string>
            {
                string.Join(";", sortedModProcess),
                ""
            };
            for (int slotIdx = 0; slotIdx < filamentCount; slotIdx++)
            {
                diffToSystem.Add(slotIdx < modifiedFilamentDiffs.Count ? modifiedFilamentDiffs[slotIdx] : "");
            }
            settingsDict["different_settings_to_system"] = diffToSystem;
            settingsDict["inherits_group"] = Enumerable.Repeat("", 2 + filamentCount).ToList();

            var sortedSettings = new SortedDictionary<string, object?>(settingsDict, StringComparer.Ordinal);
            string jsonOut = JsonSerializer.Serialize(sortedSettings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(projectSettingsPath, jsonOut, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

            // 2. Update Metadata/slice_info.config & Metadata/model_settings.config XML metadata
            string sliceInfoPath = Path.Combine(metadataDir, "slice_info.config");
            if (File.Exists(sliceInfoPath))
            {
                try
                {
                    XDocument xmlDoc = XDocument.Load(sliceInfoPath);
                    foreach (var node in xmlDoc.XPathSelectElements("//metadata[@key='printer_model_id']"))
                    {
                        node.SetAttributeValue("value", cleanModelName);
                    }
                    foreach (var node in xmlDoc.XPathSelectElements("//metadata[@key='nozzle_diameters']"))
                    {
                        node.SetAttributeValue("value", nozzleStr);
                    }
                    SanitizeXmlMetadataNodes(xmlDoc);
                    xmlDoc.Save(sliceInfoPath);
                }
                catch { }
            }

            string modelSettingsPath = Path.Combine(metadataDir, "model_settings.config");
            if (File.Exists(modelSettingsPath))
            {
                try
                {
                    XDocument xmlDoc = XDocument.Load(modelSettingsPath);
                    SanitizeXmlMetadataNodes(xmlDoc);
                    xmlDoc.Save(modelSettingsPath);
                }
                catch { }
            }

            // 3. Auto-Recenter Build Items on Target Bed if Dimensions Differ
            if (recenterOnBed && (oldBedW != bedW || oldBedD != bedD))
            {
                double dx = (bedW - oldBedW) * 0.5;
                double dy = (bedD - oldBedD) * 0.5;
                string model3DPath = Path.Combine(tempDir, "3D", "3dmodel.model");
                if (File.Exists(model3DPath))
                {
                    try
                    {
                        XDocument xmlDoc = XDocument.Load(model3DPath);
                        var items = xmlDoc.Descendants()
                            .Where(e => e.Name.LocalName == "build")
                            .Elements()
                            .Where(e => e.Name.LocalName == "item");
                        foreach (var item in items)
                        {
                            var tfAttr = item.Attribute("transform");
                            if (tfAttr == null || string.IsNullOrWhiteSpace(tfAttr.Value)) continue;
                            var parts = tfAttr.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                                .Select(s => double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out double v) ? (double?)v : null)
                                .ToList();
                            if (parts.Count == 12 && parts.All(p => p.HasValue))
                            {
                                var nums = parts.Select(p => p!.Value).ToArray();
                                const double margin = 12.0;
                                double maxW = Math.Max(margin, bedW - margin);
                                double maxD = Math.Max(margin, bedD - margin);
                                nums[9] = Math.Clamp(nums[9] + dx, margin, maxW);
                                nums[10] = Math.Clamp(nums[10] + dy, margin, maxD);
                                tfAttr.Value = string.Join(" ", nums.Select(n => n.ToString("0.0000", CultureInfo.InvariantCulture)));
                            }
                        }
                        xmlDoc.Save(model3DPath);
                    }
                    catch { }
                }
            }

            // 4. Repack .3mf ZIP Archive with POSIX forward-slash entry paths
            string dir = Path.GetDirectoryName(srcFilePath) ?? Environment.CurrentDirectory;
            string baseName = Path.GetFileNameWithoutExtension(srcFilePath);
            string outPath = UniqueOutputPath(dir, $"{baseName}_{targetPrinter.SanitizedFileSuffix}", "3mf");
            if (File.Exists(outPath))
            {
                File.Delete(outPath);
            }

            CreateZipWithForwardSlashes(tempDir, outPath);
            return outPath;
        }
        finally
        {
            try { Directory.Delete(tempDir, recursive: true); } catch { }
        }
    }

    public static string UniqueOutputPath(string directory, string baseName, string extensionWithoutDot)
    {
        string targetDir = directory;
        try
        {
            Directory.CreateDirectory(targetDir);
        }
        catch
        {
            targetDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "FlowConverter Output");
            Directory.CreateDirectory(targetDir);
        }

        string extPart = string.IsNullOrWhiteSpace(extensionWithoutDot) ? "" : $".{extensionWithoutDot.TrimStart('.')}";
        string candidate = Path.Combine(targetDir, $"{baseName}{extPart}");
        int counter = 2;
        while (File.Exists(candidate) || Directory.Exists(candidate))
        {
            candidate = Path.Combine(targetDir, $"{baseName} {counter}{extPart}");
            counter++;
        }
        return candidate;
    }

    private static void CreateZipWithForwardSlashes(string sourceDir, string zipFilePath)
    {
        using var fs = new FileStream(zipFilePath, FileMode.Create, FileAccess.Write, FileShare.None);
        using var archive = new ZipArchive(fs, ZipArchiveMode.Create);
        foreach (string file in Directory.EnumerateFiles(sourceDir, "*", SearchOption.AllDirectories))
        {
            string relPath = Path.GetRelativePath(sourceDir, file).Replace('\\', '/');
            var entry = archive.CreateEntry(relPath, CompressionLevel.Optimal);
            using var entryStream = entry.Open();
            using var srcStream = File.OpenRead(file);
            srcStream.CopyTo(entryStream);
        }
    }

    private static string CanonicalPrinterModelName(Printer3DModel printer)
    {
        string trimmed = printer.Name.Trim();
        return trimmed switch
        {
            "Anycubic Kobra 3 Combo" => "Anycubic Kobra 3",
            "Anycubic Kobra S1 Combo" => "Anycubic Kobra S1",
            "Anycubic Kobra" => "Anycubic Kobra 1",
            "Anycubic Kobra Plus" => "Anycubic Kobra 1 Plus",
            "Anycubic Kobra Max" => "Anycubic Kobra 1 Max",
            _ => trimmed
        };
    }

    private static string[] VendorIndexNames(string brand)
    {
        return brand.Trim().ToLowerInvariant() switch
        {
            "anycubic" => new[] { "Anycubic" },
            "bambu lab" or "bambulab" or "bbl" => new[] { "BBL" },
            "creality" => new[] { "Creality" },
            "flashforge" => new[] { "Flashforge" },
            "elegoo" => new[] { "Elegoo" },
            "prusa" or "prusa research" => new[] { "Prusa" },
            "qidi tech" or "qidi" => new[] { "Qidi" },
            "sovol" => new[] { "Sovol" },
            "artillery" => new[] { "Artillery" },
            "flsun" => new[] { "FLSun" },
            "voron" => new[] { "Voron" },
            "two trees" or "twotrees" => new[] { "TwoTrees" },
            _ => new[] { brand, "Anycubic", "BBL" }
        };
    }

    public static List<string> ProfileBaseDirectories()
    {
        var dirs = new List<string>
        {
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", "profiles"),
            @"C:\Program Files\AnycubicSlicerNext\resources\profiles",
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AnycubicSlicerNext", "system"),
            @"C:\Program Files\OrcaSlicer\resources\profiles",
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "OrcaSlicer", "system"),
            @"C:\Program Files\Bambu Studio\resources\profiles"
        };
        return dirs.Where(Directory.Exists).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }

    private static Dictionary<string, object?>? LoadInheritedProfileChain(
        string baseDir,
        string vendor,
        JsonElement indexRoot,
        string listKey,
        string targetName)
    {
        if (!indexRoot.TryGetProperty(listKey, out JsonElement listEl) || listEl.ValueKind != JsonValueKind.Array)
            return null;

        var subPathMap = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (JsonElement item in listEl.EnumerateArray())
        {
            if (item.TryGetProperty("name", out JsonElement nEl) &&
                item.TryGetProperty("sub_path", out JsonElement spEl))
            {
                string? n = nEl.GetString();
                string? sp = spEl.GetString();
                if (!string.IsNullOrWhiteSpace(n) && !string.IsNullOrWhiteSpace(sp))
                {
                    subPathMap[n] = sp;
                }
            }
        }

        if (!subPathMap.ContainsKey(targetName))
            return null;

        var chain = new List<Dictionary<string, object?>>();
        string curr = targetName;
        var visited = new HashSet<string>(StringComparer.Ordinal);

        while (!string.IsNullOrWhiteSpace(curr) && subPathMap.TryGetValue(curr, out string? relPath) && !visited.Contains(curr))
        {
            visited.Add(curr);
            string filePath = Path.Combine(baseDir, vendor, relPath.Replace('/', Path.DirectorySeparatorChar));
            if (!File.Exists(filePath))
                break;

            var dict = ParseJsonDictionary(File.ReadAllText(filePath, Encoding.UTF8));
            if (dict == null)
                break;

            chain.Add(dict);
            curr = GetStringValue(dict, "inherits") ?? "";
        }

        if (chain.Count == 0)
            return null;

        var merged = new Dictionary<string, object?>(StringComparer.Ordinal);
        for (int i = chain.Count - 1; i >= 0; i--)
        {
            foreach (var kv in chain[i])
            {
                merged[kv.Key] = kv.Value;
            }
        }
        return merged;
    }

    private static (Dictionary<string, object?> Combined, Dictionary<string, object?> ProcessProfile, HashSet<string> FilamentKeys)? BuildOfficialPrinterSettings(
        Printer3DModel targetPrinter,
        string nozzleStr,
        List<string> filamentTypes,
        List<string> filamentColors)
    {
        string cleanModel = CanonicalPrinterModelName(targetPrinter);
        string[] candidateMachineNames =
        {
            $"{cleanModel} {nozzleStr} nozzle",
            targetPrinter.PrinterSettingsID,
            $"{cleanModel} 0.4 nozzle",
            cleanModel
        };

        string[] vendors = VendorIndexNames(targetPrinter.Brand);
        var baseDirs = ProfileBaseDirectories();

        string? foundBaseDir = null;
        string? foundVendor = null;
        JsonElement foundIndex = default;
        string? foundMachineName = null;
        Dictionary<string, object?>? machineProfile = null;

        foreach (string dir in baseDirs)
        {
            foreach (string vendor in vendors)
            {
                string indexPath = Path.Combine(dir, $"{vendor}.json");
                if (!File.Exists(indexPath)) continue;
                try
                {
                    using JsonDocument doc = JsonDocument.Parse(File.ReadAllText(indexPath, Encoding.UTF8));
                    JsonElement root = doc.RootElement.Clone();
                    foreach (string cand in candidateMachineNames)
                    {
                        var m = LoadInheritedProfileChain(dir, vendor, root, "machine_list", cand);
                        if (m != null)
                        {
                            foundBaseDir = dir;
                            foundVendor = vendor;
                            foundIndex = root;
                            foundMachineName = cand;
                            machineProfile = m;
                            break;
                        }
                    }
                }
                catch { }
                if (machineProfile != null) break;
            }
            if (machineProfile != null) break;
        }

        // Fallback to Anycubic Kobra X 0.4 nozzle template if custom/unindexed printer
        if (machineProfile == null)
        {
            foreach (string dir in baseDirs)
            {
                string indexPath = Path.Combine(dir, "Anycubic.json");
                if (!File.Exists(indexPath)) continue;
                try
                {
                    using JsonDocument doc = JsonDocument.Parse(File.ReadAllText(indexPath, Encoding.UTF8));
                    JsonElement root = doc.RootElement.Clone();
                    var m = LoadInheritedProfileChain(dir, "Anycubic", root, "machine_list", "Anycubic Kobra X 0.4 nozzle");
                    if (m != null)
                    {
                        foundBaseDir = dir;
                        foundVendor = "Anycubic";
                        foundIndex = root;
                        foundMachineName = targetPrinter.PrinterSettingsID;
                        machineProfile = m;
                        break;
                    }
                }
                catch { }
            }
        }

        if (foundBaseDir == null || foundVendor == null || machineProfile == null)
            return null;

        string machineName = foundMachineName ?? targetPrinter.PrinterSettingsID;
        string defaultProcessName = GetFirstStringValue(machineProfile, "default_print_profile") ?? $"0.20mm Standard @{machineName}";
        var processProfile = LoadInheritedProfileChain(foundBaseDir, foundVendor, foundIndex, "process_list", defaultProcessName);

        if (processProfile == null && foundIndex.TryGetProperty("process_list", out JsonElement pList) && pList.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement item in pList.EnumerateArray())
            {
                string? name = item.TryGetProperty("name", out JsonElement nEl) ? nEl.GetString() : null;
                if (!string.IsNullOrWhiteSpace(name) && name.Contains($"@{machineName}", StringComparison.OrdinalIgnoreCase))
                {
                    processProfile = LoadInheritedProfileChain(foundBaseDir, foundVendor, foundIndex, "process_list", name);
                    if (processProfile != null) break;
                }
            }
        }

        var defaultFilamentNames = GetStringList(machineProfile, "default_filament_profile");
        string fallbackFilamentName = defaultFilamentNames.FirstOrDefault() ?? $"{foundVendor} PLA @{machineName}";

        int filamentCount = Math.Max(Math.Max(filamentTypes.Count, filamentColors.Count), 1);
        var slotFilamentProfiles = new List<Dictionary<string, object?>>();
        var slotFilamentIds = new List<string>();

        for (int i = 0; i < filamentCount; i++)
        {
            string fType = (i < filamentTypes.Count ? filamentTypes[i] : "PLA").ToUpperInvariant();
            string[] preferredCandidates =
            {
                $"{foundVendor} {fType} @{machineName}",
                $"Generic {fType} @{machineName}",
                fallbackFilamentName
            };

            Dictionary<string, object?>? loadedFilament = null;
            string loadedId = fallbackFilamentName;

            foreach (string cand in preferredCandidates)
            {
                var fp = LoadInheritedProfileChain(foundBaseDir, foundVendor, foundIndex, "filament_list", cand);
                if (fp != null)
                {
                    loadedFilament = fp;
                    loadedId = cand;
                    break;
                }
            }

            if (loadedFilament == null && foundIndex.TryGetProperty("filament_list", out JsonElement fList) && fList.ValueKind == JsonValueKind.Array)
            {
                foreach (JsonElement item in fList.EnumerateArray())
                {
                    string? n = item.TryGetProperty("name", out JsonElement nEl) ? nEl.GetString() : null;
                    if (!string.IsNullOrWhiteSpace(n) &&
                        n.Contains($"@{machineName}", StringComparison.OrdinalIgnoreCase) &&
                        n.Contains(fType, StringComparison.OrdinalIgnoreCase))
                    {
                        var fp = LoadInheritedProfileChain(foundBaseDir, foundVendor, foundIndex, "filament_list", n);
                        if (fp != null)
                        {
                            loadedFilament = fp;
                            loadedId = n;
                            break;
                        }
                    }
                }
            }

            if (loadedFilament != null)
                slotFilamentProfiles.Add(loadedFilament);
            slotFilamentIds.Add(loadedId);
        }

        var combined = new Dictionary<string, object?>(machineProfile, StringComparer.Ordinal);
        if (processProfile != null)
        {
            foreach (var kv in processProfile)
                combined[kv.Key] = kv.Value;
        }

        var firstFilament = slotFilamentProfiles.FirstOrDefault();
        if (firstFilament != null)
        {
            foreach (var kv in firstFilament)
            {
                if (kv.Value is List<string>)
                {
                    var perSlotValues = new List<string>();
                    for (int slotIdx = 0; slotIdx < filamentCount; slotIdx++)
                    {
                        var slotProf = slotIdx < slotFilamentProfiles.Count ? slotFilamentProfiles[slotIdx] : firstFilament;
                        string val = GetFirstStringValue(slotProf, kv.Key) ?? FirstStringFromObject(kv.Value) ?? "";
                        perSlotValues.Add(val);
                    }
                    combined[kv.Key] = perSlotValues;
                }
                else
                {
                    combined[kv.Key] = kv.Value;
                }
            }
        }

        string[] definitionOnlyKeys = { "type", "instantiation", "setting_id", "filament_id", "is_custom_defined" };
        foreach (string k in definitionOnlyKeys)
            combined.Remove(k);

        string resolvedProcName = (processProfile != null ? GetFirstStringValue(processProfile, "name") : null) ?? defaultProcessName;
        combined["printer_settings_id"] = machineName;
        combined["print_settings_id"] = resolvedProcName;
        combined["default_print_profile"] = resolvedProcName;
        combined["filament_settings_id"] = slotFilamentIds;
        combined["default_filament_profile"] = new List<string> { slotFilamentIds.FirstOrDefault() ?? fallbackFilamentName };
        combined["filament_type"] = filamentTypes;
        combined["filament_colour"] = filamentColors;
        combined["default_filament_colour"] = Enumerable.Repeat("", filamentCount).ToList();

        var fKeys = firstFilament != null
            ? new HashSet<string>(firstFilament.Keys, StringComparer.Ordinal)
            : new HashSet<string>(StringComparer.Ordinal);

        return (combined, processProfile ?? new Dictionary<string, object?>(StringComparer.Ordinal), fKeys);
    }

    private static string SanitizeScalarValue(string key, string rawValue, bool isAnycubic)
    {
        string val = rawValue.Trim();
        if (val.Contains(',') && key != "best_object_pos")
        {
            val = val.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).FirstOrDefault() ?? val;
        }

        switch (key)
        {
            case "ensure_vertical_shell_thickness":
                return val.ToLowerInvariant() switch
                {
                    "enabled" or "1" or "true" or "all" or "ensure_all" => "ensure_all",
                    "moderate" or "critical_only" or "ensure_critical_only" => "ensure_critical_only",
                    "disabled" or "0" or "false" or "none" or "ensure_none" => "ensure_none",
                    _ => "ensure_all"
                };

            case "enable_overhang_speed":
            case "overhang_speed_classic":
            case "enable_support":
            case "support_on_build_plate_only":
            case "detect_thin_wall":
            case "spiral_mode":
            case "enable_prime_tower":
            case "wipe_tower_no_sparse_layers":
                return val.ToLowerInvariant() switch
                {
                    "1" or "true" or "enabled" or "yes" => "1",
                    "0" or "false" or "disabled" or "no" => "0",
                    _ => val == "0" ? "0" : "1"
                };

            case "nozzle_type":
            {
                string lower = val.ToLowerInvariant();
                if (lower.Contains("hardened")) return "hardened_steel";
                if (lower.Contains("stainless")) return "stainless_steel";
                if (lower.Contains("brass")) return "brass";
                return "hardened_steel";
            }

            case "sparse_infill_pattern":
            {
                string lower = val.ToLowerInvariant();
                if (lower == "zig-zag") return "rectilinear";
                if (isAnycubic && lower == "crosshatch") return "gyroid";
                return lower;
            }

            default:
                return val;
        }
    }

    private static void SanitizeCrossSlicerSettings(Dictionary<string, object?> settingsDict, Printer3DModel targetPrinter)
    {
        bool isAnycubic = targetPrinter.Brand.Contains("anycubic", StringComparison.OrdinalIgnoreCase) ||
                          targetPrinter.Name.Contains("anycubic", StringComparison.OrdinalIgnoreCase);

        foreach (string key in settingsDict.Keys.ToList())
        {
            if (ScalarSlicerKeys.Contains(key))
            {
                string? firstStr = GetFirstStringValue(settingsDict, key);
                if (firstStr != null)
                {
                    settingsDict[key] = SanitizeScalarValue(key, firstStr, isAnycubic);
                }
            }
        }

        string eoh = GetFirstStringValue(settingsDict, "enable_overhang_speed") ?? "1";
        settingsDict["enable_overhang_speed"] = SanitizeScalarValue("enable_overhang_speed", eoh, isAnycubic);

        string evst = GetFirstStringValue(settingsDict, "ensure_vertical_shell_thickness") ?? "ensure_all";
        settingsDict["ensure_vertical_shell_thickness"] = SanitizeScalarValue("ensure_vertical_shell_thickness", evst, isAnycubic);

        string nt = GetFirstStringValue(settingsDict, "nozzle_type") ?? "hardened_steel";
        settingsDict["nozzle_type"] = SanitizeScalarValue("nozzle_type", nt, isAnycubic);
    }

    private static void SanitizeXmlMetadataNodes(XDocument xmlDoc)
    {
        var unsupportedXmlKeys = new HashSet<string>(StringComparer.Ordinal)
        {
            "skeleton_infill_density",
            "skin_infill_density"
        };

        var metaNodes = xmlDoc.XPathSelectElements("//metadata").ToList();
        foreach (var el in metaNodes)
        {
            string? key = el.Attribute("key")?.Value;
            if (string.IsNullOrEmpty(key)) continue;
            if (unsupportedXmlKeys.Contains(key))
            {
                el.Remove();
                continue;
            }
            var valAttr = el.Attribute("value");
            if (valAttr != null && ScalarSlicerKeys.Contains(key))
            {
                valAttr.Value = SanitizeScalarValue(key, valAttr.Value, isAnycubic: true);
            }
        }
    }

    public static string NormalizeHexColor(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return "#00E5FF";
        string cleaned = raw.Trim().TrimStart('#');
        if (cleaned.Length >= 6)
            return "#" + cleaned.Substring(0, 6).ToUpperInvariant();
        return "#00E5FF";
    }

    private static (int W, int D) ParsePrintableArea(List<string> area)
    {
        int maxX = 0;
        int maxY = 0;
        foreach (string pt in area)
        {
            var comps = pt.ToLowerInvariant().Split('x');
            if (comps.Length == 2 &&
                double.TryParse(comps[0], NumberStyles.Float, CultureInfo.InvariantCulture, out double x) &&
                double.TryParse(comps[1], NumberStyles.Float, CultureInfo.InvariantCulture, out double y))
            {
                maxX = Math.Max(maxX, (int)x);
                maxY = Math.Max(maxY, (int)y);
            }
        }
        return (maxX, maxY);
    }

    private static Dictionary<string, object?>? ParseJsonDictionary(string json)
    {
        try
        {
            using JsonDocument doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return null;
            var dict = new Dictionary<string, object?>(StringComparer.Ordinal);
            foreach (JsonProperty prop in doc.RootElement.EnumerateObject())
            {
                dict[prop.Name] = ConvertJsonElement(prop.Value);
            }
            return dict;
        }
        catch
        {
            return null;
        }
    }

    private static object? ConvertJsonElement(JsonElement el)
    {
        return el.ValueKind switch
        {
            JsonValueKind.String => el.GetString() ?? "",
            JsonValueKind.Number => el.GetRawText(),
            JsonValueKind.True => "1",
            JsonValueKind.False => "0",
            JsonValueKind.Array => el.EnumerateArray().Select(x => ConvertJsonElement(x)?.ToString() ?? "").ToList(),
            _ => null
        };
    }

    private static string GetStringValue(Dictionary<string, object?> dict, string key)
    {
        if (!dict.TryGetValue(key, out object? val) || val == null) return "";
        return val is string s ? s.Trim() : val.ToString()?.Trim() ?? "";
    }

    private static string? GetFirstStringValue(Dictionary<string, object?> dict, string key)
    {
        if (!dict.TryGetValue(key, out object? val) || val == null) return null;
        return FirstStringFromObject(val);
    }

    private static string? FirstStringFromObject(object? val)
    {
        if (val is string s) return s.Trim();
        if (val is IEnumerable<string> list) return list.FirstOrDefault()?.Trim();
        return val?.ToString()?.Trim();
    }

    private static List<string> GetStringList(Dictionary<string, object?> dict, string key)
    {
        if (!dict.TryGetValue(key, out object? val) || val == null) return new List<string>();
        return ValueToStringList(val);
    }

    private static List<string> ValueToStringList(object? val)
    {
        if (val is List<string> list) return new List<string>(list);
        if (val is IEnumerable<string> seq) return seq.ToList();
        if (val is string s && !string.IsNullOrWhiteSpace(s)) return new List<string> { s.Trim() };
        return new List<string>();
    }
}
