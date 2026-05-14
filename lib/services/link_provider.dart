import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum LinkStatus { initial, loading, loaded, error }

class LinkProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  LinkStatus _status = LinkStatus.initial;
  List<StudentParentLink> _allLinks = [];
  List<StudentParentLink> _filteredLinks = [];
  String? _error;
  String? _searchQuery;
  String? _selectedClass;
  bool _showOnlyUnlinked = false;

  LinkStatus get status => _status;
  List<StudentParentLink> get links => _filteredLinks.isEmpty && _allLinks.isNotEmpty ? _allLinks : _filteredLinks;
  List<StudentParentLink> get allLinks => _allLinks;
  String? get error => _error;
  String? get searchQuery => _searchQuery;
  String? get selectedClass => _selectedClass;
  bool get showOnlyUnlinked => _showOnlyUnlinked;

  bool get isLoading => _status == LinkStatus.loading;
  bool get hasError => _status == LinkStatus.error;
  bool get isEmpty => links.isEmpty && _status == LinkStatus.loaded;

  Future<void> loadLinks({String? search}) async {
    _status = LinkStatus.loading;
    _error = null;
    _searchQuery = search;
    notifyListeners();

    try {
      _allLinks = await _api.getStudentParentLinks(search: search);
      _applyFilters();
      _status = LinkStatus.loaded;
    } on ApiException catch (e) {
      _error = e.message;
      _status = LinkStatus.error;
    } catch (e) {
      _error = 'Erro de conexão. Verifique sua internet.';
      _status = LinkStatus.error;
    }

    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setClassFilter(String? className) {
    _selectedClass = className;
    _applyFilters();
    notifyListeners();
  }

  void setShowOnlyUnlinked(bool value) {
    _showOnlyUnlinked = value;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = null;
    _selectedClass = null;
    _showOnlyUnlinked = false;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredLinks = _allLinks;

    // Apply unlinked filter
    if (_showOnlyUnlinked) {
      _filteredLinks = _filteredLinks.where((l) => l.parents.isEmpty).toList();
    }

    // Apply class filter
    if (_selectedClass != null && _selectedClass!.isNotEmpty) {
      _filteredLinks = _filteredLinks
          .where((l) => l.student.fullClass == _selectedClass)
          .toList();
    }

    // Apply search filter
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final query = _searchQuery!.toLowerCase();
      _filteredLinks = _filteredLinks.where((l) {
        return l.student.name.toLowerCase().contains(query) ||
            l.student.fullClass.toLowerCase().contains(query) ||
            l.parents.any((p) =>
                p.name.toLowerCase().contains(query) ||
                p.phone.contains(query) ||
                p.email.toLowerCase().contains(query));
      }).toList();
    }
  }

  Future<bool> linkStudentParent(String studentId, String parentId) async {
    try {
      await _api.linkStudentParent(studentId, parentId);
      // Recarregar lista após vínculo
      await loadLinks(search: _searchQuery);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro de conexão. Verifique sua internet.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unlinkStudentParent(String studentId, String parentId) async {
    try {
      await _api.unlinkStudentParent(studentId, parentId);
      // Recarregar lista após desvinculação
      await loadLinks(search: _searchQuery);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro de conexão. Verifique sua internet.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = null;
    _applyFilters();
    notifyListeners();
  }
}
