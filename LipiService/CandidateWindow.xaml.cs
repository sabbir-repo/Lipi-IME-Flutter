using System;
using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Media;

namespace LipiService
{
    public class CandidateItem
    {
        public string IndexText { get; set; } = "";
        public string Word { get; set; } = "";
        public bool IsSelected { get; set; }
        
        public Brush BackgroundBrush => IsSelected ? new SolidColorBrush(Color.FromArgb(255, 60, 60, 60)) : Brushes.Transparent;
        public Brush ForegroundBrush => IsSelected ? Brushes.White : new SolidColorBrush(Color.FromArgb(255, 200, 200, 200));
    }

    public partial class CandidateWindow : Window
    {
        public ObservableCollection<CandidateItem> Suggestions { get; set; }

        public CandidateWindow()
        {
            InitializeComponent();
            Suggestions = new ObservableCollection<CandidateItem>();
            SuggestionsList.ItemsSource = Suggestions;
        }

        public void UpdateSuggestions(string[] words, int selectedIndex)
        {
            Suggestions.Clear();
            for (int i = 0; i < words.Length; i++)
            {
                Suggestions.Add(new CandidateItem
                {
                    IndexText = (i + 1).ToString() + ".",
                    Word = words[i],
                    IsSelected = (i == selectedIndex)
                });
            }
        }
    }
}
