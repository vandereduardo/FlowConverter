using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows.Markup;

namespace FlowConverter.Windows.Localization;

public static class UiText
{
    public const string English = "en-US";
    public const string BrazilianPortuguese = "pt-BR";

    public sealed record LanguageOption(string Code, string Name);

    public static IReadOnlyList<LanguageOption> Languages { get; } = Array.AsReadOnly(new[]
    {
        new LanguageOption(English, "English"),
        new LanguageOption(BrazilianPortuguese, "Português (Brasil)")
    });

    private static readonly Dictionary<string, string[]> Catalog = LoadCatalog();
    private static readonly Dictionary<string, string> Portuguese = Catalog.Values
        .ToDictionary(entry => entry[0], entry => entry[1], StringComparer.Ordinal);

    public static string Language { get; private set; } = English;

    public static string SuggestedLanguage => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "pt"
        ? BrazilianPortuguese
        : English;

    public static bool IsSupported(string? code) => Languages.Any(language => language.Code == code);

    public static void Apply(string code) => Language = IsSupported(code) ? code : English;

    public static string Get(string english) =>
        Language == BrazilianPortuguese && Portuguese.TryGetValue(english, out string? translated)
            ? translated
            : english;

    public static string Format(string english, params object?[] arguments) =>
        string.Format(CultureInfo.GetCultureInfo(Language), Get(english), arguments);

    internal static string GetByKey(string key)
    {
        if (!Catalog.TryGetValue(key, out var entry))
            throw new InvalidOperationException($"Unknown UI text resource: {key}");
        return Language == BrazilianPortuguese ? entry[1] : entry[0];
    }

    private static Dictionary<string, string[]> LoadCatalog()
    {
        using var stream = typeof(UiText).Assembly.GetManifestResourceStream("FlowConverter.Windows.Localization.Strings.json")
            ?? throw new FileNotFoundException("UI text resources are missing.");
        return JsonSerializer.Deserialize<Dictionary<string, string[]>>(stream)
            ?? throw new InvalidDataException("UI text resources could not be loaded.");
    }
}

[MarkupExtensionReturnType(typeof(string))]
public sealed class TextExtension(string key) : MarkupExtension
{
    public override object ProvideValue(IServiceProvider serviceProvider) => UiText.GetByKey(key);
}
