# SearchableDropdown
Searchable dropdown text form field widget

*** search your dropdown data from api and list ***

## Searchable Request Dropdown in Flutter

This example demonstrates how to use `SearchableRequestDropdown<String>` in Flutter with async data fetching.

### Example Code

```dart
SearchableRequestDropdown<String>(
  hintText: "Select an option",
  suggestionsCallback: (query) async {
    // Simulate fetching data
    await Future.delayed(Duration(milliseconds: 500));
    List<String> allData = ["Apple", "Banana", "Cherry", "Date"];
    return allData
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
  },
  onChanged: (value) {
    print("Selected: $value");
  },
  validator: (value) {
    if (value == null || value.isEmpty) {
      return "Field can't be empty";
    }
    return null;
  },
),

