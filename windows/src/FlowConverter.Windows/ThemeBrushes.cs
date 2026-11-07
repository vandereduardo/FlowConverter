using System.Windows;
using System.Windows.Media;

namespace FlowConverter.Windows;

internal static class ThemeBrushes
{
    internal static SolidColorBrush Get(string key) => (SolidColorBrush)Application.Current.FindResource(key);
}
