/// App-wide constants.
abstract final class AppConstants {
  static const String databaseName = 'opendocs.db';
  static const int databaseVersion = 1;

  static const int maxRecentDocuments = 50;
  static const int maxRecentFiles = 100;

  static const Set<String> pdfExtensions = {'.pdf'};
  static const Set<String> archiveExtensions = {
    '.zip',
    '.7z',
    '.tar',
    '.gz',
    '.tgz',
    '.tar.gz',
  };
  static const Set<String> imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
    '.gif',
  };
}

/// Keys for the `app_settings` table.
abstract final class SettingKeys {
  static const String themeMode = 'theme_mode'; // system | light | dark
  static const String fileViewMode = 'file_view_mode'; // list | grid
  static const String fileSortField = 'file_sort_field'; // name | size | date
  static const String fileSortAscending = 'file_sort_ascending';
  static const String showHiddenFiles = 'show_hidden_files';
  static const String readerPageMode = 'reader_page_mode'; // continuous | single
}
