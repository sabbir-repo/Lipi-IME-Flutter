using System;
using System.Collections.Generic;

namespace LipiService.Services
{
    public class AvroPhonetic
    {
        private static readonly Dictionary<string, string> Consonants = new Dictionary<string, string>
        {
            {"kkh", "ক্ষ"}, {"k", "ক"}, {"kh", "খ"}, {"g", "গ"}, {"gh", "ঘ"}, {"ng", "ঙ"},
            {"c", "চ"}, {"ch", "ছ"}, {"j", "জ"}, {"jh", "ঝ"}, {"NG", "ঞ"},
            {"T", "ট"}, {"Th", "ঠ"}, {"D", "ড"}, {"Dh", "ঢ"}, {"N", "ণ"},
            {"t", "ত"}, {"th", "থ"}, {"d", "দ"}, {"dh", "ধ"}, {"n", "ন"},
            {"p", "প"}, {"f", "ফ"}, {"ph", "ফ"}, {"b", "ব"}, {"bh", "ভ"}, {"v", "ভ"}, {"m", "ম"},
            {"z", "য"}, {"r", "র"}, {"l", "ল"}, {"sh", "শ"}, {"S", "ষ"}, {"s", "স"}, {"h", "হ"},
            {"R", "ড়"}, {"Rh", "ঢ়"}, {"y", "য়"}, {"Y", "য়"}, {"q", "ক"}, {"w", "ও"}, {"x", "ক্স"}
        };

        private static readonly Dictionary<string, string> VowelsStandalone = new Dictionary<string, string>
        {
            {"a", "আ"}, {"i", "ই"}, {"I", "ঈ"}, {"u", "উ"}, {"U", "ঊ"}, {"e", "এ"}, {"o", "ও"}, {"O", "ও"}, {"oi", "ঐ"}, {"ou", "ঔ"}
        };

        private static readonly Dictionary<string, string> VowelsKars = new Dictionary<string, string>
        {
            {"a", "া"}, {"i", "ি"}, {"I", "ী"}, {"u", "ু"}, {"U", "ূ"}, {"e", "ে"}, {"o", "ো"}, {"O", "ো"}, {"oi", "ৈ"}, {"ou", "ৌ"}
        };

        public static string Parse(string input)
        {
            if (string.IsNullOrEmpty(input)) return "";

            string result = "";
            bool lastWasConsonant = false;

            int i = 0;
            while (i < input.Length)
            {
                bool matched = false;

                // Check vowels
                for (int len = Math.Min(2, input.Length - i); len >= 1; len--)
                {
                    string sub = input.Substring(i, len);
                    if (VowelsKars.ContainsKey(sub))
                    {
                        if (lastWasConsonant)
                        {
                            result += VowelsKars[sub];
                        }
                        else
                        {
                            result += VowelsStandalone[sub];
                        }
                        lastWasConsonant = false;
                        i += len;
                        matched = true;
                        break;
                    }
                }

                if (matched) continue;

                // Handle 'o' which acts as inherent vowel or standalone
                if (input[i] == 'o' || input[i] == 'O')
                {
                    if (!lastWasConsonant)
                        result += "ও";
                    lastWasConsonant = false;
                    i++;
                    continue;
                }

                // Check consonants
                for (int len = Math.Min(3, input.Length - i); len >= 1; len--)
                {
                    string sub = input.Substring(i, len);
                    if (Consonants.ContainsKey(sub))
                    {
                        if (lastWasConsonant)
                        {
                            result += "্"; // Hasant to join consonants
                        }
                        result += Consonants[sub];
                        lastWasConsonant = true;
                        i += len;
                        matched = true;
                        break;
                    }
                }

                if (matched) continue;

                // Unmatched character, keep it as is
                if (lastWasConsonant) result += "্"; // Add hasant before unknown char if needed
                result += input[i];
                lastWasConsonant = false;
                i++;
            }

            return result;
        }
    }
}
