using System.Windows;
using FlowConverter.Windows.Localization;

namespace FlowConverter.Windows.Views;

public partial class LanguageSelectionWindow : Window
{
    public string SelectedLanguage => (string)LanguagePicker.SelectedValue;

    public LanguageSelectionWindow()
    {
        InitializeComponent();
        LanguagePicker.ItemsSource = UiText.Languages;
        LanguagePicker.SelectedValue = UiText.SuggestedLanguage;
        Loaded += (_, _) => LanguagePicker.Focus();
    }

    private void Continue_Click(object sender, RoutedEventArgs e) => DialogResult = true;
}
